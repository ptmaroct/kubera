import ArgumentParser
import Foundation
import KuberaCore

struct Projects: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List Infisical projects available to the logged-in user.")

    @Option(name: .long, help: "Organization ID. Defaults to the first org returned by Infisical.")
    var org: String?

    @Option(name: .customLong("base-url"), help: "Infisical base URL override.")
    var baseURL: String?

    @Flag(help: "Emit JSON.") var json: Bool = false

    func run() async throws {
        let url = baseURL ?? AppConfiguration.load()?.baseURL ?? AppConfiguration.defaultBaseURL
        let orgId: String
        if let org { orgId = org } else {
            let orgs = try await InfisicalCLIService.fetchOrganizations(baseURL: url)
            guard let first = orgs.first else { throw ValidationError("No organizations available — run kubera login.") }
            orgId = first.id
        }
        let projects = try await InfisicalCLIService.fetchProjects(orgId: orgId, baseURL: url)
        if json { try Helpers.emitJSON(projects); return }
        for p in projects {
            let envs = p.environments.map(\.slug).joined(separator: ",")
            print("\(p.id)\t\(p.name)\t[\(envs)]")
        }
    }
}

struct Envs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List environments for the configured project.")

    @Flag(help: "Emit JSON.") var json: Bool = false

    func run() async throws {
        let cfg = try Helpers.requireConfig()
        let orgId = cfg.organizationId
        let url = cfg.baseURL
        let projects: [InfisicalProject]
        if let orgId {
            projects = try await InfisicalCLIService.fetchProjects(orgId: orgId, baseURL: url)
        } else {
            let orgs = try await InfisicalCLIService.fetchOrganizations(baseURL: url)
            guard let first = orgs.first else { throw ValidationError("No organizations available.") }
            projects = try await InfisicalCLIService.fetchProjects(orgId: first.id, baseURL: url)
        }
        guard let project = projects.first(where: { $0.id == cfg.projectId }) else {
            throw ValidationError("Configured project \(cfg.projectId) not found.")
        }
        if json { try Helpers.emitJSON(project.environments); return }
        for e in project.environments {
            print("\(e.slug)\t\(e.name)")
        }
    }
}

struct Tags: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List tags defined in the configured project.")

    @Flag(help: "Emit JSON.") var json: Bool = false

    func run() async throws {
        let cfg = try Helpers.requireConfig()
        let tags = try await InfisicalCLIService.fetchTags(projectId: cfg.projectId, baseURL: cfg.baseURL)
        if json { try Helpers.emitJSON(tags); return }
        for t in tags {
            print("\(t.id)\t\(t.slug)\t\(t.color ?? "-")")
        }
    }
}
