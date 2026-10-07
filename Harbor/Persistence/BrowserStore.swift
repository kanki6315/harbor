import Foundation

/// A versioned, atomic snapshot. Cookies and website storage belong exclusively to WebKit.
struct BrowserStore {
    let fileURL: URL
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Harbor/browser.json")
    }
    func load() throws -> BrowserArchive {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return BrowserArchive() }
        let archive = try JSONDecoder().decode(BrowserArchive.self, from: Data(contentsOf: fileURL))
        guard archive.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return archive
    }
    func save(_ archive: BrowserArchive) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(archive)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
