import ArgumentParser
import Foundation
import KuberaCore

struct Status: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show login state, configured project/environment, and config file location."
    )

    @Flag(help: "Emit machine-readable JSON.")
    var json: Bool = false

    func run() async throws {
        let installed = InfisicalCLIService.isInstalled()
        let loggedIn = installed ? await InfisicalCLIService.isLoggedIn() : false
        let cfg = AppConfiguration.load()

        struct Report: Encodable {
            let infisicalCLIInstalled: Bool
            let loggedIn: Bool
            let configFile: String
            let projectId: String?
            let projectName: String?
            let environment: String?
            let secretPath: String?
            let baseURL: String?
        }

        let report = Report(
            infisicalCLIInstalled: installed,
            loggedIn: loggedIn,
            configFile: AppConfiguration.configFileURL.path,
            projectId: cfg?.projectId,
            projectName: cfg?.projectName,
            environment: cfg?.environment,
            secretPath: cfg?.secretPath,
            baseURL: cfg?.baseURL
        )

        if json {
            try Helpers.emitJSON(report)
            return
        }

        print("infisical CLI:  \(installed ? "installed" : "MISSING (brew install infisical)")")
        print("logged in:     \(loggedIn ? "yes" : "no — run: kubera login")")
        print("config file:   \(report.configFile)")
        if let cfg {
            print("project:       \(cfg.projectName ?? cfg.projectId)  (\(cfg.projectId))")
            print("environment:   \(cfg.isAllEnvironments ? "All Environments" : cfg.environment)")
            print("secret path:   \(cfg.secretPath)")
            print("base URL:      \(cfg.baseURL)")
        } else {
            print("project:       <not configured> — run: kubera config set --project <id>")
        }
    }
}
