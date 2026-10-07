import XCTest
import WebKit
@testable import Harbor

@MainActor final class WebKitTests: XCTestCase {
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
