import ArgumentParser
import Foundation
import KuberaCore

struct Config: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "View or modify the Kubera config file (~/.config/kubera/config.json).",
        subcommands: [Show.self, Set.self, Clear.self],
        defaultSubcommand: Show.self
    )

    struct Show: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Print the current config.")

        @Flag(help: "Emit JSON.") var json: Bool = false

        func run() async throws {
            let cfg = AppConfiguration.load()
            if json {
                if let cfg { try Helpers.emitJSON(cfg) } else { print("null") }
                return
            }
            guard let cfg else {
                print("<no config> — run: kubera config set --project <id>")
                return
            }
            print("file:        \(AppConfiguration.configFileURL.path)")
            print("project:     \(cfg.projectName ?? cfg.projectId)  (\(cfg.projectId))")
            print("environment: \(cfg.isAllEnvironments ? "All Environments" : cfg.environment)")
            print("path:        \(cfg.secretPath)")
            print("base URL:    \(cfg.baseURL)")
            if let org = cfg.organizationId { print("org:         \(org)") }
        }
    }

    struct Set: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Update one or more config fields.")

        @Option(name: .long, help: "Workspace / project ID.") var project: String?
        @Option(name: .long, help: "Environment slug, or '*' for all.") var env: String?
        @Option(name: .long, help: "Secret path, e.g. '/' or '/api'.") var path: String?
        @Option(name: .customLong("base-url"), help: "Infisical base URL.") var baseURL: String?
        @Option(name: .long, help: "Organization ID (used to build dashboard links).") var org: String?
        @Option(name: .customLong("project-name"), help: "Friendly project name shown in the menu/CLI.") var projectName: String?

        func run() async throws {
            var cfg = AppConfiguration.load() ?? AppConfiguration(
                projectId: project ?? "",
                environment: env ?? AppConfiguration.defaultEnvironment,
                secretPath: path ?? AppConfiguration.defaultSecretPath,
                baseURL: baseURL ?? AppConfiguration.defaultBaseURL,
                projectName: projectName,
                organizationId: org
            )

            if let project { cfg.projectId = project }
            if let env { cfg.environment = env }
            if let path { cfg.secretPath = path }
            if let baseURL { cfg.baseURL = baseURL }
            if let org { cfg.organizationId = org }
            if let projectName { cfg.projectName = projectName }

            guard !cfg.projectId.isEmpty else {
                throw ValidationError("--project is required when no config exists yet. Run: kubera projects to find one.")
            }
            cfg.save()
            print("saved \(AppConfiguration.configFileURL.path)")
        }
    }

    struct Clear: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete the config file.")

        func run() async throws {
            AppConfiguration.clear()
            print("cleared \(AppConfiguration.configFileURL.path)")
        }
    }
}
