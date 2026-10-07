import SwiftUI
import WebKit

@MainActor @Observable
final class ProfileManager {
    private(set) var registry: ProfileRegistry?
    private(set) var browser: BrowserModel?
    private(set) var isDeleting = false
    var errorMessage: String?
    let store: ProfileStore
    private var browsers: [UUID: BrowserModel] = [:]
    private let testing: Bool

    var profiles: [BrowserProfile] { registry?.availableProfiles ?? [] }
    var pendingDeletions: [BrowserProfile] { registry?.profiles.filter(\.isDeleting) ?? [] }
    var currentProfile: BrowserProfile? { profiles.first { $0.id == registry?.selectedProfileID } }

    init(store: ProfileStore? = nil, now: Date = Date()) {
        #if DEBUG
        testing = store == nil && ProcessInfo.processInfo.arguments.contains("--uitesting")
        #else
        testing = false
        #endif
        self.store = store ?? (testing ? ProfileStore(root: FileManager.default.temporaryDirectory.appending(path: "HarborUITests")) : ProfileStore())
        do {
            #if DEBUG
            if testing && ProcessInfo.processInfo.arguments.contains("--reset") {
                // UI test profiles have their own named WebKit stores, never the user's default store.
                if FileManager.default.fileExists(atPath: self.store.root.path) {
                    try FileManager.default.removeItem(at: self.store.root)
                }
            }
            #endif
            var loaded = try self.store.loadOrMigrate()
            #if DEBUG
            if testing && ProcessInfo.processInfo.arguments.contains("--reset") {
                let profile = BrowserProfile(name: "Personal")
                loaded = ProfileRegistry(profiles: [profile], selectedProfileID: profile.id, defaultProfileID: profile.id)
                try self.store.browserStore(for: profile.id).save(BrowserArchive())
            }
            #endif
            loaded.selectedProfileID = loaded.profileOnReturn(at: now)
            loaded.backgroundedAt = nil
            try self.store.save(loaded)
            registry = loaded
            activateSelected()
        } catch {
            errorMessage = "Profiles could not be loaded. Your saved data has been left untouched. \(error.localizedDescription)"
        }
    }

    private func commit(_ candidate: ProfileRegistry) -> Bool {
        do { try store.save(candidate); registry = candidate; return true }
        catch { errorMessage = "Profile changes could not be saved. \(error.localizedDescription)"; return false }
    }

    private func activateSelected() {
        guard let profile = currentProfile else { return }
        let model: BrowserModel
        if let existing = browsers[profile.id] { model = existing }
        else {
            model = BrowserModel(store: store.browserStore(for: profile.id), profileID: profile.id,
                                 profileName: profile.name,
                                 websiteDataStore: profile.usesLegacyWebStore ? .default() : WKWebsiteDataStore(forIdentifier: profile.id),
                                 isTesting: testing)
            browsers[profile.id] = model
        }
        browser = model
        model.activate()
    }

    @discardableResult func select(_ id: UUID) -> Bool {
        guard var candidate = registry, profiles.contains(where: { $0.id == id }) else { return false }
        if candidate.selectedProfileID == id { return true }
        // An unreadable archive stays untouched, but must not lock the user out of other profiles.
        if browser?.persistenceAvailable == true, browser?.saveNow() == false { return false }
        candidate.selectedProfileID = id
        guard commit(candidate) else { return false }
        browser?.deactivate()
        activateSelected()
        return true
    }

    @discardableResult func create(name: String, symbol: String) -> Bool {
        guard var candidate = registry else { return false }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        let profile = BrowserProfile(name: String(name.prefix(60)), symbol: symbol)
        do { try store.browserStore(for: profile.id).save(BrowserArchive()) }
        catch { errorMessage = "Profile could not be created. \(error.localizedDescription)"; return false }
        candidate.profiles.append(profile)
        return commit(candidate)
    }

    @discardableResult func rename(_ id: UUID, name: String, symbol: String) -> Bool {
        guard var candidate = registry, let index = candidate.profiles.firstIndex(where: { $0.id == id }) else { return false }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        candidate.profiles[index].name = String(name.prefix(60))
        candidate.profiles[index].symbol = symbol
        guard commit(candidate) else { return false }
        browsers[id]?.profileName = candidate.profiles[index].name
        return true
    }

    func configureReturn(defaultID: UUID, minutes: Int?) {
        guard var candidate = registry, profiles.contains(where: { $0.id == defaultID }) else { return }
        candidate.defaultProfileID = defaultID
        candidate.returnAfterMinutes = minutes
        _ = commit(candidate)
    }

    func enteredBackground(at date: Date = Date()) {
        browser?.saveNow()
        guard var candidate = registry, candidate.backgroundedAt == nil else { return }
        candidate.backgroundedAt = date
        _ = commit(candidate)
    }

    func becameActive(at date: Date = Date()) {
        guard var candidate = registry else { return }
        let target = candidate.profileOnReturn(at: date)
        // Save/switch before consuming the timestamp, so a failed save can be retried.
        guard select(target), let updated = registry else { return }
        candidate = updated
        candidate.backgroundedAt = nil
        _ = commit(candidate)
    }

    func delete(_ id: UUID) async {
        guard !isDeleting else { return }
        guard browsers[id]?.isClearingData != true else {
            errorMessage = "Browsing data is still being cleared. Try deleting this profile again when it finishes."
            return
        }
        guard var candidate = registry,
              let index = candidate.profiles.firstIndex(where: { $0.id == id }),
              let fallback = profiles.first(where: { $0.id != id }) else { return }
        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }
        if candidate.selectedProfileID == id {
            guard select(fallback.id), let updated = registry else { return }
            candidate = updated
        }
        if candidate.defaultProfileID == id { candidate.defaultProfileID = fallback.id }
        candidate.profiles[index].isDeleting = true
        guard commit(candidate) else { return }
        let profile = candidate.profiles[index]
        browsers[id]?.deactivate()
        browsers[id]?.downloads.clearTemporaryFiles()
        browsers.removeValue(forKey: id)
        // Let SwiftUI detach outgoing web views before WebKit removes their data store.
        await Task.yield()
        do {
            if profile.usesLegacyWebStore {
                await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
            } else {
                // Flush storage initialization/removal before dropping the named store. A new,
                // never-navigated profile can otherwise race WebKit's directory creation.
                await WKWebsiteDataStore(forIdentifier: id).removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
                try await removeNamedStore(id)
            }
            let directory = store.directory(for: id)
            if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
            try DownloadManager.removeFiles(profileID: id)
            if profile.usesLegacyWebStore, FileManager.default.fileExists(atPath: store.legacyURL.path) {
                try FileManager.default.removeItem(at: store.legacyURL)
            }
            // Other profile changes may have occurred while awaiting WebKit.
            guard var finished = registry else { return }
            finished.profiles.removeAll { $0.id == id }
            _ = commit(finished)
        } catch { errorMessage = "Could not finish deleting \(profile.name). Retry deletion in Profiles. \(error.localizedDescription)" }
    }

    private func removeNamedStore(_ id: UUID) async throws {
        // WebKit releases a detached view's network-process reference asynchronously.
        // Bound retries so real deletion failures remain visible and recoverable.
        for attempt in 0..<4 {
            do { try await WKWebsiteDataStore.remove(forIdentifier: id); return }
            catch {
                if attempt == 3 { throw error }
                try await Task.sleep(for: .milliseconds(100 * (1 << attempt)))
            }
        }
    }

}
