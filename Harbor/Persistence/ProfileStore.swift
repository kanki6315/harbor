import Foundation

struct ProfileStore {
    let root: URL
    var registryURL: URL { root.appending(path: "profiles.json") }
    var legacyURL: URL { root.appending(path: "browser.json") }
    func directory(for id: UUID) -> URL { root.appending(path: "Profiles/\(id.uuidString)") }
    func browserStore(for id: UUID) -> BrowserStore {
        BrowserStore(fileURL: directory(for: id).appending(path: "browser.json"))
    }

    init(root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "Harbor")) {
        self.root = root
    }

    func loadOrMigrate() throws -> ProfileRegistry {
        if FileManager.default.fileExists(atPath: registryURL.path) {
            let registry = try JSONDecoder().decode(ProfileRegistry.self, from: Data(contentsOf: registryURL))
            try registry.validate()
            // Finish cleanup if the process stopped after committing the migration.
            if registry.profiles.contains(where: \.usesLegacyWebStore), FileManager.default.fileExists(atPath: legacyURL.path) {
                try FileManager.default.removeItem(at: legacyURL)
            }
            return registry
        }
        let hasLegacy = FileManager.default.fileExists(atPath: legacyURL.path)
        // A stable migration ID makes retrying an interrupted migration idempotent.
        let profile = BrowserProfile(id: hasLegacy ? UUID(uuidString: "86F47D39-56A9-4D0B-9875-90719C5953DC")! : UUID(),
                                     name: "Personal", usesLegacyWebStore: hasLegacy)
        let archive = try BrowserStore(fileURL: legacyURL).load()
        try browserStore(for: profile.id).save(archive)
        let registry = ProfileRegistry(profiles: [profile], selectedProfileID: profile.id, defaultProfileID: profile.id)
        try save(registry)
        // The original stays untouched until both the profile archive and registry are committed.
        if hasLegacy { try FileManager.default.removeItem(at: legacyURL) }
        return registry
    }

    func save(_ registry: ProfileRegistry) throws {
        try registry.validate()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(registry).write(to: registryURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
