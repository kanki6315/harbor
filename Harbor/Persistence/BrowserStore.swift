// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UIKit

/// Durable preferences are backed up; browsing sessions remain local to this device.
struct BrowserStore {
    /// The original mixed archive, retained only until migration succeeds.
    let fileURL: URL
    var durableURL: URL { fileURL.deletingLastPathComponent().appending(path: "preferences.json") }
    var sessionDirectory: URL { fileURL.deletingLastPathComponent().appending(path: "DeviceOnly") }
    var sessionURL: URL { sessionDirectory.appending(path: "session.json") }

    private struct Preferences: Codable {
        var version = 1
        var bookmarks: [Bookmark]
        var bookmarkFolders: [BookmarkFolder]?
        var settings: BrowserSettings
    }
    private struct Session: Codable {
        var version = 1
        var tabs: [TabRecord]
        var selectedTabID: UUID?
        var history: [HistoryEntry]
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Harbor/browser.json")
    }
    func load() throws -> BrowserArchive {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // The original remains authoritative after an interrupted migration.
            var archive = try Self.readLegacy(fileURL)
            archive.tabs = archive.tabs.map(\.restorable)
            try save(archive)
            return archive
        }
        var archive = BrowserArchive()
        if FileManager.default.fileExists(atPath: durableURL.path) {
            let preferences = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: durableURL))
            guard preferences.version == 1 else { throw CocoaError(.coderReadCorrupt) }
            archive.bookmarkFolders = preferences.bookmarkFolders ?? []
            archive.bookmarks = preferences.bookmarks
            archive.settings = preferences.settings
        }
        if FileManager.default.fileExists(atPath: sessionDirectory.path) {
            try Self.prepareDeviceOnlyDirectory(sessionDirectory)
        }
        if FileManager.default.fileExists(atPath: sessionURL.path) {
            let session = try JSONDecoder().decode(Session.self, from: Data(contentsOf: sessionURL))
            guard session.version == 1 else { throw CocoaError(.coderReadCorrupt) }
            archive.tabs = session.tabs.map(\.restorable)
            archive.selectedTabID = session.selectedTabID
            archive.history = session.history
        }
        return archive
    }
    static func readLegacy(_ url: URL) throws -> BrowserArchive {
        // Protect even an unreadable legacy archive while keeping it recoverable.
        try excludeFromBackup(url)
        let archive = try JSONDecoder().decode(BrowserArchive.self, from: Data(contentsOf: url))
        guard archive.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return archive
    }
    static func prepareDeviceOnlyDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try excludeFromBackup(directory)
    }
    static func excludeFromBackup(_ resource: URL) throws {
        var url = resource
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        guard try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
    func save(_ archive: BrowserArchive) throws {
        try Self.prepareDeviceOnlyDirectory(sessionDirectory)
        let encoder = JSONEncoder()
        try encoder.encode(Session(tabs: archive.tabs.map(\.restorable), selectedTabID: archive.selectedTabID, history: archive.history))
            .write(to: sessionURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try encoder.encode(Preferences(bookmarks: archive.bookmarks, bookmarkFolders: archive.bookmarkFolders, settings: archive.settings))
            .write(to: durableURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        // Never delete the source until both destination files have been committed.
        if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
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

/// Serialize routine writes off the UI thread. Explicit flushes join the same queue,
/// so an older autosave cannot overwrite a newer user action or recreate deleted data.
final class BrowserArchiveWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Harbor.archive-writer", qos: .utility)
    private let store: BrowserStore

    init(store: BrowserStore) { self.store = store }

    func save(_ archive: BrowserArchive) throws {
        try queue.sync { try store.save(archive) }
    }

    @MainActor func saveInBackground(_ archive: BrowserArchive) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do { try store.save(archive); continuation.resume() }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    func flush() { queue.sync {} }
}
