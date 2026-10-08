// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
import UIKit
import WebKit
@testable import Harbor

final class CoreTests: XCTestCase {
    func testAddressResolution() {
        XCTAssertEqual(AddressResolver.resolve("example.com/path", engine: .duckDuckGo)?.absoluteString, "https://example.com/path")
        XCTAssertEqual(AddressResolver.resolve("a search & more", engine: .google)?.host, "www.google.com")
        XCTAssertNil(AddressResolver.resolve("  ", engine: .bing))
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

}
