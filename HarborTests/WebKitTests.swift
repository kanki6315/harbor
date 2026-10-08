// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
