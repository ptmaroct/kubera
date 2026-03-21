import Foundation

struct AppConfiguration: Codable {
    var projectId: String
    var environment: String
    var secretPath: String
    var baseURL: String
    var projectName: String?

    static let defaultBaseURL = "https://app.infisical.com"
    static let defaultEnvironment = "dev"
    static let defaultSecretPath = "/"

    private static let userDefaultsKey = "infisical_app_config"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    static func load() -> AppConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(AppConfiguration.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
