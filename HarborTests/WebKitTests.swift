// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
import WebKit
@testable import Harbor

@MainActor final class WebKitTests: XCTestCase {
    func testTrackerRulesAreSharedAcrossProfiles() async {
        let first = ContentBlocker()
        let second = ContentBlocker()
        await first.prepare()
        await second.prepare()
        XCTAssertNotNil(first.ruleList)
        XCTAssertTrue(first.ruleList === second.ruleList)
    }

    func testAutosaveAndExplicitFlushKeepNewestState() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = BrowserStore(fileURL: folder.appending(path: "state.json"))
        let browser = BrowserModel(store: store)
        defer { browser.deactivate() }
        browser.updateTab(browser.selectedID, url: URL(string: "https://example.com/old")!, title: "Old")
        try await Task.sleep(for: .milliseconds(300))
        browser.updateTab(browser.selectedID, url: URL(string: "https://example.com/new")!, title: "New")
        XCTAssertTrue(browser.saveNow())
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(try store.load().tabs.first?.title, "New")
        browser.updateTab(browser.selectedID, url: URL(string: "https://example.com/latest")!, title: "Latest")
        try await Task.sleep(for: .milliseconds(500))
        browser.deactivate()
        XCTAssertEqual(try store.load().tabs.first?.title, "Latest")
    }

    func testPrivacyCoverIsAboveSheetsAndRemovedWhenDisabled() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.isHidden = false
        defer { window.isHidden = true }
        let host = ProfilePrivacyCover.HostView()
        window.rootViewController!.view.addSubview(host)
        host.enabled = true
        host.refresh(inactive: true)
        let cover = try XCTUnwrap(scene.windows.first { $0.accessibilityIdentifier == "profilePrivacyCover" && !$0.isHidden })
        XCTAssertGreaterThan(cover.windowLevel, window.windowLevel)
        XCTAssertNotNil(cover.rootViewController?.view.backgroundColor)
        host.enabled = false
        host.refresh(inactive: true)
        XCTAssertTrue(cover.isHidden)
    }

    func testRulesCompileAndConfigurationIsPersistent() async throws {
        let blocker = ContentBlocker()
        await blocker.prepare()
        XCTAssertNotNil(blocker.ruleList, blocker.failure ?? "Missing rule list")
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        MediaPolicy.configure(configuration)
        XCTAssertTrue(configuration.websiteDataStore.isPersistent)
        XCTAssertTrue(configuration.allowsInlineMediaPlayback)
        XCTAssertTrue(configuration.allowsAirPlayForMediaPlayback)
        XCTAssertTrue(configuration.allowsPictureInPictureMediaPlayback)
        XCTAssertEqual(configuration.mediaTypesRequiringUserActionForPlayback, .all)
        XCTAssertFalse(configuration.preferences.javaScriptCanOpenWindowsAutomatically)
    }

    func testTabRestoreCloseUndoAndMemoryBudget() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = BrowserStore(fileURL: folder.appending(path: "state.json"))
        let browser = BrowserModel(store: store)
        for index in 0..<40 { browser.newTab(url: URL(string: "https://example.com/\(index)")) }
        let selected = browser.selectedID
        browser.archive.settings.siteExceptions.insert("example.com")
        browser.saveNow()
        let restored = BrowserModel(store: store)
        XCTAssertEqual(restored.archive.tabs.count, 41)
        XCTAssertEqual(restored.selectedID, selected)
        XCTAssertTrue(restored.archive.settings.siteExceptions.contains("example.com"))
        restored.closeTab(selected)
        XCTAssertFalse(restored.archive.tabs.contains { $0.id == selected })
        restored.undoClose()
        XCTAssertEqual(restored.selectedID, selected)
        XCTAssertEqual(restored.archive.tabs.count, 41)
        XCTAssertLessThanOrEqual(restored.sessions.count, 1, "Restoration must be lazy")
    }

    func testUnloadedTabsRestoreHistoryAndReleaseEndedProcesses() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = BrowserStore(fileURL: folder.appending(path: "state.json"))
        let browser = BrowserModel(store: store, isTesting: true)
        defer { browser.deactivate() }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = browser.websiteDataStore
        _ = browser.createPopup(configuration: configuration, url: nil)
        let id = browser.selectedID
        let session = try XCTUnwrap(browser.sessions[id])
        let first = try XCTUnwrap(URL(string: "https://example.com/first"))
        let second = try XCTUnwrap(URL(string: "https://example.com/second"))
        // Simulated responses are real navigations with history entries, without network access.
        for url in [first, second] {
            session.webView.loadSimulatedRequest(URLRequest(url: url), responseHTML: "<p>\(url.path)</p>")
            try await waitUntil { !session.isLoading && browser.selectedTab.url == url }
        }

        browser.newTab()
        await browser.unloadBackgroundTabs()
        XCTAssertNil(browser.sessions[id])
        try await waitUntil { browser.blocker.ready }
        browser.selectTab(id)
        let restored = try XCTUnwrap(browser.sessions[id])
        XCTAssertFalse(restored === session)
        XCTAssertEqual(restored.webView.url, second)
        XCTAssertEqual(restored.webView.backForwardList.backList.map(\.url), [first])

        // A page process that ends in the background unloads its tab instead of holding a slot.
        browser.newTab()
        browser.contentProcessTerminated(restored)
        XCTAssertNil(browser.sessions[id])
        XCTAssertTrue(browser.archive.tabs.contains { $0.id == id })

        // Closing removes the saved state once undo is no longer possible.
        browser.closeTab(id)
        browser.closeTab(browser.selectedID)
        XCTAssertNil(store.loadTabState(id))
    }

    private func waitUntil(timeout: Duration = .seconds(10), _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else { XCTFail("Timed out"); return }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    func testRestoreDisabledKeepsBookmarksAndSettings() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = BrowserStore(fileURL: folder.appending(path: "state.json"))
        var archive = BrowserArchive()
        archive.tabs = [TabRecord(url: URL(string: "https://example.com"))]
        archive.settings.restoreTabs = false
        archive.bookmarks = [Bookmark(url: URL(string: "https://example.com")!, title: "Example")]
        try store.save(archive)
        let browser = BrowserModel(store: store)
        XCTAssertNil(browser.selectedTab.url)
        XCTAssertEqual(browser.archive.bookmarks.count, 1)
    }

    func testBookmarkNamesRequireAcceptanceAndIgnoreCancelledResults() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = BrowserStore(fileURL: folder.appending(path: "state.json"))
        let browser = BrowserModel(store: store, isTesting: true)
        let url = URL(string: "https://example.com/guide")!
        browser.archive.tabs[0].url = url
        browser.archive.tabs[0].title = "Travel Guide"
        browser.toggleBookmark()
        let original = try XCTUnwrap(browser.archive.bookmarks.first)
        let task = browser.requestBookmarkName(original) { _, _ in "Weekend in Maine" }
        XCTAssertEqual(browser.bookmarkNameStates[original.id], .generating)
        await task?.value
        XCTAssertEqual(browser.bookmarkNameStates[original.id], .suggested("Weekend in Maine"))
        XCTAssertEqual(try store.load().bookmarks.first?.title, "Travel Guide")
        browser.keepOriginalBookmarkName(original.id)
        XCTAssertNil(browser.bookmarkNameStates[original.id])
        XCTAssertEqual(try store.load().bookmarks.first?.title, "Travel Guide")
        await browser.requestBookmarkName(original) { _, _ in "Weekend in Maine" }?.value
        browser.useSuggestedBookmarkName(original.id)
        XCTAssertEqual(try store.load().bookmarks.first?.title, "Weekend in Maine")
        XCTAssertNil(browser.bookmarkNameStates[original.id])
        let current = try XCTUnwrap(browser.archive.bookmarks.first)
        let late = browser.requestBookmarkName(current) { _, _ in "Late suggestion" }
        browser.renameBookmark(original.id, to: "  My   trip ")
        await late?.value
        XCTAssertEqual(try store.load().bookmarks.first?.title, "My trip")
        XCTAssertNil(browser.bookmarkNameStates[original.id])
        let manual = try XCTUnwrap(browser.archive.bookmarks.first)
        let deleted = browser.requestBookmarkName(manual) { _, _ in "Deleted suggestion" }
        browser.deleteBookmark(original.id)
        browser.toggleBookmark()
        await deleted?.value
        XCTAssertEqual(browser.archive.bookmarks.first?.title, "Travel Guide")
        XCTAssertNil(browser.bookmarkNameStates[original.id])
        let replacement = try XCTUnwrap(browser.archive.bookmarks.first)
        await browser.requestBookmarkName(replacement) { _, _ in nil }?.value
        XCTAssertEqual(browser.bookmarkNameStates[replacement.id], .unavailable)
        XCTAssertEqual(browser.archive.bookmarks.first?.title, "Travel Guide")
        let cancelled = browser.requestBookmarkName(replacement) { _, _ in "Rejected name" }
        browser.keepOriginalBookmarkName(replacement.id)
        await cancelled?.value
        XCTAssertNil(browser.bookmarkNameStates[replacement.id])
        let inactive = browser.requestBookmarkName(replacement) { _, _ in "Inactive profile" }
        browser.deactivate()
        await inactive?.value
        XCTAssertTrue(browser.bookmarkNameStates.isEmpty)
        XCTAssertEqual(try store.load().bookmarks.first?.title, "Travel Guide")
    }

    func testBookmarkFoldersPersistAndDeletionPreservesPages() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = BrowserStore(fileURL: folder.appending(path: "state.json"))
        let browser = BrowserModel(store: store, isTesting: true)
        let travel = try XCTUnwrap(browser.createBookmarkFolder(named: "Travel"))
        XCTAssertEqual(browser.createBookmarkFolder(named: " travel "), travel)
        XCTAssertNil(browser.createBookmarkFolder(named: " "))
        browser.archive.tabs[0].url = URL(string: "https://example.com/guide")!
        browser.archive.tabs[0].title = "Guide"
        browser.toggleBookmark(folderID: travel)
        let bookmark = try XCTUnwrap(browser.archive.bookmarks.first)
        XCTAssertEqual(try store.load().bookmarks.first?.folderID, travel)
        let reading = try XCTUnwrap(browser.createBookmarkFolder(named: "Reading"))
        let naming = browser.requestBookmarkName(bookmark) { _, _ in "Travel guide" }
        browser.moveBookmark(bookmark.id, to: reading)
        await naming?.value
        browser.useSuggestedBookmarkName(bookmark.id)
        XCTAssertEqual(browser.archive.bookmarks.first?.title, "Travel guide")
        XCTAssertEqual(browser.archive.bookmarks.first?.folderID, reading)
        browser.renameBookmarkFolder(reading, to: "Read later")
        XCTAssertEqual(try store.load().bookmarkFolders.last?.name, "Read later")
        browser.renameBookmarkFolder(reading, to: "Travel")
        XCTAssertEqual(browser.archive.bookmarkFolders.last?.name, "Read later")
        browser.moveBookmark(bookmark.id, to: UUID())
        XCTAssertEqual(browser.archive.bookmarks.first?.folderID, reading)
        browser.deleteBookmarkFolder(reading)
        let restored = try store.load()
        XCTAssertEqual(restored.bookmarks.count, 1)
        XCTAssertNil(restored.bookmarks.first?.folderID)
        XCTAssertEqual(restored.bookmarkFolders.map(\.id), [travel])
        let other = BrowserModel(store: BrowserStore(fileURL: folder.appending(path: "other/state.json")), isTesting: true)
        XCTAssertTrue(other.archive.bookmarkFolders.isEmpty)
    }

    func testPersistentCookieStoreAcrossWebViews() async throws {
        let first = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let cookie = try XCTUnwrap(HTTPCookie(properties: [.domain: "harbor-test.invalid", .path: "/", .name: "harbor-test", .value: "persistent", .expires: Date().addingTimeInterval(3600)]))
        await first.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        let second = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let cookies = await second.configuration.websiteDataStore.httpCookieStore.allCookies()
        XCTAssertTrue(cookies.contains { $0.name == "harbor-test" && $0.value == "persistent" })
        await second.configuration.websiteDataStore.httpCookieStore.deleteCookie(cookie)
    }
}

extension WebKitTests {
    func testDownloadsRequireMainFrameAndOtherNavigationsAreNotRewritten() {
        for main in [false, true] {
            XCTAssertEqual(TabSession.downloadPolicy(isMainFrame: main), main ? .download : .cancel)
            XCTAssertEqual(TabSession.responsePolicy(isMainFrame: main, canShowMIMEType: false, disposition: ""),
                           main ? .download : .cancel)
            XCTAssertEqual(TabSession.responsePolicy(isMainFrame: main, canShowMIMEType: true,
                                                      disposition: "attachment; filename=test.txt"),
                           main ? .download : .cancel)
            XCTAssertEqual(TabSession.responsePolicy(isMainFrame: main, canShowMIMEType: true, disposition: ""), .allow)
            for type in [WKNavigationType.other, .backForward, .reload, .formSubmitted, .formResubmitted, .linkActivated] {
                for method in ["GET", "POST"] {
                    XCTAssertEqual(TabSession.canRewriteTrackingParameters(method: method, type: type, isMainFrame: main),
                                   main && type == .linkActivated && method == "GET")
                }
            }
        }
    }

    func testClearDataPreservesUnreadableArchives() async throws {
        for corruptedFile in ["preferences", "session", "legacy"] {
            let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: folder) }
            let store = BrowserStore(fileURL: folder.appending(path: "browser.json"))
            var archive = BrowserArchive()
            archive.bookmarks = [Bookmark(url: URL(string: "https://example.com")!, title: "Keep me")]
            archive.settings.siteExceptions.insert("example.com")
            try store.save(archive)
            let corruptURL = corruptedFile == "preferences" ? store.durableURL :
                (corruptedFile == "session" ? store.sessionURL : store.fileURL)
            try Data("unreadable archive".utf8).write(to: corruptURL)
            let preferences = try Data(contentsOf: store.durableURL)
            let corrupt = try Data(contentsOf: corruptURL)
            let browser = BrowserModel(store: store)
            defer { browser.deactivate() }
            XCTAssertFalse(browser.persistenceAvailable)
            await browser.clearWebsiteData()
            XCTAssertFalse(browser.persistenceAvailable)
            XCTAssertFalse(browser.saveNow())
            XCTAssertEqual(try Data(contentsOf: store.durableURL), preferences)
            XCTAssertEqual(try Data(contentsOf: corruptURL), corrupt)
        }
    }

    func testDialogsAreCancelledWhenBusyBackgroundedOrDisposed() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let browser = BrowserModel(store: BrowserStore(fileURL: folder.appending(path: "state.json")))
        defer { browser.deactivate() }
        let session = TabSession(id: browser.selectedID, browser: browser)
        defer { session.dispose() }
        XCTAssertTrue(browser.canPresentDialog(from: session.id))
        for sheet in [BrowserSheet.tabs, .settings, .history, .share(ShareItem(url: URL(string: "https://example.com")!))] {
            browser.sheet = sheet
            XCTAssertFalse(browser.canPresentDialog(from: session.id))
            XCTAssertNil(browser.dialog)
        }
        browser.sheet = nil
        var replies = 0
        let dialog = WebDialog(title: "example.com", message: "Confirm", kind: .confirm) { value in
            XCTAssertNil(value); replies += 1
        }
        browser.dialog = dialog
        XCTAssertFalse(browser.canPresentDialog(from: session.id))
        browser.newTab()
        XCTAssertNil(browser.dialog)
        XCTAssertEqual(replies, 1)
        dialog.finish(nil)
        XCTAssertEqual(replies, 1)
        XCTAssertFalse(browser.canPresentDialog(from: session.id))
        browser.selectTab(session.id)
        browser.dialog = WebDialog(title: "example.com", message: "Alert", kind: .alert) { _ in replies += 1 }
        session.dispose()
        XCTAssertNil(browser.dialog)
        XCTAssertEqual(replies, 2)
        browser.dialog = WebDialog(title: "example.com", message: "Dismiss", kind: .alert) { _ in replies += 1 }
        browser.sheet = nil
        XCTAssertEqual(replies, 3)
    }
}
