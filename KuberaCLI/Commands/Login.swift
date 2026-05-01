import ArgumentParser
import Foundation
import KuberaCore

struct Login: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Sign in to Infisical via the bundled `infisical login` flow."
    )

    func run() async throws {
        guard let cli = Helpers.infisicalPath() else {
            throw ValidationError("infisical CLI not found. Install it: brew install infisical")
        }
        let status = try Helpers.runInherit(cli, arguments: ["login"])
        if status != 0 { throw ExitCode(status) }
    }
}

struct Logout: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Sign out of Infisical."
    )

    func run() async throws {
        guard let cli = Helpers.infisicalPath() else {
            throw ValidationError("infisical CLI not found.")
        }
        let status = try Helpers.runInherit(cli, arguments: ["logout"])
        if status != 0 { throw ExitCode(status) }
    }
}
