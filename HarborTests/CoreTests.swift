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
}
