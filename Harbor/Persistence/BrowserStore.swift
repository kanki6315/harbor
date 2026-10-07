import Foundation
import UIKit

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

// Previews are local, disposable files scoped to the same profile as the archive.
// Keep them outside JSON so restoring many tabs never decodes every image.
extension BrowserStore {
    private var previewsURL: URL { fileURL.deletingLastPathComponent().appending(path: "TabPreviews") }
    func previewURL(_ id: UUID) -> URL { previewsURL.appending(path: "\(id.uuidString).jpg") }

    func savePreview(_ image: UIImage, id: UUID) throws {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        try FileManager.default.createDirectory(at: previewsURL, withIntermediateDirectories: true)
        var directory = previewsURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try data.write(to: previewURL(id), options: [.atomic, .completeFileProtection])
    }

    func removePreview(_ id: UUID) { try? FileManager.default.removeItem(at: previewURL(id)) }

    func prunePreviews(keeping ids: Set<UUID>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: previewsURL, includingPropertiesForKeys: nil) else { return }
        for file in files {
            guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent), !ids.contains(id) else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
