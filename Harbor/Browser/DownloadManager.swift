import WebKit
import Observation

struct ShareItem: Identifiable {
    let id = UUID()
    var url: URL
}

@MainActor @Observable
final class DownloadManager: NSObject, WKDownloadDelegate {
    let directory: URL
    init(profileID: UUID) {
        directory = Self.directory(profileID: profileID)
        super.init()
        // No downloads survive process termination; remove leftovers before this profile starts any.
        try? FileManager.default.removeItem(at: directory)
    }
    static func directory(profileID: UUID) -> URL {
        FileManager.default.temporaryDirectory.appending(path: "HarborDownloads/Profiles/\(profileID.uuidString)")
    }
    static func removeFiles(profileID: UUID) throws {
        let directory = directory(profileID: profileID)
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
    var completed: ShareItem?
    var errorMessage: String?
    private(set) var activeCount = 0
    private var downloads: [ObjectIdentifier: (WKDownload, URL?)] = [:]
    func clearTemporaryFiles() {
        for (download, _) in downloads.values { download.delegate = nil; download.cancel { _ in } }
        downloads.removeAll()
        activeCount = 0
        completed = nil
        try? FileManager.default.removeItem(at: directory)
    }
    func accept(_ download: WKDownload) {
        downloads[ObjectIdentifier(download)] = (download, nil)
        activeCount = downloads.count
        download.delegate = self
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        do {
            let directory = self.directory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let name = (suggestedFilename as NSString).lastPathComponent
            let url = directory.appendingPathComponent(name.isEmpty || name == "." || name == ".." ? "Download" : name)
            downloads[ObjectIdentifier(download)] = (download, url)
            completionHandler(url)
        } catch { errorMessage = error.localizedDescription; completionHandler(nil) }
    }
    func downloadDidFinish(_ download: WKDownload) {
        if let url = downloads.removeValue(forKey: ObjectIdentifier(download))?.1 { completed = ShareItem(url: url) }
        activeCount = downloads.count
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let url = downloads.removeValue(forKey: ObjectIdentifier(download))?.1 { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        activeCount = downloads.count
        errorMessage = "Download failed. \(error.localizedDescription)"
    }
}
