// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
import UIKit
import WebKit
@testable import Harbor

final class CoreTests: XCTestCase {
    @MainActor func testTabGroupsPersistAndDeleteWithoutClosingTabs() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(fileURL: directory.appending(path: "browser.json"))
        let browser = BrowserModel(store: store, isTesting: true)
        defer { browser.deactivate() }
        let first = browser.selectedID
        let group = try XCTUnwrap(browser.createTabGroup(name: "  Research  ", tabID: first))
        let second = browser.newTab()
        XCTAssertEqual(browser.groupedTabs.map(\.id), [first, second])
        XCTAssertEqual(browser.selectedTabGroup?.name, "Research")
        browser.renameTabGroup(group, name: "Reading")
        XCTAssertTrue(browser.saveNow())
        let restored = try store.load()
        XCTAssertEqual(restored.tabGroups, [TabGroup(id: group, name: "Reading")])
        XCTAssertEqual(restored.selectedTabGroupID, group)
        XCTAssertTrue(restored.tabs.allSatisfy { $0.groupID == group })
        let otherStore = BrowserStore(fileURL: directory.appending(path: "other/browser.json"))
        XCTAssertTrue(try otherStore.load().tabGroups.isEmpty)
        browser.closeTab(second)
        browser.deleteTabGroup(group)
        browser.undoClose()
        XCTAssertEqual(browser.archive.tabs.map(\.id), [first, second])
        XCTAssertTrue(browser.archive.tabs.allSatisfy { $0.groupID == nil })
        XCTAssertNil(browser.archive.selectedTabGroupID)
        XCTAssertTrue(browser.archive.tabGroups.isEmpty)
        XCTAssertTrue(browser.saveNow())
        XCTAssertTrue(try store.load().tabGroups.isEmpty)
    }

    @MainActor func testTabGroupMovesAndEmptyGroupRemainUsable() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let browser = BrowserModel(store: BrowserStore(fileURL: directory.appending(path: "browser.json")), isTesting: true)
        defer { browser.deactivate() }
        let first = browser.selectedID
        XCTAssertNil(browser.createTabGroup(name: " \n "))
        let group = try XCTUnwrap(browser.createTabGroup(name: "Work"))
        XCTAssertTrue(browser.groupedTabs.isEmpty)
        let second = browser.newTab()
        browser.moveTab(first, toGroup: group)
        browser.closeTab(second)
        browser.undoClose()
        XCTAssertEqual(browser.selectedTab.groupID, group)
        browser.moveTab(first, toGroup: UUID())
        XCTAssertEqual(browser.archive.tabs.first?.groupID, group)
        browser.moveTab(first, toGroup: nil)
        browser.closeTab(second)
        XCTAssertEqual(browser.archive.selectedTabGroupID, group)
        XCTAssertTrue(browser.groupedTabs.isEmpty)
        browser.selectTabGroup(nil)
        XCTAssertEqual(browser.groupedTabs.map(\.id), [first])
        browser.selectTabGroup(UUID())
        XCTAssertNil(browser.archive.selectedTabGroupID)
    }

    func testPreGroupArchivesStillDecode() throws {
        let archive = BrowserArchive()
        let encoded = try JSONEncoder().encode(archive)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "tabGroups")
        json.removeValue(forKey: "selectedTabGroupID")
        let restored = try JSONDecoder().decode(BrowserArchive.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(restored.tabGroups.isEmpty)
        XCTAssertNil(restored.tabs.first?.groupID)
    }

    func testSettingsFromBeforeStatusBarFitStillDecode() throws {
        var settings = BrowserSettings()
        settings.searchEngine = .bing
        settings.fitBesideStatusBar = true
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        XCTAssertEqual(try JSONDecoder().decode(BrowserSettings.self, from: JSONSerialization.data(withJSONObject: json)), settings)
        json.removeValue(forKey: "fitBesideStatusBar")
        let restored = try JSONDecoder().decode(BrowserSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.searchEngine, .bing)
        XCTAssertFalse(restored.fitBesideStatusBar)
    }

    func testAddressResolution() {
        XCTAssertEqual(AddressResolver.resolve("example.com/path", engine: .duckDuckGo)?.absoluteString, "https://example.com/path")
        XCTAssertEqual(AddressResolver.resolve("a search & more", engine: .google)?.host, "www.google.com")
        XCTAssertNil(AddressResolver.resolve("  ", engine: .bing))
    }
    func testAddressSuggestionsRankLocalPages() throws {
        let tab = TabRecord(url: URL(string: "https://github.com/apple/swift"), title: "apple/swift")
        let history = [
            HistoryEntry(url: URL(string: "https://www.apple.com/")!, title: "Apple"),
            HistoryEntry(url: URL(string: "https://apple.com")!, title: "Apple"),
            HistoryEntry(url: URL(string: "https://example.com/pineapple-recipes")!, title: "Pineapple recipes"),
            HistoryEntry(url: URL(string: "mailto:apple@example.com")!, title: "Mail")
        ]
        let bookmarks = [Bookmark(url: URL(string: "https://developer.apple.com/documentation")!, title: "Apple Developer Documentation")]
        let results = AddressSuggestions.rank("app", tabs: [tab], bookmarks: bookmarks, history: history)
        // One row per page however it was visited, and only web addresses.
        XCTAssertEqual(results.map(\.id), ["apple.com", "developer.apple.com/documentation", "github.com/apple/swift", "example.com/pineapple-recipes"])
        XCTAssertEqual(results[1].kind, .bookmark)
        XCTAssertEqual(results[2].kind, .tab(tab.id))
        XCTAssertEqual(AddressSuggestions.rank("https://www.apple", tabs: [], bookmarks: [], history: history).first?.id, "apple.com")
        XCTAssertEqual(AddressSuggestions.rank("pineapple recipes", tabs: [], bookmarks: [], history: history).map(\.id), ["example.com/pineapple-recipes"])
        XCTAssertTrue(AddressSuggestions.rank("  ", tabs: [tab], bookmarks: bookmarks, history: history).isEmpty)
        XCTAssertTrue(AddressSuggestions.rank("zzz", tabs: [tab], bookmarks: bookmarks, history: history).isEmpty)
    }

    func testDottedSearchTermsAndExplicitAddresses() {
        for term in ["node.js", "3.14", "v1.2", "999.999.999.999", "notlan", "router.internalish", "corp"] {
            XCTAssertEqual(AddressResolver.resolve(term, engine: .google), SearchEngine.google.searchURL(term))
        }
        for address in ["example.com/path", "example.dev", "localhost:8080", "192.168.1.1", "[::1]:8080", "例え.みんな", "münchen.de", "例子.中国", "[::1]",
                        "nas.lan", "router.internal", "host.corp", "server.home.arpa", "nas.lan:8080/files"] {
            XCTAssertEqual(AddressResolver.resolve(address, engine: .google), URL(string: "https://" + address))
        }
        XCTAssertEqual(AddressResolver.resolve("https://node.js", engine: .google), URL(string: "https://node.js"))
    }

    func testTransientTabURLsAreNotSavedOrRestored() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(fileURL: directory.appending(path: "browser.json"))
        var archive = BrowserArchive()
        archive.tabs = ["data:text/plain," + String(repeating: "x", count: 100_000),
                        "blob:https://example.com/id", "about:blank", "https://example.com"].map {
            TabRecord(url: URL(string: $0)!, title: "Live page")
        }
        archive.selectedTabID = archive.tabs[1].id
        try store.save(archive)
        XCTAssertNotNil(archive.tabs[0].url, "Saving must not replace live in-memory addresses")
        XCTAssertLessThan(try Data(contentsOf: store.sessionURL).count, 3000)
        let restored = try store.load()
        XCTAssertTrue(restored.tabs.prefix(3).allSatisfy { $0.url == nil && $0.title == "New Tab" })
        XCTAssertEqual(restored.tabs.last?.url, archive.tabs.last?.url)
        XCTAssertEqual(restored.selectedTabID, archive.selectedTabID)
        // Existing mixed archives also get sanitized during migration.
        try JSONEncoder().encode(archive).write(to: store.fileURL)
        XCTAssertTrue(try store.load().tabs.prefix(3).allSatisfy { $0.url == nil })
    }

    func testCleanerPreservesEncodingAndSignedMedia() {
        let plain = URL(string: "https://example.com/?q=a%20b&utm_source=test&x=%2F#part")!
        XCTAssertEqual(TrackingParameterCleaner.clean(plain).absoluteString, "https://example.com/?q=a%20b&x=%2F#part")
        for text in ["https://example.com/a.m3u8?utm_source=x", "https://example.com/?signature=abc&utm_source=x", "https://example.com/?X-Amz-Signature=abc&fbclid=x"] {
            let url = URL(string: text)!
            XCTAssertEqual(TrackingParameterCleaner.clean(url), url)
        }
    }
    func testArchiveRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(fileURL: directory.appending(path: "browser.json"))
        var archive = BrowserArchive()
        archive.tabs = [TabRecord(url: URL(string: "https://example.com"), title: "Example")]
        archive.selectedTabID = archive.tabs[0].id
        archive.settings.siteExceptions = ["example.com"]
        try store.save(archive)
        let restored = try store.load()
        XCTAssertEqual(restored.tabs, archive.tabs)
        XCTAssertEqual(restored.selectedTabID, archive.selectedTabID)
        XCTAssertEqual(restored.settings, archive.settings)
    }
    func testBookmarksFromBeforeFoldersStillDecode() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(fileURL: directory.appending(path: "browser.json"))
        var archive = BrowserArchive()
        archive.bookmarks = [Bookmark(url: URL(string: "https://example.com")!, title: "Saved")]
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(archive)) as? [String: Any])
        legacy.removeValue(forKey: "bookmarkFolders")
        let decoded = try JSONDecoder().decode(BrowserArchive.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertTrue(decoded.bookmarkFolders.isEmpty)
        XCTAssertNil(decoded.bookmarks.first?.folderID)
        try store.save(archive)
        var preferences = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: store.durableURL)) as? [String: Any])
        preferences.removeValue(forKey: "bookmarkFolders")
        try JSONSerialization.data(withJSONObject: preferences).write(to: store.durableURL)
        XCTAssertEqual(try store.load().bookmarks, archive.bookmarks)
        XCTAssertTrue(try store.load().bookmarkFolders.isEmpty)
    }

    func testSplitStorageMigrationAndBackupRestore() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = BrowserStore(fileURL: directory.appending(path: "browser.json"))
        var original = BrowserArchive()
        let url = URL(string: "https://example.com/?secret=private")!
        original.tabs = [TabRecord(url: url, title: "Private")]
        original.selectedTabID = original.tabs[0].id
        original.history = [HistoryEntry(url: url, title: "Private")]
        original.bookmarks = [Bookmark(url: URL(string: "https://saved.example")!, title: "Saved")]
        original.settings.searchEngine = .bing
        try JSONEncoder().encode(original).write(to: store.fileURL)
        let migrated = try store.load()
        XCTAssertEqual(migrated.tabs, original.tabs)
        XCTAssertEqual(migrated.history, original.history)
        XCTAssertEqual(migrated.bookmarks, original.bookmarks)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(try store.sessionDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        let durable = try String(contentsOf: store.durableURL, encoding: .utf8)
        XCTAssertFalse(durable.contains("secret"))
        XCTAssertFalse(durable.contains("lastUsed"))
        try FileManager.default.removeItem(at: store.sessionDirectory)
        let restored = try store.load()
        XCTAssertEqual(restored.bookmarks, original.bookmarks)
        XCTAssertEqual(restored.settings, original.settings)
        XCTAssertTrue(restored.history.isEmpty)
        XCTAssertEqual(restored.tabs.count, 1)
        XCTAssertNil(restored.tabs[0].url)
        XCTAssertNil(restored.selectedTabID)
    }

    func testInterruptedMigrationRetainsSourceAndRetries() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = BrowserStore(fileURL: directory.appending(path: "browser.json"))
        var original = BrowserArchive()
        original.history = [HistoryEntry(url: URL(string: "https://private.example")!, title: "Private")]
        let bytes = try JSONEncoder().encode(original)
        try bytes.write(to: store.fileURL)
        // Block the second write after the session write succeeds.
        try FileManager.default.createDirectory(at: store.durableURL, withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: store.fileURL), bytes)
        XCTAssertEqual(try store.fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        try FileManager.default.removeItem(at: store.durableURL)
        XCTAssertEqual(try store.load().history, original.history)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    @MainActor func testReorderingPreservesSelectionAndSavedOrder() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(fileURL: directory.appending(path: "browser.json"))
        let browser = BrowserModel(store: store, isTesting: true)
        defer { browser.deactivate() }
        let first = browser.selectedID
        let second = browser.newTab()
        let third = browser.newTab()
        browser.moveTab(first, onto: third)
        XCTAssertEqual(browser.archive.tabs.map(\.id), [second, third, first])
        XCTAssertEqual(browser.selectedID, third)
        browser.moveTabs(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(browser.archive.tabs.map(\.id), [first, second, third])
        XCTAssertTrue(browser.saveNow())
        XCTAssertEqual(try store.load().tabs.map(\.id), [first, second, third])
        browser.moveTab(UUID(), onto: first)
        XCTAssertEqual(browser.archive.tabs.count, 3)
    }

    @MainActor func testSavedPreviewsAreProfileScopedAndPruned() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = BrowserStore(fileURL: directory.appending(path: "first/browser.json"))
        let second = BrowserStore(fileURL: directory.appending(path: "second/browser.json"))
        let id = UUID(), removed = UUID()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 48)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 48))
        }
        try first.savePreview(image, id: id)
        try first.savePreview(image, id: removed)
        XCTAssertNotNil(UIImage(contentsOfFile: first.previewURL(id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.previewURL(id).path))
        first.prunePreviews(keeping: [id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.previewURL(id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.previewURL(removed).path))
        first.removePreview(id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.previewURL(id).path))
    }

    @MainActor func testUnloadingKeepsPreviewAndTabButReleasesSession() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(fileURL: directory.appending(path: "browser.json"))
        let browser = BrowserModel(store: store, isTesting: true)
        defer { browser.deactivate() }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = browser.websiteDataStore
        _ = browser.createPopup(configuration: configuration, url: URL(string: "https://example.com"))
        let id = browser.selectedID
        let session = try XCTUnwrap(browser.sessions[id])
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 48)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 48))
        }
        browser.savePreview(image, for: session)
        browser.newTab()
        await browser.unloadBackgroundTabs()
        XCTAssertNil(browser.sessions[id])
        XCTAssertTrue(session.isDisposed)
        XCTAssertTrue(browser.archive.tabs.contains { $0.id == id })
        XCTAssertNotNil(UIImage(contentsOfFile: browser.previewURL(id).path))
        await browser.clearWebsiteData()
        XCTAssertFalse(FileManager.default.fileExists(atPath: browser.previewURL(id).path))
    }

    func testLiveTabLimitScalesWithDeviceAndHeadroom() {
        let gigabyte: UInt64 = 1_000_000_000
        XCTAssertEqual(BrowserModel.liveTabLimit(physicalMemory: 4 * gigabyte, availableMemory: 0), 3)
        XCTAssertEqual(BrowserModel.liveTabLimit(physicalMemory: 6 * gigabyte, availableMemory: 0), 4)
        XCTAssertEqual(BrowserModel.liveTabLimit(physicalMemory: 8 * gigabyte, availableMemory: 0), 6)
        XCTAssertEqual(BrowserModel.liveTabLimit(physicalMemory: 16 * gigabyte, availableMemory: 2_000_000_000), 8)
        XCTAssertEqual(BrowserModel.liveTabLimit(physicalMemory: 16 * gigabyte, availableMemory: 200_000_000), 2)
    }

    func testSavedTabStatesArePrunedWithTheirTabs() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(fileURL: directory.appending(path: "browser.json"))
        let kept = UUID(), removed = UUID(), closed = UUID()
        for id in [kept, removed, closed] { try store.saveTabState(Data(id.uuidString.utf8), id: id) }
        store.removeTabState(closed)
        XCTAssertNil(store.loadTabState(closed))
        store.pruneTabStates(keeping: [kept])
        XCTAssertEqual(store.loadTabState(kept), Data(kept.uuidString.utf8))
        XCTAssertNil(store.loadTabState(removed))
    }

}
