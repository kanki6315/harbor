// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WebKit
import LocalAuthentication

@MainActor @Observable
final class ProfileManager {
    private(set) var registry: ProfileRegistry?
    private(set) var browser: BrowserModel?
    private(set) var isDeleting = false
    var errorMessage: String?
    let store: ProfileStore
    private var pendingIncomingURLs: [UUID: [URL]] = [:]
    private var browsers: [UUID: BrowserModel] = [:]
    private let testing: Bool
    private var unlockedProfileID: UUID?
    private var lockBackgroundedAt: Date?
    private var authenticationGeneration = 0
    private var authenticationContext: LAContext?
    private(set) var isAuthenticating = false
    // The privacy cover waits for SwiftUI to render the result of this activation.
    private(set) var activationRevision: UInt = 0
    var shouldHideAppSwitcherPreview: Bool {
        guard let profile = currentProfile, profile.isProtected else { return false }
        // Cover immediate-lock profiles before UIKit captures the outgoing scene.
        // A delayed lock keeps the page preview visible during the unlocked session.
        return isLocked || profile.effectiveLockAfterMinutes == 0
    }
    private let authenticate: (@MainActor (String) async throws -> Bool)?
    var isLocked: Bool { currentProfile?.isProtected == true && unlockedProfileID != currentProfile?.id }

    var authenticationLabel: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Device authentication"
        }
    }

    private func verifyOwner(reason: String) async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        let generation = authenticationGeneration
        defer { isAuthenticating = false; authenticationContext = nil }
        do {
            let success: Bool
            if let authenticate { success = try await authenticate(reason) }
            else {
                let context = LAContext()
                authenticationContext = context
                success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            }
            guard generation == authenticationGeneration else { return false }
            if !success { errorMessage = "Authentication was not completed. Try again." }
            return success
        } catch {
            if generation == authenticationGeneration { errorMessage = error.localizedDescription }
            return false
        }
    }

    func unlockSelected() async {
        guard isLocked, let profile = currentProfile else { return }
        errorMessage = nil
        guard await verifyOwner(reason: "Unlock \(profile.name) in Harbor."), currentProfile?.id == profile.id else { return }
        unlockedProfileID = profile.id
        activateSelected()
    }

    @discardableResult func setProtection(_ id: UUID, enabled: Bool) async -> Bool {
        guard let profile = profiles.first(where: { $0.id == id }) else { return false }
        if profile.isProtected == enabled { return true }
        errorMessage = nil
        guard await verifyOwner(reason: "Change the profile lock for \(profile.name)."),
              var candidate = registry,
              let index = candidate.profiles.firstIndex(where: { $0.id == id && !$0.isDeleting }) else { return false }
        candidate.profiles[index].requiresAuthentication = enabled
        guard commit(candidate) else { return false }
        if currentProfile?.id == id {
            unlockedProfileID = enabled ? id : nil
            if browser == nil { activateSelected() }
        }
        return true
    }

    @discardableResult func setLockAfter(_ id: UUID, minutes: Int) async -> Bool {
        guard BrowserProfile.lockDelays.contains(minutes),
              let profile = profiles.first(where: { $0.id == id }) else { return false }
        if profile.effectiveLockAfterMinutes == minutes { return true }
        errorMessage = nil
        guard await verifyOwner(reason: "Change the lock delay for \(profile.name)."),
              var candidate = registry,
              let index = candidate.profiles.firstIndex(where: { $0.id == id && !$0.isDeleting }) else { return false }
        candidate.profiles[index].lockAfterMinutes = minutes
        return commit(candidate)
    }

    var profiles: [BrowserProfile] { registry?.availableProfiles ?? [] }
    var pendingDeletions: [BrowserProfile] { registry?.profiles.filter(\.isDeleting) ?? [] }
    var currentProfile: BrowserProfile? { profiles.first { $0.id == registry?.selectedProfileID } }

    init(store: ProfileStore? = nil, now: Date = Date(), authenticate: (@MainActor (String) async throws -> Bool)? = nil) {
        self.authenticate = authenticate
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
                var profile = BrowserProfile(name: "Personal")
                if ProcessInfo.processInfo.arguments.contains("--locked-profile-fixture") {
                    profile.requiresAuthentication = true
                }
                loaded = ProfileRegistry(profiles: [profile], selectedProfileID: profile.id, defaultProfileID: profile.id)
                var archive = BrowserArchive()
                if ProcessInfo.processInfo.arguments.contains("--history-fixture") {
                    // Synthetic visits live only in the isolated, reset UI-test profile.
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: now)
                    let samples: [(String, String, Int)] = [
                        ("https://developer.apple.com/design/human-interface-guidelines", "Human Interface Guidelines", 0),
                        ("https://www.nps.gov/acad/planyourvisit/", "Plan your visit — Acadia National Park", 0),
                        ("https://www.nps.gov/acad/maps.htm", "Maps — Acadia National Park", 0),
                        ("https://www.wikipedia.org/", "Wikipedia", -1),
                        ("https://example.com/long-title", "A longer page title that wraps naturally while keeping the website address and visit time readable", -1),
                        ("https://example.org/untitled", "", -4)
                    ]
                    archive.history = samples.enumerated().map { index, sample in
                        HistoryEntry(url: URL(string: sample.0)!, title: sample.1,
                                     visitedAt: calendar.date(byAdding: .day, value: sample.2, to: today)!
                                        .addingTimeInterval(Double(3600 - index * 120)))
                    }
                }
                try self.store.browserStore(for: profile.id).save(archive)
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
        guard let profile = currentProfile, !isLocked else { browser = nil; return }
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
        openPendingIncomingURLs()
    }

    /// Apply return/lock policy before choosing the receiving profile, regardless of
    /// whether SwiftUI delivers the URL or the active-scene event first.
    func openIncomingURL(_ url: URL, at date: Date = Date()) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty else { return }
        becameActive(at: date)
        guard let profile = currentProfile else { return }
        pendingIncomingURLs[profile.id, default: []].append(url)
        openPendingIncomingURLs()
    }

    private func openPendingIncomingURLs() {
        guard !isLocked, let browser, let id = currentProfile?.id,
              browser.profileID == id else { return }
        // Keep links tied to their receiving profile when the user switches away
        // from a locked profile. Pending links live only in memory.
        let urls = pendingIncomingURLs.removeValue(forKey: id) ?? []
        for url in urls { browser.newTab(url: url) }
    }

    @discardableResult func select(_ id: UUID) -> Bool {
        guard var candidate = registry, profiles.contains(where: { $0.id == id }) else { return false }
        if candidate.selectedProfileID == id { return true }
        // An unreadable archive stays untouched, but must not lock the user out of other profiles.
        if browser?.persistenceAvailable == true, browser?.saveNow() == false { return false }
        candidate.selectedProfileID = id
        guard commit(candidate) else { return false }
        browser?.deactivate()
        authenticationGeneration += 1
        authenticationContext?.invalidate()
        unlockedProfileID = nil
        activateSelected()
        return true
    }

    @discardableResult func create(name: String, symbol: String, requiresAuthentication: Bool) async -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        errorMessage = nil
        if requiresAuthentication {
            guard await verifyOwner(reason: "Protect \(name) in Harbor.") else { return false }
        }
        return createProfile(name: name, symbol: symbol, requiresAuthentication: requiresAuthentication)
    }

    @discardableResult func create(name: String, symbol: String) -> Bool {
        createProfile(name: name, symbol: symbol, requiresAuthentication: false)
    }

    private func createProfile(name: String, symbol: String, requiresAuthentication: Bool) -> Bool {
        guard var candidate = registry else { return false }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        var profile = BrowserProfile(name: String(name.prefix(60)), symbol: symbol)
        profile.requiresAuthentication = requiresAuthentication
        do { try store.browserStore(for: profile.id).save(BrowserArchive()) }
        catch { errorMessage = "Profile could not be created. \(error.localizedDescription)"; return false }
        candidate.profiles.append(profile)
        return commit(candidate)
    }

    @discardableResult func rename(_ id: UUID, name: String, symbol: String) async -> Bool {
        guard let profile = profiles.first(where: { $0.id == id }) else { return false }
        if profile.isProtected && unlockedProfileID != id {
            guard await verifyOwner(reason: "Edit \(profile.name) in Harbor.") else { return false }
        }
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
        authenticationGeneration += 1
        authenticationContext?.invalidate()
        if lockBackgroundedAt == nil { lockBackgroundedAt = date }
        lockIfExpired(at: date)
        guard var candidate = registry, candidate.backgroundedAt == nil else { return }
        candidate.backgroundedAt = date
        _ = commit(candidate)
    }

    private func lockIfExpired(at date: Date) {
        guard let profile = currentProfile, profile.isProtected,
              let departed = lockBackgroundedAt,
              date.timeIntervalSince(departed) >= Double(profile.effectiveLockAfterMinutes) * 60 else { return }
        unlockedProfileID = nil
        browser?.deactivate()
        browser = nil
    }

    func becameActive(at date: Date = Date()) {
        defer { activationRevision &+= 1 }
        // Check before displaying retained content; iOS may suspend background timers.
        lockIfExpired(at: date)
        lockBackgroundedAt = nil
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
        if profiles.first(where: { $0.id == id })?.isProtected == true {
            guard await verifyOwner(reason: "Delete this protected profile."), !isDeleting else { return }
        }
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
        pendingIncomingURLs.removeValue(forKey: id)
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
