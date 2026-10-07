import SwiftUI
import WebKit

@MainActor @Observable
final class BrowserModel {
    var archive: BrowserArchive
    private(set) var sessions: [UUID: TabSession] = [:]
    let blocker = ContentBlocker()
    let downloads: DownloadManager
    let profileID: UUID
    var profileName: String
    let websiteDataStore: WKWebsiteDataStore
    private(set) var isActive = true
    var errorMessage: String?
    var externalURL: URL?
    var dialog: WebDialog?
    var lastClosed: TabRecord?
    var isClearingData = false
    private let store: BrowserStore
    private var persistTask: Task<Void, Never>?
    private var bookmarkNameTasks: [UUID: Task<Void, Never>] = [:]
    private var mediaTask: Task<Void, Never>?
    private var memoryObserver: NSObjectProtocol?
    private(set) var isTesting = false
    private(set) var persistenceAvailable = true
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

    init(store: BrowserStore = BrowserStore(), profileID: UUID = UUID(), profileName: String = "Personal",
         websiteDataStore: WKWebsiteDataStore? = nil, isTesting: Bool = false) {
        self.store = store
        self.profileID = profileID
        self.profileName = profileName
        self.websiteDataStore = websiteDataStore ?? .nonPersistent()
        self.downloads = DownloadManager(profileID: profileID)
        do { archive = try self.store.load() }
        catch {
            archive = BrowserArchive()
            persistenceAvailable = false
            errorMessage = "Saved browsing data could not be read. It has been left untouched. \(error.localizedDescription)"
        }
        self.isTesting = isTesting
        if !archive.settings.restoreTabs || archive.tabs.isEmpty { archive.tabs = [TabRecord()]; archive.selectedTabID = nil }
        if !archive.tabs.contains(where: { $0.id == archive.selectedTabID }) { archive.selectedTabID = archive.tabs[0].id }
        if persistenceAvailable { store.prunePreviews(keeping: Set(archive.tabs.map(\.id))) }
        memoryObserver = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.trimSessions(memoryPressure: true) }
        }
        Task { [weak self] in
            guard let self else { return }
            await self.blocker.prepare()
            self.ensureSession(self.selectedID)
            #if DEBUG
            if self.isActive && self.isTesting && ProcessInfo.processInfo.arguments.contains("--fixture"),
               let url = Bundle.main.url(forResource: "browser-fixture", withExtension: "html") {
                self.loadFixture(url)
            }
            #endif
        }
        mediaTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { break }
                await self?.trimSessions()
            }
        }
    }

    isolated deinit {
        persistTask?.cancel(); mediaTask?.cancel()
        for task in bookmarkNameTasks.values { task.cancel() }
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
    @discardableResult func saveNow() -> Bool {
        guard persistenceAvailable else { return false }
        do { try store.save(archive); return true }
        catch { errorMessage = "Harbor could not save your session. \(error.localizedDescription)"; return false }
    }

    func activate() {
        isActive = true
        ensureSession(selectedID)
    }

    func deactivate() {
        isActive = false
        for task in bookmarkNameTasks.values { task.cancel() }
        bookmarkNameTasks.removeAll()
        persistTask?.cancel()
        dialog?.finish(nil)
        dialog = nil
        externalURL = nil
        for session in sessions.values { session.dispose() }
        sessions.removeAll()
    }

    func ensureSession(_ id: UUID) {
        guard isActive, !isClearingData, blocker.ready, sessions[id] == nil,
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
        guard isActive, !isClearingData else { return }
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
        if let previous = lastClosed { store.removePreview(previous.id) }
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
    func moveTabs(from offsets: IndexSet, to destination: Int) {
        archive.tabs.move(fromOffsets: offsets, toOffset: destination)
        saveSoon()
    }

    func moveTab(_ id: UUID, onto target: UUID) {
        guard let source = archive.tabs.firstIndex(where: { $0.id == id }),
              let destination = archive.tabs.firstIndex(where: { $0.id == target }), source != destination else { return }
        moveTabs(from: IndexSet(integer: source), to: destination > source ? destination + 1 : destination)
    }

    func previewURL(_ id: UUID) -> URL { store.previewURL(id) }

    func savePreview(_ image: UIImage, for session: TabSession) {
        guard isActive, !isClearingData, persistenceAvailable, sessions[session.id] === session else { return }
        // A preview failure must not interrupt browsing; the live thumbnail remains available.
        try? store.savePreview(image, id: session.id)
    }

    /// Release background pages without removing their tab records or saved previews.
    func unloadBackgroundTabs() async {
        await refreshMedia()
        for session in Array(sessions.values) {
            guard session.id != selectedID, session.mediaState != .playing,
                  !session.fullscreen, !session.isLoading else { continue }
            sessions.removeValue(forKey: session.id)?.dispose()
        }
    }

    func createPopup(configuration: WKWebViewConfiguration, url: URL?) -> WKWebView? {
        guard isActive, !isClearingData, configuration.websiteDataStore === websiteDataStore else { return nil }
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
        guard isActive, !isClearingData, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        if archive.history.first?.url == url { archive.history.removeFirst() }
        archive.history.insert(HistoryEntry(url: url, title: title), at: 0)
        archive.history = Array(archive.history.prefix(3000))
        saveSoon()
    }
    func toggleBookmark(folderID: UUID? = nil) {
        guard isActive, let url = selectedTab.url else { return }
        if let bookmark = archive.bookmarks.first(where: { $0.url == url }) {
            deleteBookmark(bookmark.id)
        } else {
            let bookmark = Bookmark(url: url, title: BookmarkNaming.fallback(title: selectedTab.title, url: url),
                                    folderID: archive.bookmarkFolders.contains(where: { $0.id == folderID }) ? folderID : nil)
            archive.bookmarks.append(bookmark)
            saveNow()
            guard !isTesting else { return }
            bookmarkNameTasks[bookmark.id] = Task { [weak self] in
                let name = await BookmarkNaming.suggest(title: bookmark.title, url: bookmark.url)
                guard !Task.isCancelled, let self else { return }
                self.bookmarkNameTasks[bookmark.id] = nil
                if let name { self.applySuggestedBookmarkName(name, to: bookmark) }
            }
        }
    }

    func applySuggestedBookmarkName(_ name: String, to original: Bookmark) {
        guard isActive, let index = archive.bookmarks.firstIndex(where: { $0.id == original.id && $0.title == original.title }) else { return }
        let name = BookmarkNaming.normalized(name)
        guard !name.isEmpty, name.count <= 80 else { return }
        archive.bookmarks[index].title = name
        saveNow()
    }

    func renameBookmark(_ id: UUID, to title: String) {
        let title = BookmarkNaming.normalized(title)
        guard isActive, !title.isEmpty,
              let index = archive.bookmarks.firstIndex(where: { $0.id == id }) else { return }
        bookmarkNameTasks.removeValue(forKey: id)?.cancel()
        archive.bookmarks[index].title = title
        saveNow()
    }

    func deleteBookmark(_ id: UUID) {
        bookmarkNameTasks.removeValue(forKey: id)?.cancel()
        archive.bookmarks.removeAll { $0.id == id }
        saveNow()
    }

    @discardableResult
    func createBookmarkFolder(named name: String) -> UUID? {
        let name = BookmarkNaming.normalized(name)
        guard isActive, !name.isEmpty else { return nil }
        if let existing = archive.bookmarkFolders.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return existing.id
        }
        let folder = BookmarkFolder(name: name)
        archive.bookmarkFolders.append(folder)
        saveNow()
        return folder.id
    }

    func renameBookmarkFolder(_ id: UUID, to name: String) {
        let name = BookmarkNaming.normalized(name)
        guard isActive, !name.isEmpty,
              !archive.bookmarkFolders.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }),
              let index = archive.bookmarkFolders.firstIndex(where: { $0.id == id }) else { return }
        archive.bookmarkFolders[index].name = name
        saveNow()
    }

    func moveBookmark(_ id: UUID, to folderID: UUID?) {
        guard isActive, folderID == nil || archive.bookmarkFolders.contains(where: { $0.id == folderID }),
              let index = archive.bookmarks.firstIndex(where: { $0.id == id }) else { return }
        archive.bookmarks[index].folderID = folderID
        saveNow()
    }

    func deleteBookmarkFolder(_ id: UUID) {
        guard isActive else { return }
        // Removing a folder never removes its saved pages.
        for index in archive.bookmarks.indices where archive.bookmarks[index].folderID == id {
            archive.bookmarks[index].folderID = nil
        }
        archive.bookmarkFolders.removeAll { $0.id == id }
        saveNow()
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
                  (!session.isLoading || memoryPressure) else { continue }
            sessions.removeValue(forKey: session.id)?.dispose()
        }
        if memoryPressure { for session in sessions.values { session.snapshot = nil } }
    }
    func clearWebsiteData(site: String? = nil) async {
        guard !isClearingData else { return }
        isClearingData = true
        // Clear preview pixels too, including unloaded tabs and the undo-close record.
        // Clearing all previews for site deletion is deliberately conservative.
        store.prunePreviews(keeping: [])
        for session in sessions.values { session.snapshot = nil }
        defer { isClearingData = false }
        // Stop affected pages first so they cannot immediately recreate deleted storage.
        let affected = sessions.values.filter { site == nil || ContentBlocker.siteKey($0.webView.url) == site }
        for session in affected { sessions.removeValue(forKey: session.id)?.dispose() }
        let dataStore = websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        if let site {
            let records = await dataStore.dataRecords(ofTypes: types)
            // WebKit commonly reports a registrable domain rather than an exact origin.
            let matching = records.filter {
                let domain = $0.displayName.lowercased()
                return domain == site || site.hasSuffix("." + domain)
            }
            let domains = matching.map { $0.displayName.lowercased() }
            let related = sessions.values.filter { session in
                guard let host = ContentBlocker.siteKey(session.webView.url) else { return false }
                return domains.contains { host == $0 || host.hasSuffix("." + $0) }
            }
            for session in related { sessions.removeValue(forKey: session.id)?.dispose() }
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
            persistenceAvailable = true
            downloads.clearTemporaryFiles()
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
        blocker.apply(to: session.webView, url: url, settings: archive.settings)
        session.webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    #endif
}
