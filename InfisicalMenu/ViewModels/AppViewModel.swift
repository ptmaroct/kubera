import Foundation
import AppKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var secrets: [SecretItem] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isConfigured: Bool = false

    var filteredSecrets: [SecretItem] {
        if searchText.isEmpty { return secrets }
        return secrets.filter {
            $0.key.localizedCaseInsensitiveContains(searchText)
        }
    }

    init() {
        isConfigured = AppConfiguration.load() != nil
    }

    func loadSecrets() async {
        guard let config = AppConfiguration.load() else {
            isConfigured = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            secrets = try await InfisicalCLIService.listSecrets(
                environment: config.environment,
                projectId: config.projectId,
                secretPath: config.secretPath
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func copySecret(_ secret: SecretItem) {
        ClipboardService.copy(secret.value)
    }

    func createSecret(key: String, value: String) async -> Bool {
        guard let config = AppConfiguration.load() else { return false }

        isLoading = true
        do {
            try await InfisicalCLIService.createSecret(
                key: key,
                value: value,
                environment: config.environment,
                projectId: config.projectId,
                secretPath: config.secretPath
            )
            // Refresh the list
            await loadSecrets()
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func configurationSaved() {
        isConfigured = true
        Task {
            await loadSecrets()
        }
    }
}
