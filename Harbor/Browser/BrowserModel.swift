// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WebKit
import os

/// All browser sheets share one presentation slot, including website dialogs.
enum BrowserSheet: Identifiable {
    case tabs, history, bookmarks, settings, privacy, profiles
    case share(ShareItem), webDialog(WebDialog)

    var id: String {
        switch self {
        case .tabs: "tabs"
        case .history: "history"
        case .bookmarks: "bookmarks"
        case .settings: "settings"
        case .privacy: "privacy"
        case .profiles: "profiles"
        case .share(let item): "share-\(item.id)"
        case .webDialog(let dialog): "dialog-\(dialog.id)"
        }
    }
}

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
    var sheet: BrowserSheet? {
        didSet {
            if case .webDialog(let previous) = oldValue, previous.id != dialog?.id {
                previous.finish(nil)
            }
        }
    }
    var dialog: WebDialog? {
        get {
            if case .webDialog(let dialog) = sheet { return dialog }
            return nil
        }
        set {
            if let newValue { sheet = .webDialog(newValue) }
            else if dialog != nil { sheet = nil }
        }
    }

    func canPresentDialog(from tabID: UUID) -> Bool {
        isActive && !isClearingData && selectedID == tabID && sheet == nil
            && externalURL == nil && errorMessage == nil && downloads.errorMessage == nil
    }
    var lastClosed: TabRecord?
    var isClearingData = false
    private let store: BrowserStore
    private let writer: BrowserArchiveWriter
    private var persistTask: Task<Void, Never>?
    enum BookmarkNameState: Equatable {
        case generating
        case suggested(String)
        case unavailable
    }
    private(set) var bookmarkNameStates: [UUID: BookmarkNameState] = [:]
    private var bookmarkNameTasks: [UUID: Task<Void, Never>] = [:]
    private var mediaTask: Task<Void, Never>?
    private var trimRetryTask: Task<Void, Never>?
    private var memoryObserver: NSObjectProtocol?
    private(set) var isTesting = false
    private(set) var persistenceAvailable = true
    private var trimming = false
    /// A trim requested mid-pass; true when any request was for memory pressure.
    private var queuedTrim: Bool?

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
        self.writer = BrowserArchiveWriter(store: store)
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
        if persistenceAvailable {
            store.prunePreviews(keeping: Set(archive.tabs.map(\.id)))
            store.pruneTabStates(keeping: Set(archive.tabs.map(\.id)))
        }
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
        // Only the browser menu's Pause action reads the visible tab's media state between
        // explicit refreshes. Unloading samples background tabs itself when it needs to.
        mediaTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await self?.refreshVisibleMedia()
            }
        }
    }

    isolated deinit {
        persistTask?.cancel(); mediaTask?.cancel(); trimRetryTask?.cancel()
        for task in bookmarkNameTasks.values { task.cancel() }
        if let memoryObserver { NotificationCenter.default.removeObserver(memoryObserver) }
    }

    func saveSoon() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            guard let self, self.persistenceAvailable else { return }
            do { try await self.writer.saveInBackground(self.archive) }
            catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = "Harbor could not save your session. \(error.localizedDescription)"
            }
        }
    }
    @discardableResult func saveNow() -> Bool {
        persistTask?.cancel()
        guard persistenceAvailable else { return false }
        do { try writer.save(archive); return true }
        catch { errorMessage = "Harbor could not save your session. \(error.localizedDescription)"; return false }
    }

    func activate() {
        isActive = true
        ensureSession(selectedID)
    }

    func deactivate() {
        // Save before going inactive; inactive browsers write nothing further.
        for session in sessions.values { saveState(of: session) }
        isActive = false
        for task in bookmarkNameTasks.values { task.cancel() }
        bookmarkNameTasks.removeAll()
        bookmarkNameStates.removeAll()
        persistTask?.cancel()
        writer.flush()
        sheet = nil
        externalURL = nil
        trimRetryTask?.cancel()
        trimRetryTask = nil
        for session in sessions.values { session.dispose() }
        sessions.removeAll()
    }

    func ensureSession(_ id: UUID) {
        guard isActive, !isClearingData, blocker.ready, sessions[id] == nil,
              let record = archive.tabs.first(where: { $0.id == id }), let url = record.url else { return }
        let session = TabSession(id: id, browser: self)
        sessions[id] = session
        blocker.apply(to: session.webView, url: url, settings: archive.settings)
        // Restore back/forward history, scroll and form state saved when the tab was unloaded.
        // Saved state can trail the tab (a navigation from the unloaded tab, or a page left
        // after the last save), so the record's address wins when they differ.
        if let state = store.loadTabState(id) {
            session.webView.interactionState = state
            if session.webView.url == url { return }
        }
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
        // Recency means "last visible", so the tab being left counts as just used.
        activeSession?.lastUsed = Date()
        activeSession?.captureSnapshot()
        if id != selectedID { dialog = nil }
        archive.selectedTabID = id
        archive.tabs[index].lastUsed = Date()
        sessions[id]?.lastUsed = Date()
        ensureSession(id)
        saveSoon()
        scheduleTrim()
    }
    func closeTab(_ id: UUID) {
        guard let index = archive.tabs.firstIndex(where: { $0.id == id }) else { return }
        if let previous = lastClosed {
            store.removePreview(previous.id)
            store.removeTabState(previous.id)
        }
        lastClosed = archive.tabs[index]
        // Undo close restores the page with its history, like any unloaded tab.
        if let session = sessions[id] { unload(session) }
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

    /// Returns false when the preview was not saved; the caller then keeps it in memory.
    @discardableResult func savePreview(_ image: UIImage, for session: TabSession) -> Bool {
        guard isActive, !isClearingData, persistenceAvailable, sessions[session.id] === session else { return false }
        // A preview failure must not interrupt browsing; the live thumbnail remains available.
        do { try store.savePreview(image, id: session.id); return true } catch { return false }
    }

    /// Release background pages without removing their tab records or saved previews.
    func unloadBackgroundTabs() async {
        await refreshMedia()
        for session in Array(sessions.values) {
            guard session.id != selectedID, session.mediaState != .playing,
                  !session.fullscreen, !session.isLoading else { continue }
            unload(session)
        }
    }

    /// Release a page's web process, keeping its tab, preview and saved state.
    private func unload(_ session: TabSession) {
        guard sessions[session.id] === session else { return }
        saveState(of: session)
        sessions.removeValue(forKey: session.id)
        session.dispose()
    }

    /// Saved state holds page history and form contents, so it follows the same rules as
    /// previews: profile-scoped, protected, and only for addresses Harbor would restore.
    private func saveState(of session: TabSession) {
        guard isActive, !isClearingData, persistenceAvailable, session.hasCommitted,
              archive.tabs.first(where: { $0.id == session.id })?.restorable.url != nil,
              let state = session.webView.interactionState as? Data else { return }
        try? store.saveTabState(state, id: session.id)
    }

    /// Free background pages before iOS suspends Harbor, and save the visible page so a
    /// relaunch or a terminated page process restores its history.
    func enteredBackground() async {
        if let session = activeSession { saveState(of: session) }
        await unloadBackgroundTabs()
    }

    func becameActive() async {
        // The visible page may have been unloaded after its process ended in the background.
        ensureSession(selectedID)
        await refreshMedia()
    }

    /// WebKit ends page processes under memory pressure, often while Harbor is in the background.
    func contentProcessTerminated(_ session: TabSession) {
        guard sessions[session.id] === session else { return }
        let visible = isActive && session.id == selectedID && UIApplication.shared.applicationState == .active
        guard visible else {
            // Selecting the tab, or returning to Harbor, restores it from saved state.
            unload(session)
            return
        }
        if let last = session.lastAutomaticReload, Date().timeIntervalSince(last) < 30 {
            session.loadError = "iOS released this page to free memory. Reload to continue."
            session.isLoading = false
            return
        }
        session.lastAutomaticReload = Date()
        reload()
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
        let updatedTitle = title.flatMap { $0.isEmpty ? nil : $0 } ?? archive.tabs[index].title
        guard archive.tabs[index].url != url || archive.tabs[index].title != updatedTitle else { return }
        archive.tabs[index].url = url
        archive.tabs[index].title = updatedTitle
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
            if !isTesting { requestBookmarkName(bookmark) }
            #if DEBUG
            if isTesting && ProcessInfo.processInfo.arguments.contains("--bookmark-name-fixture") {
                requestBookmarkName(bookmark)
            }
            #endif
        }
    }

    @discardableResult
    func requestBookmarkName(_ bookmark: Bookmark,
                             generate: ((String, URL) async -> String?)? = nil) -> Task<Void, Never>? {
        guard isActive, archive.bookmarks.contains(where: { $0.id == bookmark.id }) else { return nil }
        keepOriginalBookmarkName(bookmark.id)
        bookmarkNameStates[bookmark.id] = .generating
        let task = Task { [weak self] in
            let name: String?
            if let generate {
                name = await generate(bookmark.title, bookmark.url)
            } else {
                #if DEBUG
                if self?.isTesting == true && ProcessInfo.processInfo.arguments.contains("--bookmark-name-fixture") {
                    try? await Task.sleep(for: .seconds(3))
                    name = "Harbor fixture guide"
                } else {
                    name = await BookmarkNaming.suggest(title: bookmark.title, url: bookmark.url)
                }
                #else
                name = await BookmarkNaming.suggest(title: bookmark.title, url: bookmark.url)
                #endif
            }
            guard !Task.isCancelled, let self, self.isActive,
                  self.archive.bookmarks.contains(where: { $0.id == bookmark.id && $0.title == bookmark.title }) else { return }
            self.bookmarkNameTasks[bookmark.id] = nil
            let normalized = name.map(BookmarkNaming.normalized)
            if let normalized, !normalized.isEmpty, normalized.count <= 80 {
                self.bookmarkNameStates[bookmark.id] = .suggested(normalized)
            } else {
                self.bookmarkNameStates[bookmark.id] = .unavailable
            }
        }
        bookmarkNameTasks[bookmark.id] = task
        return task
    }

    func useSuggestedBookmarkName(_ id: UUID) {
        guard case .suggested(let name) = bookmarkNameStates[id] else { return }
        renameBookmark(id, to: name)
    }

    func keepOriginalBookmarkName(_ id: UUID) {
        bookmarkNameTasks.removeValue(forKey: id)?.cancel()
        bookmarkNameStates[id] = nil
    }

    func renameBookmark(_ id: UUID, to title: String) {
        let title = BookmarkNaming.normalized(title)
        guard isActive, !title.isEmpty,
              let index = archive.bookmarks.firstIndex(where: { $0.id == id }) else { return }
        keepOriginalBookmarkName(id)
        archive.bookmarks[index].title = title
        saveNow()
    }

    func deleteBookmark(_ id: UUID) {
        keepOriginalBookmarkName(id)
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
    private func refreshVisibleMedia() async {
        guard isActive, UIApplication.shared.applicationState == .active else { return }
        await activeSession?.refreshMediaState()
    }

    /// Live pages kept before the least recently used background tab is unloaded.
    /// Unloaded tabs restore their history, so the budget favours memory over reload time.
    nonisolated static func liveTabLimit(physicalMemory: UInt64, availableMemory: Int) -> Int {
        let limit = switch physicalMemory {
        case ..<3_500_000_000: 2
        case ..<5_000_000_000: 3
        case ..<7_000_000_000: 4
        case ..<10_000_000_000: 6
        default: 8
        }
        // Zero means no process limit applies, as in the simulator.
        if availableMemory > 0 && availableMemory < 300_000_000 { return min(limit, 2) }
        return limit
    }
    var liveTabLimit: Int {
        Self.liveTabLimit(physicalMemory: ProcessInfo.processInfo.physicalMemory,
                          availableMemory: os_proc_available_memory())
    }

    /// Called when a tab that could not be unloaded may now be, such as after loading finishes.
    func scheduleTrim() {
        Task { await trimSessions() }
    }

    func trimSessions(memoryPressure: Bool = false) async {
        if memoryPressure { for session in sessions.values { session.snapshot = nil } }
        guard !trimming else {
            queuedTrim = (queuedTrim ?? false) || memoryPressure
            return
        }
        trimming = true
        defer { trimming = false }
        var next: Bool? = memoryPressure
        while let pressure = next {
            await trimPass(memoryPressure: pressure)
            next = queuedTrim
            queuedTrim = nil
        }
    }

    private func trimPass(memoryPressure: Bool) async {
        let limit = memoryPressure ? 1 : liveTabLimit
        guard sessions.count > limit else { return }
        var deferred = false
        let candidates = sessions.values.filter { $0.id != selectedID }.sorted { $0.lastUsed < $1.lastUsed }
        for session in candidates where sessions.count > limit {
            guard !session.fullscreen, !session.isLoading || memoryPressure else { deferred = true; continue }
            // Sample media only for tabs about to be unloaded.
            // Native media state is sampled, not a claim about every embedded player.
            await session.refreshMediaState()
            guard sessions[session.id] === session, session.id != selectedID else { continue }
            guard session.mediaState != .playing else { deferred = true; continue }
            unload(session)
        }
        // Loading and full-screen tabs recheck on their own; playing media needs a slow retry.
        if deferred && sessions.count > limit { scheduleTrimRetry() }
    }

    private func scheduleTrimRetry() {
        guard trimRetryTask == nil else { return }
        trimRetryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self else { return }
            self.trimRetryTask = nil
            await self.trimSessions()
        }
    }
    func clearWebsiteData(site: String? = nil) async {
        guard !isClearingData else { return }
        isClearingData = true
        // Clear preview pixels too, including unloaded tabs and the undo-close record.
        // Clearing all previews for site deletion is deliberately conservative.
        store.prunePreviews(keeping: [])
        store.pruneTabStates(keeping: [])
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
            downloads.clearTemporaryFiles()
        }
        // Preserve the save guard after a failed load; the fallback archive is incomplete.
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
