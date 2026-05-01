import Foundation

public struct AppConfiguration: Codable, Equatable {
    public var projectId: String
    public var environment: String
    public var secretPath: String
    public var baseURL: String
    public var projectName: String?
    public var organizationId: String?

    public var shortcutKeyCode: UInt32?
    public var shortcutModifiers: UInt32?

    /// Env slug to pre-select on the Add Secret form when the menu is browsing
    /// "All Environments". nil means "use the first env in the project".
    public var defaultAddEnvironment: String?

    /// Backend providing secrets — "local" (encrypted on this Mac, default) or
    /// "infisical". Decoded from older configs as "infisical" via custom init below
    /// so existing users see no change after upgrade.
    public var storeBackend: String

    /// When true and storeBackend == "local", secret values are written to the
    /// macOS Keychain with `kSecAttrSynchronizable = true` so iCloud Keychain
    /// replicates them across the user's signed-in devices. No effect on
    /// Infisical backend.
    public var iCloudSyncEnabled: Bool

    public static let defaultBaseURL = "https://app.infisical.com"
    public static let defaultEnvironment = "dev"
    public static let defaultSecretPath = "/"

    /// Sentinel value stored in `environment` to indicate "fetch all envs in this project".
    public static let allEnvironmentsSentinel = "*"

    /// Sentinel value stored in `projectId` to indicate "fetch every project I can access".
    public static let allProjectsSentinel = "*"

    /// True if this configuration is in all-envs mode.
    public var isAllEnvironments: Bool {
        environment == Self.allEnvironmentsSentinel
    }

    /// True if this configuration is in all-projects mode.
    public var isAllProjects: Bool {
        projectId == Self.allProjectsSentinel
    }

    public init(
        projectId: String,
        environment: String = AppConfiguration.defaultEnvironment,
        secretPath: String = AppConfiguration.defaultSecretPath,
        baseURL: String = AppConfiguration.defaultBaseURL,
        projectName: String? = nil,
        organizationId: String? = nil,
        shortcutKeyCode: UInt32? = nil,
        shortcutModifiers: UInt32? = nil,
        defaultAddEnvironment: String? = nil,
        storeBackend: String = "infisical",
        iCloudSyncEnabled: Bool = false
    ) {
        self.projectId = projectId
        self.environment = environment
        self.secretPath = secretPath
        self.baseURL = baseURL
        self.projectName = projectName
        self.organizationId = organizationId
        self.shortcutKeyCode = shortcutKeyCode
        self.shortcutModifiers = shortcutModifiers
        self.defaultAddEnvironment = defaultAddEnvironment
        self.storeBackend = storeBackend
        self.iCloudSyncEnabled = iCloudSyncEnabled
    }

    enum CodingKeys: String, CodingKey {
        case projectId, environment, secretPath, baseURL, projectName, organizationId
        case shortcutKeyCode, shortcutModifiers, defaultAddEnvironment
        case storeBackend, iCloudSyncEnabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        projectId = try c.decode(String.self, forKey: .projectId)
        environment = try c.decodeIfPresent(String.self, forKey: .environment)
            ?? Self.defaultEnvironment
        secretPath = try c.decodeIfPresent(String.self, forKey: .secretPath)
            ?? Self.defaultSecretPath
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? Self.defaultBaseURL
        projectName = try c.decodeIfPresent(String.self, forKey: .projectName)
        organizationId = try c.decodeIfPresent(String.self, forKey: .organizationId)
        shortcutKeyCode = try c.decodeIfPresent(UInt32.self, forKey: .shortcutKeyCode)
        shortcutModifiers = try c.decodeIfPresent(UInt32.self, forKey: .shortcutModifiers)
        defaultAddEnvironment = try c.decodeIfPresent(String.self, forKey: .defaultAddEnvironment)
        // Older configs predate this field — assume Infisical to preserve behaviour.
        storeBackend = try c.decodeIfPresent(String.self, forKey: .storeBackend) ?? "infisical"
        iCloudSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .iCloudSyncEnabled) ?? false
    }

    public var dashboardURL: String {
        if let orgId = organizationId {
            return "\(baseURL)/organizations/\(orgId)/projects/secret-management/\(projectId)/overview"
        }
        return baseURL
    }

    // MARK: - File-backed storage

    /// `~/.config/kubera/config.json`. Both the GUI app and CLI read/write this.
    public static var configFileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/kubera/config.json")
    }

    /// Legacy UserDefaults key, used once for migration.
    private static let legacyUserDefaultsKey = "infisical_app_config"

    public func save() {
        let url = Self.configFileURL
        let dir = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self)
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        } catch {
            // Persist failures are non-fatal at the call site; surface via logs only.
            FileHandle.standardError.write(
                Data("kubera: failed to save config: \(error.localizedDescription)\n".utf8)
            )
        }
    }

    public static func load() -> AppConfiguration? {
        let url = configFileURL
        if let data = try? Data(contentsOf: url),
           let cfg = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            return cfg
        }
        // One-time migration from legacy UserDefaults.
        if let legacyData = UserDefaults.standard.data(forKey: legacyUserDefaultsKey),
           let cfg = try? JSONDecoder().decode(AppConfiguration.self, from: legacyData) {
            cfg.save()
            return cfg
        }
        return nil
    }

    public static func clear() {
        let url = configFileURL
        try? FileManager.default.removeItem(at: url)
        UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
    }

    /// True when the local backend is selected.
    public var isLocalBackend: Bool { storeBackend == SecretStoreBackendID.local }

    /// Default config for a freshly bootstrapped local backend.
    public static func defaultLocal() -> AppConfiguration {
        AppConfiguration(
            projectId: KeychainSecretStore.localProjectId,
            environment: KeychainSecretStore.defaultEnvironments.first ?? defaultEnvironment,
            secretPath: defaultSecretPath,
            baseURL: defaultBaseURL,
            projectName: "Local",
            storeBackend: SecretStoreBackendID.local
        )
    }
}

/// Build the active `SecretStore` from a configuration. Call sites that previously
/// reached for `InfisicalCLIService` directly should go through this so the local
/// backend takes over when configured.
public enum SecretStoreFactory {
    public static func make(for config: AppConfiguration) -> SecretStore {
        if config.isLocalBackend {
            return KeychainSecretStore()
        }
        return InfisicalSecretStore(baseURL: config.baseURL)
    }
}
