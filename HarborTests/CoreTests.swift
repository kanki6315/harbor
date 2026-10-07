import XCTest
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

}
