import Foundation

@MainActor
final class AddSecretViewModel: ObservableObject {

    // MARK: - Data from API

    @Published var projects: [InfisicalProject] = []
    @Published var environments: [InfisicalEnvironment] = []
    @Published var tags: [InfisicalTag] = []

    // MARK: - User Selections

    @Published var selectedProject: InfisicalProject?
    @Published var selectedEnvironmentIds: Set<String> = []
    @Published var selectedTagIds: Set<String> = []

    // MARK: - Form Fields

    @Published var key: String = ""
    @Published var value: String = ""
    @Published var comment: String = ""
    @Published var newTagName: String = ""

    // MARK: - UI State

    @Published var isLoadingProjects: Bool = false
    @Published var isLoadingTags: Bool = false
    @Published var isCreatingTag: Bool = false
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?

    // MARK: - Computed

    var isValid: Bool {
        !key.isEmpty && !value.isEmpty && selectedProject != nil && !selectedEnvironmentIds.isEmpty
    }

    var selectedEnvironments: [InfisicalEnvironment] {
        environments.filter { selectedEnvironmentIds.contains($0.id) }
    }

    // MARK: - Load Initial Data (cache-first, no loaders)

    func loadInitialData() async {
        errorMessage = nil

        // 1. Use cached projects instantly
        let cached = ProjectCache.shared.cachedProjects
        if !cached.isEmpty {
            projects = cached
            preSelectFromConfig()

            // Load cached tags instantly
            if let projectId = selectedProject?.id {
                let cachedTags = ProjectCache.shared.cachedTags(for: projectId)
                if !cachedTags.isEmpty {
                    tags = cachedTags
                }
            }

            // Refresh both in background
            Task {
                let fresh = await ProjectCache.shared.fetchProjects()
                if fresh != projects {
                    projects = fresh
                    if selectedProject == nil || !projects.contains(where: { $0.id == selectedProject?.id }) {
                        preSelectFromConfig()
                    }
                }
            }
            if let projectId = selectedProject?.id {
                Task {
                    let freshTags = await ProjectCache.shared.fetchTags(for: projectId)
                    if freshTags != tags {
                        tags = freshTags
                    }
                }
            }
            return
        }

        // 2. No cache — show loader for first load only
        isLoadingProjects = true
        let fetched = await ProjectCache.shared.fetchProjects()
        projects = fetched
        preSelectFromConfig()
        isLoadingProjects = false

        if projects.isEmpty {
            errorMessage = "No projects found"
            return
        }

        // Fetch tags (with loader since first load)
        if let projectId = selectedProject?.id {
            isLoadingTags = true
            tags = await ProjectCache.shared.fetchTags(for: projectId)
            isLoadingTags = false
        }
    }

    private func preSelectFromConfig() {
        guard let config = AppConfiguration.load() else { return }
        selectedProject = projects.first(where: { $0.id == config.projectId })
        if let project = selectedProject {
            environments = project.environments
            if let env = environments.first(where: { $0.slug == config.environment }) {
                selectedEnvironmentIds = [env.id]
            }
        }
    }

    // MARK: - Project Changed

    func onProjectSelected() {
        guard let project = selectedProject else {
            environments = []
            selectedEnvironmentIds = []
            tags = []
            selectedTagIds = []
            return
        }

        environments = project.environments
        if let first = environments.first {
            selectedEnvironmentIds = [first.id]
        }
        selectedTagIds = []

        // Load cached tags instantly, refresh in background
        let cachedTags = ProjectCache.shared.cachedTags(for: project.id)
        tags = cachedTags

        if cachedTags.isEmpty {
            isLoadingTags = true
        }
        Task {
            let fresh = await ProjectCache.shared.fetchTags(for: project.id)
            tags = fresh
            isLoadingTags = false
        }
    }

    // MARK: - Environment Toggle

    func toggleEnvironment(_ env: InfisicalEnvironment) {
        if selectedEnvironmentIds.contains(env.id) {
            if selectedEnvironmentIds.count > 1 {
                selectedEnvironmentIds.remove(env.id)
            }
        } else {
            selectedEnvironmentIds.insert(env.id)
        }
    }

    // MARK: - Fetch Tags (unused now, kept for manual refresh)

    func fetchTags() async {
        guard let project = selectedProject else {
            tags = []
            return
        }
        tags = await ProjectCache.shared.fetchTags(for: project.id)
    }

    // MARK: - Create Tag

    func createTag() async {
        guard let project = selectedProject else { return }
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        // Check duplicate — auto-select if exists
        if let existing = tags.first(where: { $0.displayName.lowercased() == name.lowercased() }) {
            selectedTagIds.insert(existing.id)
            newTagName = ""
            return
        }

        isCreatingTag = true
        errorMessage = nil

        do {
            let baseURL = AppConfiguration.load()?.baseURL ?? AppConfiguration.defaultBaseURL
            let newTag = try await InfisicalCLIService.createTag(
                name: name,
                projectId: project.id,
                baseURL: baseURL
            )
            tags.append(newTag)
            selectedTagIds.insert(newTag.id)
            newTagName = ""
            // Update cache
            ProjectCache.shared.addTag(newTag, for: project.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreatingTag = false
    }

    // MARK: - Create Secret

    func createSecret() async -> Bool {
        guard let project = selectedProject,
              !selectedEnvironmentIds.isEmpty else {
            errorMessage = "Select a project and at least one environment"
            return false
        }

        guard !key.isEmpty, !value.isEmpty else {
            errorMessage = "Secret name and value are required"
            return false
        }

        isCreating = true
        errorMessage = nil

        let envsToCreate = selectedEnvironments
        let baseURL = AppConfiguration.load()?.baseURL ?? AppConfiguration.defaultBaseURL

        do {
            for env in envsToCreate {
                try await InfisicalCLIService.createSecretViaAPI(
                    name: key,
                    value: value,
                    comment: comment,
                    tagIds: Array(selectedTagIds),
                    environment: env.slug,
                    projectId: project.id,
                    secretPath: "/",
                    baseURL: baseURL
                )
            }
            isCreating = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
            return false
        }
    }
}
