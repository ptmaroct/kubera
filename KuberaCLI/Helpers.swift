import Foundation
import KuberaCore

/// Shared helpers used across kubera subcommands.
enum Helpers {

    /// Load config or fail with a friendly error pointing the user at `kubera config set`.
    static func requireConfig() throws -> AppConfiguration {
        guard let cfg = AppConfiguration.load() else {
            throw ValidationError(
                "No Kubera config found. Run 'kubera config set --project <id>' or open the macOS app to configure."
            )
        }
        return cfg
    }

    /// True when stdout is connected to an interactive terminal.
    static var isTTY: Bool {
        isatty(fileno(stdout)) != 0
    }

    /// Print a line to stderr.
    static func warn(_ message: String) {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
    }

    /// Print structured JSON to stdout.
    static func emitJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    /// Pipe stdin/stdout/stderr into a child process and return its exit code.
    @discardableResult
    static func runInherit(_ path: String, arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Fetch secrets honoring the all-environments sentinel (`*`).
    /// Returns secrets with `environment` populated so callers can disambiguate.
    static func fetchSecrets(
        config: AppConfiguration,
        envOverride: String? = nil,
        pathOverride: String? = nil
    ) async throws -> [SecretItem] {
        let effectiveEnv = envOverride ?? config.environment
        let effectivePath = pathOverride ?? config.secretPath

        // Fast path: a concrete env slug.
        if effectiveEnv != AppConfiguration.allEnvironmentsSentinel {
            let items = try await InfisicalCLIService.listSecretsViaAPI(
                environment: effectiveEnv,
                projectId: config.projectId,
                secretPath: effectivePath,
                baseURL: config.baseURL
            )
            return items.map { var c = $0; c.environment = effectiveEnv; return c }
        }

        // All-envs fan-out: resolve project env slugs, then list per env.
        let orgId: String
        if let configured = config.organizationId {
            orgId = configured
        } else {
            let orgs = try await InfisicalCLIService.fetchOrganizations(baseURL: config.baseURL)
            guard let first = orgs.first else { throw ValidationError("No organizations available.") }
            orgId = first.id
        }
        let projects = try await InfisicalCLIService.fetchProjects(orgId: orgId, baseURL: config.baseURL)
        guard let project = projects.first(where: { $0.id == config.projectId }) else {
            throw ValidationError("Configured project \(config.projectId) not found.")
        }
        let envSlugs = project.environments.map(\.slug)

        return try await withThrowingTaskGroup(of: (Int, [SecretItem]).self) { group in
            for (idx, slug) in envSlugs.enumerated() {
                group.addTask {
                    let items = try await InfisicalCLIService.listSecretsViaAPI(
                        environment: slug,
                        projectId: config.projectId,
                        secretPath: effectivePath,
                        baseURL: config.baseURL
                    )
                    let tagged = items.map { var c = $0; c.environment = slug; return c }
                    return (idx, tagged)
                }
            }
            var collected: [(Int, [SecretItem])] = []
            for try await result in group { collected.append(result) }
            collected.sort { $0.0 < $1.0 }
            return collected.flatMap { $0.1 }
        }
    }

    /// Resolve the `infisical` CLI path, mirroring InfisicalCLIService logic for shell-outs.
    static func infisicalPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/infisical",
            "/usr/local/bin/infisical",
            "/usr/bin/infisical",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        return nil
    }
}

/// Lightweight validation error so subcommands can fail with non-zero exit + clean message.
struct ValidationError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { self.description = message }
}
