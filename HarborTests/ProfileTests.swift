import XCTest
import WebKit
import Network
@testable import Harbor

@MainActor final class ProfileTests: XCTestCase {
    func testProtectionPersistsAndLocksOnSwitchBackgroundAndRelaunch() async throws {
        let manager = ProfileManager(store: store, authenticate: { _ in true })
        let id = try XCTUnwrap(manager.currentProfile?.id)
        let enabled = await manager.setProtection(id, enabled: true)
        XCTAssertTrue(enabled)
        XCTAssertFalse(manager.isLocked)
        XCTAssertNotNil(manager.browser)
        XCTAssertTrue(manager.create(name: "Work", symbol: "briefcase"))
        let work = try XCTUnwrap(manager.profiles.last?.id)
        XCTAssertTrue(manager.select(work))
        XCTAssertTrue(manager.select(id))
        XCTAssertTrue(manager.isLocked)
        XCTAssertNil(manager.browser)
        await manager.unlockSelected()
        XCTAssertFalse(manager.isLocked)
        XCTAssertNotNil(manager.browser)
        manager.enteredBackground()
        XCTAssertTrue(manager.isLocked)
        XCTAssertNil(manager.browser)
        manager.becameActive()
        XCTAssertTrue(manager.isLocked)
        XCTAssertNil(manager.browser)
        let relaunched = ProfileManager(store: store)
        XCTAssertTrue(relaunched.isLocked)
        XCTAssertNil(relaunched.browser)
    }

    func testFailedAuthenticationCannotUnlockDisableOrDelete() async throws {
        let setup = ProfileManager(store: store, authenticate: { _ in true })
        let id = try XCTUnwrap(setup.currentProfile?.id)
        _ = await setup.setProtection(id, enabled: true)
        XCTAssertTrue(setup.create(name: "Work", symbol: "briefcase"))
        let manager = ProfileManager(store: store, authenticate: { _ in false })
        await manager.unlockSelected()
        XCTAssertNil(manager.browser)
        let disabled = await manager.setProtection(id, enabled: false)
        XCTAssertFalse(disabled)
        await manager.delete(id)
        XCTAssertTrue(manager.currentProfile?.isProtected == true)
        XCTAssertEqual(manager.profiles.count, 2)
    }

    func testBackgroundDuringAuthenticationDiscardsSuccess() async throws {
        let setup = ProfileManager(store: store, authenticate: { _ in true })
        let id = try XCTUnwrap(setup.currentProfile?.id)
        _ = await setup.setProtection(id, enabled: true)
        var continuation: CheckedContinuation<Bool, Never>?
        let manager = ProfileManager(store: store, authenticate: { _ in
            await withCheckedContinuation { continuation = $0 }
        })
        let task = Task { await manager.unlockSelected() }
        while continuation == nil { await Task.yield() }
        manager.enteredBackground()
        continuation?.resume(returning: true)
        await task.value
        XCTAssertTrue(manager.isLocked)
        XCTAssertNil(manager.browser)
    }

    func testOldProfilesDecodeWithoutLock() throws {
        let id = UUID()
        let json = "{\"id\":\"\(id)\",\"name\":\"Personal\",\"symbol\":\"house\",\"usesLegacyWebStore\":false,\"isDeleting\":false}"
        XCTAssertFalse(try JSONDecoder().decode(BrowserProfile.self, from: Data(json.utf8)).isProtected)
    }

    private var root: URL!
    private var store: ProfileStore { ProfileStore(root: root) }
    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appending(path: "ProfileTests-\(UUID().uuidString)")
    }
    override func tearDown() async throws {
        if let registry = try? store.loadOrMigrate() {
            for profile in registry.profiles where !profile.usesLegacyWebStore {
                try? await WKWebsiteDataStore.remove(forIdentifier: profile.id)
                try? DownloadManager.removeFiles(profileID: profile.id)
            }
        }
        try? FileManager.default.removeItem(at: root)
    }

    func testMigrationPreservesArchiveAndLegacyLoginsWithoutReimport() throws {
        var legacy = BrowserArchive()
        legacy.tabs = [TabRecord(url: URL(string: "https://example.com"), title: "Original")]
        legacy.history = [HistoryEntry(url: URL(string: "https://example.com")!, title: "Original")]
        legacy.bookmarks = [Bookmark(url: URL(string: "https://example.com")!, title: "Saved")]
        legacy.settings.searchEngine = .bing
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(legacy).write(to: store.legacyURL)
        let registry = try store.loadOrMigrate()
        XCTAssertTrue(registry.profiles[0].usesLegacyWebStore)
        let archive = try store.browserStore(for: registry.selectedProfileID).load()
        XCTAssertEqual(archive.history, legacy.history)
        XCTAssertEqual(archive.tabs, legacy.tabs)
        XCTAssertEqual(archive.bookmarks, legacy.bookmarks)
        XCTAssertEqual(archive.settings, legacy.settings)
        try store.browserStore(for: registry.selectedProfileID).save(BrowserArchive())
        let second = try store.loadOrMigrate()
        XCTAssertEqual(second.profiles, registry.profiles)
        XCTAssertTrue(try store.browserStore(for: second.selectedProfileID).load().history.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.legacyURL.path))
    }

    func testExistingProfilesMigrateIncludingInactiveProfileAndTimestamp() throws {
        let personal = BrowserProfile(name: "Personal")
        let work = BrowserProfile(name: "Work")
        let timestamp = Date(timeIntervalSince1970: 12345)
        let registry = ProfileRegistry(profiles: [personal, work], selectedProfileID: personal.id,
                                       defaultProfileID: personal.id, backgroundedAt: timestamp)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(registry).write(to: store.registryURL)
        for profile in registry.profiles {
            let browserStore = store.browserStore(for: profile.id)
            try FileManager.default.createDirectory(at: store.directory(for: profile.id), withIntermediateDirectories: true)
            var archive = BrowserArchive()
            archive.history = [HistoryEntry(url: URL(string: "https://private.example")!, title: profile.name)]
            try JSONEncoder().encode(archive).write(to: browserStore.fileURL)
        }
        let migrated = try store.loadOrMigrate()
        XCTAssertEqual(migrated.backgroundedAt, timestamp)
        XCTAssertFalse(try String(contentsOf: store.registryURL, encoding: .utf8).contains("backgroundedAt"))
        for profile in registry.profiles {
            let browserStore = store.browserStore(for: profile.id)
            XCTAssertFalse(FileManager.default.fileExists(atPath: browserStore.fileURL.path))
            XCTAssertEqual(try browserStore.load().history.first?.title, profile.name)
            XCTAssertEqual(try browserStore.sessionDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        }
    }

    func testBackupRestoreKeepsProfilesWithoutBrowsingOrBackgroundState() throws {
        let manager = ProfileManager(store: store)
        XCTAssertTrue(manager.create(name: "Work", symbol: "briefcase"))
        let work = manager.profiles.last!.id
        XCTAssertTrue(manager.select(work))
        manager.browser!.archive.bookmarks = [Bookmark(url: URL(string: "https://saved.example")!, title: "Saved")]
        manager.browser!.recordVisit(url: URL(string: "https://private.example")!, title: "Private")
        manager.enteredBackground(at: Date(timeIntervalSince1970: 100))
        let durable = try String(contentsOf: store.registryURL, encoding: .utf8)
        XCTAssertFalse(durable.contains("backgroundedAt"))
        XCTAssertEqual(try store.runtimeDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        try FileManager.default.removeItem(at: store.runtimeDirectory)
        for profile in manager.profiles {
            try FileManager.default.removeItem(at: store.browserStore(for: profile.id).sessionDirectory)
        }
        let restored = try store.loadOrMigrate()
        XCTAssertEqual(restored.profiles, manager.profiles)
        XCTAssertNil(restored.backgroundedAt)
        let archive = try store.browserStore(for: work).load()
        XCTAssertEqual(archive.bookmarks.count, 1)
        XCTAssertTrue(archive.history.isEmpty)
        XCTAssertNil(archive.tabs.first?.url)
        manager.browser?.deactivate()
    }

    func testCorruptRegistryAndLegacyArchiveAreNotOverwritten() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bytes = Data("corrupt".utf8)
        try bytes.write(to: store.legacyURL)
        XCTAssertThrowsError(try store.loadOrMigrate())
        XCTAssertEqual(try Data(contentsOf: store.legacyURL), bytes)
        try bytes.write(to: store.registryURL)
        let manager = ProfileManager(store: store)
        XCTAssertNil(manager.browser)
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertEqual(try Data(contentsOf: store.registryURL), bytes)
    }

    func testUnreadableProfileDoesNotPreventSwitchingToHealthyProfile() throws {
        let original = ProfileManager(store: store)
        XCTAssertTrue(original.create(name: "Work", symbol: "briefcase"))
        let personal = try XCTUnwrap(original.currentProfile?.id)
        let work = try XCTUnwrap(original.profiles.last?.id)
        let bytes = Data("corrupt".utf8)
        try bytes.write(to: store.browserStore(for: personal).fileURL)
        let manager = ProfileManager(store: store)
        XCTAssertNotNil(manager.browser?.errorMessage)
        XCTAssertTrue(manager.select(work))
        XCTAssertEqual(manager.currentProfile?.id, work)
        XCTAssertEqual(try Data(contentsOf: store.browserStore(for: personal).fileURL), bytes)
    }

    func testProfilesSeparateAllArchiveStateAndRestore() throws {
        let manager = ProfileManager(store: store)
        let personal = try XCTUnwrap(manager.browser)
        let personalID = personal.profileID
        personal.newTab(url: URL(string: "https://personal.invalid"))
        personal.recordVisit(url: URL(string: "https://personal.invalid")!, title: "Personal")
        personal.toggleBookmark()
        personal.archive.settings.searchEngine = .bing
        personal.archive.settings.siteExceptions = ["personal.invalid"]
        personal.closeTab(personal.selectedID)
        XCTAssertTrue(manager.create(name: "Work", symbol: "briefcase"))
        let workID = try XCTUnwrap(manager.profiles.last?.id)
        XCTAssertTrue(manager.select(workID))
        let work = try XCTUnwrap(manager.browser)
        XCTAssertTrue(work.archive.history.isEmpty)
        XCTAssertTrue(work.archive.bookmarks.isEmpty)
        XCTAssertEqual(work.archive.settings.searchEngine, .duckDuckGo)
        XCTAssertTrue(work.archive.settings.siteExceptions.isEmpty)
        XCTAssertNil(work.lastClosed)
        work.newTab()
        XCTAssertTrue(manager.rename(workID, name: "Office", symbol: "book"))
        XCTAssertEqual(work.profileName, "Office")
        XCTAssertTrue(manager.select(personalID))
        personal.undoClose()
        XCTAssertEqual(personal.selectedTab.url?.host, "personal.invalid")
        XCTAssertEqual(personal.archive.history.count, 1)
        XCTAssertEqual(personal.archive.bookmarks.count, 1)
        personal.saveNow()
        manager.enteredBackground()
        manager.browser?.deactivate()
        let relaunched = ProfileManager(store: store)
        XCTAssertEqual(relaunched.browser?.profileID, personalID)
        XCTAssertEqual(relaunched.browser?.archive.settings.searchEngine, .bing)
        XCTAssertEqual(relaunched.browser?.selectedTab.url?.host, "personal.invalid")
        XCTAssertTrue(relaunched.select(workID))
        XCTAssertEqual(relaunched.browser?.archive.tabs.count, 2)
        XCTAssertEqual(relaunched.currentProfile?.name, "Office")
        relaunched.browser?.deactivate()
    }

    func testTimeoutBoundaryResumeRelaunchNeverAndRepeatedBackgroundEvents() throws {
        let start = Date(timeIntervalSince1970: 10000)
        let manager = ProfileManager(store: store, now: start)
        let personal = try XCTUnwrap(manager.currentProfile?.id)
        XCTAssertTrue(manager.create(name: "Work", symbol: "briefcase"))
        let work = try XCTUnwrap(manager.profiles.last?.id)
        manager.configureReturn(defaultID: personal, minutes: 5)
        XCTAssertTrue(manager.select(work))
        manager.enteredBackground(at: start)
        manager.enteredBackground(at: start.addingTimeInterval(120))
        XCTAssertEqual(manager.registry?.backgroundedAt, start)
        manager.becameActive(at: start.addingTimeInterval(299))
        XCTAssertEqual(manager.currentProfile?.id, work)
        XCTAssertNil(manager.registry?.backgroundedAt)
        manager.enteredBackground(at: start)
        manager.becameActive(at: start.addingTimeInterval(300))
        XCTAssertEqual(manager.currentProfile?.id, personal)
        XCTAssertTrue(manager.select(work))
        manager.enteredBackground(at: start)
        let recent = ProfileManager(store: store, now: start.addingTimeInterval(299))
        XCTAssertEqual(recent.currentProfile?.id, work)
        recent.enteredBackground(at: start)
        let expired = ProfileManager(store: store, now: start.addingTimeInterval(300))
        XCTAssertEqual(expired.currentProfile?.id, personal)
        expired.configureReturn(defaultID: personal, minutes: nil)
        XCTAssertTrue(expired.select(work))
        expired.enteredBackground(at: start)
        let never = ProfileManager(store: store, now: start.addingTimeInterval(1000000))
        XCTAssertEqual(never.currentProfile?.id, work)
        // A clock moving backwards must not expire the interval.
        never.configureReturn(defaultID: personal, minutes: 1)
        never.enteredBackground(at: start)
        never.becameActive(at: start.addingTimeInterval(-60))
        XCTAssertEqual(never.currentProfile?.id, work)
    }

    func testCookieIsolationSharingRecreationAndScopedClear() async throws {
        let manager = ProfileManager(store: store)
        let personal = try XCTUnwrap(manager.browser)
        XCTAssertTrue(manager.create(name: "Work", symbol: "briefcase"))
        XCTAssertTrue(manager.select(manager.profiles.last!.id))
        let work = try XCTUnwrap(manager.browser)
        let url = URL(string: "https://profiles.invalid")!
        for (browser, value) in [(personal, "personal"), (work, "work")] {
            let cookie = try XCTUnwrap(HTTPCookie(properties: [.domain: "profiles.invalid", .path: "/", .name: "account", .value: value, .expires: Date().addingTimeInterval(3600)]))
            await browser.websiteDataStore.httpCookieStore.setCookie(cookie)
        }
        let first = TabSession(id: UUID(), browser: work)
        let second = TabSession(id: UUID(), browser: work)
        let cookies = await second.webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        XCTAssertEqual(cookies.first(where: { $0.name == "account" })?.value, "work")
        let reopenedStore = WKWebsiteDataStore(forIdentifier: personal.profileID)
        let restored = await reopenedStore.httpCookieStore.allCookies()
        XCTAssertEqual(restored.first(where: { $0.name == "account" })?.value, "personal")
        work.recordVisit(url: url, title: "Work")
        work.archive.bookmarks = [Bookmark(url: url, title: "Keep")]
        await work.clearWebsiteData(site: "profiles.invalid")
        let cleared = await work.websiteDataStore.httpCookieStore.allCookies()
        XCTAssertFalse(cleared.contains { $0.name == "account" })
        let retained = await personal.websiteDataStore.httpCookieStore.allCookies()
        XCTAssertEqual(retained.first(where: { $0.name == "account" })?.value, "personal")
        await work.clearWebsiteData()
        XCTAssertTrue(work.archive.history.isEmpty)
        XCTAssertEqual(work.archive.tabs.count, 1)
        XCTAssertEqual(work.archive.bookmarks.count, 1)
        first.dispose(); second.dispose()
    }

    func testLocalStorageIndexedDBAndSessionStorageIsolation() async throws {
        let manager = ProfileManager(store: store)
        let personal = try XCTUnwrap(manager.browser)
        XCTAssertTrue(manager.create(name: "Work", symbol: "briefcase"))
        XCTAssertTrue(manager.select(manager.profiles.last!.id))
        let work = try XCTUnwrap(manager.browser)
        let a = TabSession(id: UUID(), browser: personal)
        let b = TabSession(id: UUID(), browser: work)
        let secondA = TabSession(id: UUID(), browser: personal)
        for session in [a, b, secondA] {
            let loaded = expectation(description: "Storage page loaded")
            let loader = StoragePageLoader(loaded: loaded)
            session.webView.navigationDelegate = loader
            session.webView.loadHTMLString("<html><title>Storage fixture</title></html>", baseURL: URL(string: "https://profiles.invalid"))
            await fulfillment(of: [loaded], timeout: 10)
            withExtendedLifetime(loader) {}
        }
        _ = try await a.webView.evaluateJavaScript("localStorage.setItem('account', 'personal'); sessionStorage.setItem('account', 'personal');")
        _ = try await b.webView.evaluateJavaScript("localStorage.setItem('account', 'work'); sessionStorage.setItem('account', 'work');")
        let aLocal = try await secondA.webView.evaluateJavaScript("localStorage.getItem('account')") as? String
        let bLocal = try await b.webView.evaluateJavaScript("localStorage.getItem('account')") as? String
        XCTAssertEqual(aLocal, "personal")
        XCTAssertEqual(bLocal, "work")
        // Session storage is per tab as well as per profile.
        let secondSession = try await secondA.webView.evaluateJavaScript("sessionStorage.getItem('account') === null") as? Bool
        XCTAssertEqual(secondSession, true)
        let dbScript = """
        const db = await new Promise((resolve, reject) => {
            const request = indexedDB.open('profile-test', 1);
            request.onupgradeneeded = () => request.result.createObjectStore('accounts');
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error.message);
        });
        try {
            return await new Promise((resolve, reject) => {
                const transaction = db.transaction('accounts', value === null ? 'readonly' : 'readwrite');
                const store = transaction.objectStore('accounts');
                const request = value === null ? store.get('account') : store.put(value, 'account');
                transaction.oncomplete = () => resolve(value === null ? (request.result ?? 'empty') : value);
                transaction.onerror = () => reject(transaction.error.message);
            });
        } finally { db.close(); }
        """
        _ = try await a.webView.callAsyncJavaScript(dbScript, arguments: ["value": "personal"], in: nil, contentWorld: .page)
        let emptyB = try await b.webView.callAsyncJavaScript(dbScript, arguments: ["value": NSNull()], in: nil, contentWorld: .page) as? String
        XCTAssertEqual(emptyB, "empty")
        _ = try await b.webView.callAsyncJavaScript(dbScript, arguments: ["value": "work"], in: nil, contentWorld: .page)
        let sharedA = try await secondA.webView.callAsyncJavaScript(dbScript, arguments: ["value": NSNull()], in: nil, contentWorld: .page) as? String
        XCTAssertEqual(sharedA, "personal")
        // Clearing one profile's disk stores leaves the other profile intact.
        a.dispose(); secondA.dispose(); b.dispose()
        await work.clearWebsiteData()
        let retained = await personal.websiteDataStore.dataRecords(ofTypes: [WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeIndexedDBDatabases])
        let cleared = await work.websiteDataStore.dataRecords(ofTypes: [WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeIndexedDBDatabases])
        XCTAssertFalse(retained.isEmpty)
        XCTAssertTrue(cleared.isEmpty)
    }

    func testPopupInheritsProfileAndDisposedSessionCannotWriteHistory() async throws {
        let manager = ProfileManager(store: store)
        let browser = try XCTUnwrap(manager.browser)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = browser.websiteDataStore
        let popup = try XCTUnwrap(browser.createPopup(configuration: configuration, url: nil))
        XCTAssertEqual(popup.configuration.websiteDataStore.identifier, browser.profileID)
        let session = try XCTUnwrap(browser.activeSession)
        XCTAssertNil(browser.createPopup(configuration: WKWebViewConfiguration(), url: nil))
        XCTAssertTrue(manager.create(name: "Work", symbol: "briefcase"))
        XCTAssertTrue(manager.select(manager.profiles.last!.id))
        XCTAssertTrue(session.isDisposed)
        XCTAssertNil(session.browser)
        XCTAssertTrue(browser.sessions.isEmpty)
        browser.recordVisit(url: URL(string: "https://late.invalid")!, title: "Late callback")
        XCTAssertTrue(browser.archive.history.isEmpty)
        XCTAssertTrue(manager.browser!.archive.history.isEmpty)
    }

    func testDeletionFailureCanBeRetriedWithoutTouchingAnotherProfile() async throws {
        let manager = ProfileManager(store: store)
        let personal = try XCTUnwrap(manager.currentProfile?.id)
        XCTAssertTrue(manager.create(name: "Work", symbol: "briefcase"))
        let work = manager.profiles.last!.id
        XCTAssertTrue(manager.select(work))
        var retainedView: WKWebView? = TabSession(id: UUID(), browser: manager.browser!).webView
        await manager.delete(work)
        XCTAssertNotNil(retainedView)
        XCTAssertEqual(manager.pendingDeletions.map(\.id), [work])
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertEqual(manager.currentProfile?.id, personal)
        retainedView = nil
        await manager.delete(work)
        XCTAssertTrue(manager.pendingDeletions.isEmpty)
        XCTAssertNil(manager.errorMessage)
        XCTAssertEqual(manager.profiles.map(\.id), [personal])
    }

    func testDownloadCompletesInOriginProfileAfterSwitching() async throws {
        let server = try DownloadFixtureServer()
        let port = try await server.start()
        defer { server.stop() }
        let manager = ProfileManager(store: store)
        let personal = try XCTUnwrap(manager.browser)
        let session = TabSession(id: UUID(), browser: personal)
        let download = await session.webView.startDownload(using: URLRequest(url: URL(string: "http://127.0.0.1:\(port)/file")!))
        personal.downloads.accept(download)
        XCTAssertTrue(manager.create(name: "Work", symbol: "briefcase"))
        XCTAssertTrue(manager.select(manager.profiles.last!.id))
        session.dispose()
        for _ in 0..<100 where personal.downloads.completed == nil && personal.downloads.errorMessage == nil {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertNil(personal.downloads.errorMessage)
        let file = try XCTUnwrap(personal.downloads.completed?.url)
        XCTAssertTrue(file.path.hasPrefix(personal.downloads.directory.path))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "profile-owned download")
        XCTAssertNil(manager.browser?.downloads.completed)
        XCTAssertEqual(manager.browser?.downloads.activeCount, 0)
        XCTAssertTrue(manager.select(personal.profileID))
        XCTAssertEqual(manager.browser?.downloads.completed?.url, file)
    }

    func testDownloadFilesClearOnlyTheirOwnerAndDeletionFallsBack() async throws {
        let manager = ProfileManager(store: store)
        let personalID = try XCTUnwrap(manager.currentProfile?.id)
        let personalDirectory = try XCTUnwrap(manager.browser?.downloads.directory)
        try FileManager.default.createDirectory(at: personalDirectory, withIntermediateDirectories: true)
        try Data("personal".utf8).write(to: personalDirectory.appending(path: "file"))
        XCTAssertTrue(manager.create(name: "Work", symbol: "briefcase"))
        let workID = manager.profiles.last!.id
        XCTAssertTrue(manager.select(workID))
        let workDirectory = try XCTUnwrap(manager.browser?.downloads.directory)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        try Data("work".utf8).write(to: workDirectory.appending(path: "file"))
        manager.browser?.downloads.clearTemporaryFiles()
        XCTAssertTrue(FileManager.default.fileExists(atPath: personalDirectory.appending(path: "file").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: workDirectory.path))
        manager.configureReturn(defaultID: workID, minutes: 30)
        await manager.delete(workID)
        XCTAssertNil(manager.errorMessage)
        XCTAssertEqual(manager.currentProfile?.id, personalID)
        XCTAssertEqual(manager.registry?.defaultProfileID, personalID)
        XCTAssertEqual(manager.profiles.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory(for: workID).path))
        let identifiers = await WKWebsiteDataStore.allDataStoreIdentifiers
        XCTAssertFalse(identifiers.contains(workID))
        await manager.delete(personalID)
        XCTAssertEqual(manager.profiles.count, 1, "The last profile cannot be deleted")
        XCTAssertEqual(try store.loadOrMigrate().defaultProfileID, personalID)
    }
}

@MainActor private final class StoragePageLoader: NSObject, WKNavigationDelegate {
    let loaded: XCTestExpectation
    init(loaded: XCTestExpectation) { self.loaded = loaded }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded.fulfill() }
}

private final class DownloadFixtureServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "Harbor.download-fixture")
    init() throws { listener = try NWListener(using: .tcp, on: .any) }
    func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume(returning: listener.port!.rawValue)
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default: break
                }
            }
            listener.newConnectionHandler = { [queue] connection in
                connection.start(queue: queue)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { _, _, _, _ in
                    let body = Data("profile-owned download".utf8)
                    let header = Data("HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=profile.txt\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
                    connection.send(content: header, completion: .contentProcessed { _ in
                        queue.asyncAfter(deadline: .now() + 1) {
                            connection.send(content: body, completion: .contentProcessed { _ in connection.cancel() })
                        }
                    })
                }
            }
            listener.start(queue: queue)
        }
    }
    func stop() { listener.cancel() }
}
