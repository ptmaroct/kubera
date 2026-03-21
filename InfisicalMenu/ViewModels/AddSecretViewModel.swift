import Foundation

@MainActor
final class AddSecretViewModel: ObservableObject {

    // MARK: - Data from API

    @Published var projects: [InfisicalProject] = []
    @Published var environments: [InfisicalEnvironment] = []
    @Published var tags: [InfisicalTag] = []

    // MARK: - User Selections

    @Published var selectedProject: InfisicalProject?
    @Published var selectedEnvironment: InfisicalEnvironment?
    @Published var selectedTagIds: Set<String> = []
    @Published var secretPath: String = "/"

    // MARK: - Form Fields

    @Published var key: String = ""
    @Published var value: String = ""
    @Published var comment: String = ""

    // MARK: - UI State

    @Published var isLoadingProjects: Bool = false
    @Published var isLoadingTags: Bool = false
    @Published var isCreating: Bool = false
    @Published var showAdvanced: Bool = false
    @Published var errorMessage: String?
    @Published var showSuccess: Bool = false

    // MARK: - Computed

    var isValid: Bool {
        !key.isEmpty && !value.isEmpty && selectedProject != nil && selectedEnvironment != nil
    }

    // MARK: - Load Initial Data

    /// Fetches orgs → projects and pre-selects from current AppConfiguration
    func loadInitialData() async {
        isLoadingProjects = true
        errorMessage = nil

        do {
            let orgs = try await InfisicalCLIService.fetchOrganizations()
            guard let org = orgs.first else {
                errorMessage = "No organizations found"
                isLoadingProjects = false
                return
            }

            projects = try await InfisicalCLIService.fetchProjects(orgId: org.id)

            // Pre-select from current configuration
            if let config = AppConfiguration.load() {
                selectedProject = projects.first(where: { $0.id == config.projectId })
                if let project = selectedProject {
                    environments = project.environments
                    selectedEnvironment = environments.first(where: { $0.slug == config.environment })
                    secretPath = config.secretPath
                }
            }

            isLoadingProjects = false

            // Fetch tags for the selected project
            if selectedProject != nil {
                await fetchTags()
            }
        } catch {
            errorMessage = "Failed to load projects: \(error.localizedDescription)"
            isLoadingProjects = false
        }
    }

    // MARK: - Project Changed

    func onProjectSelected() {
        guard let project = selectedProject else {
            environments = []
            selectedEnvironment = nil
            tags = []
            selectedTagIds = []
            return
        }

        environments = project.environments
        selectedEnvironment = environments.first
        selectedTagIds = []

        Task {
            await fetchTags()
        }
    }

    // MARK: - Fetch Tags

    func fetchTags() async {
        guard let project = selectedProject else {
            tags = []
            return
        }

        isLoadingTags = true
        do {
            let baseURL = AppConfiguration.load()?.baseURL ?? AppConfiguration.defaultBaseURL
            tags = try await InfisicalCLIService.fetchTags(projectId: project.id, baseURL: baseURL)
        } catch {
            // Non-fatal — form still works without tags
            tags = []
        }
        isLoadingTags = false
    }

    // MARK: - Create Secret

    func createSecret() async -> Bool {
        guard let project = selectedProject,
              let env = selectedEnvironment else {
            errorMessage = "Select a project and environment"
            return false
        }

        guard !key.isEmpty, !value.isEmpty else {
            errorMessage = "Secret name and value are required"
            return false
        }

        isCreating = true
        errorMessage = nil

        do {
            let baseURL = AppConfiguration.load()?.baseURL ?? AppConfiguration.defaultBaseURL
            try await InfisicalCLIService.createSecretViaAPI(
                name: key,
                value: value,
                comment: comment,
                tagIds: Array(selectedTagIds),
                environment: env.slug,
                projectId: project.id,
                secretPath: secretPath,
                baseURL: baseURL
            )
            isCreating = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
            return false
        }
    }
}
