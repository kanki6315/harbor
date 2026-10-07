import Foundation

struct BrowserProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var symbol = "person.crop.circle"
    // Only an upgraded installation's original profile owns WebKit's default store.
    var usesLegacyWebStore = false
    var isDeleting = false
    // Optional for backwards-compatible decoding of existing profile registries.
    var requiresAuthentication: Bool? = nil
    var lockAfterMinutes: Int? = nil
    var effectiveLockAfterMinutes: Int { lockAfterMinutes ?? 30 }
    static let lockDelays = [0, 1, 5, 15, 30, 60]
    var isProtected: Bool { requiresAuthentication == true }

    static let symbols = ["person.crop.circle", "briefcase", "house", "book", "leaf", "star"]
}

struct ProfileRegistry: Codable {
    var version = 1
    var profiles: [BrowserProfile]
    var selectedProfileID: UUID
    var defaultProfileID: UUID
    var returnAfterMinutes: Int? = nil
    var backgroundedAt: Date? = nil

    var availableProfiles: [BrowserProfile] { profiles.filter { !$0.isDeleting } }

    func profileOnReturn(at now: Date) -> UUID {
        guard let backgroundedAt else { return selectedProfileID }
        guard let minutes = returnAfterMinutes,
              now.timeIntervalSince(backgroundedAt) >= Double(minutes) * 60 else { return selectedProfileID }
        return defaultProfileID
    }

    func validate() throws {
        let ids = profiles.map(\.id)
        guard version == 1, !availableProfiles.isEmpty, Set(ids).count == ids.count,
              !ids.contains(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!),
              availableProfiles.contains(where: { $0.id == selectedProfileID }),
              availableProfiles.contains(where: { $0.id == defaultProfileID }),
              profiles.filter(\.usesLegacyWebStore).count <= 1,
              profiles.allSatisfy({ BrowserProfile.lockDelays.contains($0.effectiveLockAfterMinutes) }),
              profiles.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              returnAfterMinutes == nil || (1...10080).contains(returnAfterMinutes!) else {
            throw CocoaError(.coderReadCorrupt)
        }
    }
}
