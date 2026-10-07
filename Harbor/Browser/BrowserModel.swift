import SwiftUI
import WebKit

@MainActor @Observable
final class BrowserModel {
    var archive: BrowserArchive
    private(set) var sessions: [UUID: TabSession] = [:]
    let blocker = ContentBlocker()
    let downloads = DownloadManager()
    var errorMessage: String?
    var externalURL: URL?
    var dialog: WebDialog?
    var lastClosed: TabRecord?
    var isClearingData = false
    private let store: BrowserStore
    private var persistTask: Task<Void, Never>?
    private var mediaTask: Task<Void, Never>?
    private var memoryObserver: NSObjectProtocol?
    private(set) var isTesting = false
    private var persistenceAvailable = true
    private var trimming = false

    var selectedID: UUID { archive.selectedTabID ?? archive.tabs[0].id }
    var selectedTab: TabRecord { archive.tabs.first(where: { $0.id == selectedID }) ?? archive.tabs[0] }
    var activeSession: TabSession? { sessions[selectedID] }
    var site: String? { ContentBlocker.siteKey(selectedTab.url) }
    var protectionStatus: String {
        if !archive.settings.trackerBlocking { return "Tracker blocking off" }
        if !blocker.ready { return "Preparing protection" }
        if blocker.ruleList == nil { return "Protection unavailable" }
        if let site, archive.settings.siteExceptions.contains(site) { return "Off for this site" }
        return "Tracker blocking on"
    }

    init(store: BrowserStore = BrowserStore()) {
        #if DEBUG
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
        #else
        let testing = false
        #endif
        if testing {
            self.store = BrowserStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "HarborUITests/browser.json"))
        } else { self.store = store }
        do { archive = try self.store.load() }
        catch {
            archive = BrowserArchive()
            persistenceAvailable = false
            errorMessage = "Saved browsing data could not be read. It has been left untouched. \(error.localizedDescription)"
        }
        isTesting = testing
        #if DEBUG
        if isTesting && ProcessInfo.processInfo.arguments.contains("--reset") { archive = BrowserArchive() }
        #endif
        if !archive.settings.restoreTabs || archive.tabs.isEmpty { archive.tabs = [TabRecord()]; archive.selectedTabID = nil }
        if !archive.tabs.contains(where: { $0.id == archive.selectedTabID }) { archive.selectedTabID = archive.tabs[0].id }
        memoryObserver = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.trimSessions(memoryPressure: true) }
        }
        Task { [weak self] in
            guard let self else { return }
            await self.blocker.prepare()
            self.ensureSession(self.selectedID)
            #if DEBUG
            if self.isTesting && ProcessInfo.processInfo.arguments.contains("--fixture"),
               let url = Bundle.main.url(forResource: "browser-fixture", withExtension: "html") {
                self.loadFixture(url)
            }
            #endif
        }
        mediaTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { break }
                await self?.refreshMedia()
            }
        }
    }

    isolated deinit {
        persistTask?.cancel(); mediaTask?.cancel()
        if let memoryObserver { NotificationCenter.default.removeObserver(memoryObserver) }
    }

    func saveSoon() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }
    func saveNow() {
        guard persistenceAvailable else { return }
        do { try store.save(archive) }
        catch { errorMessage = "Harbor could not save your session. \(error.localizedDescription)" }
    }

    func ensureSession(_ id: UUID) {
        guard blocker.ready, sessions[id] == nil,
              let record = archive.tabs.first(where: { $0.id == id }), let url = record.url else { return }
        let session = TabSession(id: id, browser: self)
        sessions[id] = session
        blocker.apply(to: session.webView, url: url, settings: archive.settings)
        session.webView.load(URLRequest(url: url))
    }
    func navigate(_ input: String) {
        guard let url = AddressResolver.resolve(input, engine: archive.settings.searchEngine) else { return }
        navigate(url)
    }
    func navigate(_ original: URL) {
        guard !isClearingData else { return }
        guard ["http", "https"].contains(original.scheme?.lowercased() ?? "") else { externalURL = original; return }
        let url = archive.settings.stripTrackingParameters ? TrackingParameterCleaner.clean(original) : original
        guard let index = archive.tabs.firstIndex(where: { $0.id == selectedID }) else { return }
        archive.tabs[index].url = url
        archive.tabs[index].title = url.host ?? "Page"
        if let session = activeSession {
            session.loadError = nil
            blocker.apply(to: session.webView, url: url, settings: archive.settings)
            session.webView.load(URLRequest(url: url))
        } else { ensureSession(selectedID) }
        saveSoon()
    }
    @discardableResult func newTab(url: URL? = nil) -> UUID {
        let tab = TabRecord(url: url)
        archive.tabs.append(tab)
        selectTab(tab.id)
        return tab.id
    }
    func selectTab(_ id: UUID) {
        guard let index = archive.tabs.firstIndex(where: { $0.id == id }) else { return }
        activeSession?.captureSnapshot()
        archive.selectedTabID = id
        archive.tabs[index].lastUsed = Date()
        sessions[id]?.lastUsed = Date()
        ensureSession(id)
        saveSoon()
        Task { await trimSessions() }
    }
    func closeTab(_ id: UUID) {
        guard let index = archive.tabs.firstIndex(where: { $0.id == id }) else { return }
        lastClosed = archive.tabs[index]
        sessions.removeValue(forKey: id)?.dispose()
        archive.tabs.remove(at: index)
        if archive.tabs.isEmpty { archive.tabs = [TabRecord()] }
        if archive.selectedTabID == id { selectTab(archive.tabs[min(index, archive.tabs.count - 1)].id) }
        saveSoon()
    }
    func undoClose() {
        guard let tab = lastClosed else { return }
        archive.tabs.append(tab)
        lastClosed = nil
        selectTab(tab.id)
    }
    func createPopup(configuration: WKWebViewConfiguration, url: URL?) -> WKWebView {
        let tab = TabRecord(url: url)
        archive.tabs.append(tab)
        let session = TabSession(id: tab.id, browser: self, configuration: configuration)
        sessions[tab.id] = session
        blocker.apply(to: session.webView, url: url, settings: archive.settings)
        selectTab(tab.id)
        // WebKit loads the original action, preserving POST data and opener relationship.
        return session.webView
    }
    func updateTab(_ id: UUID, url: URL, title: String?) {
        guard let index = archive.tabs.firstIndex(where: { $0.id == id }) else { return }
        archive.tabs[index].url = url
        if let title, !title.isEmpty { archive.tabs[index].title = title }
        saveSoon()
    }
    func recordVisit(url: URL, title: String) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        if archive.history.first?.url == url { archive.history.removeFirst() }
        archive.history.insert(HistoryEntry(url: url, title: title), at: 0)
        archive.history = Array(archive.history.prefix(3000))
        saveSoon()
    }
    func toggleBookmark() {
        guard let url = selectedTab.url else { return }
        if let index = archive.bookmarks.firstIndex(where: { $0.url == url }) { archive.bookmarks.remove(at: index) }
        else { archive.bookmarks.append(Bookmark(url: url, title: selectedTab.title)) }
        saveSoon()
    }
    func settingsChanged() {
        for session in sessions.values {
            blocker.apply(to: session.webView, url: session.webView.url ?? archive.tabs.first(where: { $0.id == session.id })?.url,
                          settings: archive.settings)
        }
        saveNow()
    }
    func reload() {
        guard let session = activeSession else { ensureSession(selectedID); return }
        session.loadError = nil
        if session.webView.url == nil, let url = selectedTab.url { session.webView.load(URLRequest(url: url)) }
        else { session.webView.reload() }
    }
    func refreshMedia() async {
        for session in Array(sessions.values) { await session.refreshMediaState() }
    }
    func trimSessions(memoryPressure: Bool = false) async {
        guard !trimming else { return }
        trimming = true
        defer { trimming = false }
        await refreshMedia()
        let limit = memoryPressure ? 1 : 5
        let candidates = sessions.values.sorted { $0.lastUsed < $1.lastUsed }
        for session in candidates where sessions.count > limit {
            // Native media state is sampled, not a claim about every embedded player.
            guard session.id != selectedID, session.mediaState != .playing, !session.fullscreen,
                  !session.isLoading else { continue }
            sessions.removeValue(forKey: session.id)?.dispose()
        }
        if memoryPressure { for session in sessions.values { session.snapshot = nil } }
    }
    func clearWebsiteData(site: String? = nil) async {
        guard !isClearingData else { return }
        isClearingData = true
        defer { isClearingData = false }
        // Stop affected pages first so they cannot immediately recreate deleted storage.
        let affected = sessions.values.filter { site == nil || ContentBlocker.siteKey($0.webView.url) == site }
        for session in affected { sessions.removeValue(forKey: session.id)?.dispose() }
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        if let site {
            let records = await dataStore.dataRecords(ofTypes: types)
            // WebKit commonly reports a registrable domain rather than an exact origin.
            let matching = records.filter {
                let domain = $0.displayName.lowercased()
                return domain == site || site.hasSuffix("." + domain)
            }
            await dataStore.removeData(ofTypes: types, for: matching)
            let cookies = await dataStore.httpCookieStore.allCookies()
            for cookie in cookies {
                let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
                if site == domain || site.hasSuffix("." + domain) { await dataStore.httpCookieStore.deleteCookie(cookie) }
            }
        } else {
            await dataStore.removeData(ofTypes: types, modifiedSince: .distantPast)
            archive.history.removeAll()
            archive.tabs = [TabRecord()]
            archive.selectedTabID = archive.tabs[0].id
            lastClosed = nil
        }
        saveNow()
    }
    #if DEBUG
    func loadFixture(_ url: URL) {
        let id = selectedID
        let session = TabSession(id: id, browser: self)
        sessions[id]?.dispose()
        sessions[id] = session
        if let index = archive.tabs.firstIndex(where: { $0.id == id }) { archive.tabs[index].url = url }
        session.webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    #endif
}
