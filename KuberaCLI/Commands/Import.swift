import ArgumentParser
import Foundation
import KuberaCore

/// Restore from a `.kubera` encrypted backup. Routes through the active
/// `SecretStore` so the same archive can land in either the local store or
/// Infisical, depending on the current backend.
struct Import: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Restore secrets from an encrypted .kubera backup archive."
    )

    @Argument(help: "Path to the .kubera archive.") var file: String

    @Option(name: .long,
            help: "Backup password. Prompts on TTY if omitted. Avoid passing on the command line.")
    var password: String?

    @Flag(name: .long, help: "Overwrite existing secrets that share a (project, env, path, key).")
    var overwrite: Bool = false

    @Flag(name: .long, help: "Print what would be imported without writing.")
    var dryRun: Bool = false

    func run() async throws {
        let cfg = try Helpers.requireConfig()
        let url = URL(fileURLWithPath: (file as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("Archive not found: \(url.path)")
        }
        let blob = try Data(contentsOf: url)

        let pw: String
        if let provided = password, !provided.isEmpty {
            pw = provided
        } else {
            guard let entered = Helpers.readPassword(prompt: "Backup password: "),
                  !entered.isEmpty else {
                throw ValidationError("Password required.")
            }
            pw = entered
        }

        let payload: BackupPayload
        do {
            payload = try BackupArchive.decode(blob, password: pw)
        } catch {
            throw ValidationError(error.localizedDescription)
        }

        Helpers.warn("archive contains \(payload.secrets.count) secrets " +
                     "(created \(payload.createdAt), backend: \(payload.backendId))")

        if dryRun {
            for s in payload.secrets {
                print("\(s.environment)\t\(s.secretPath)\t\(s.key)")
            }
            return
        }

        let store = Helpers.activeStore(cfg)
        if cfg.isLocalBackend, let local = store as? KeychainSecretStore {
            let count = try await local.importBackup(payload.secrets, overwrite: overwrite)
            Helpers.warn("imported \(count) secrets into local store")
            return
        }

        // Infisical backend: write each secret one by one. Slower, but works
        // with whatever backend is active.
        var imported = 0
        var skipped = 0
        for item in payload.secrets {
            do {
                if overwrite {
                    try await store.updateSecret(
                        name: item.key, value: item.value,
                        comment: item.comment ?? "", tagIds: [],
                        tagsExplicit: false,
                        expiryDate: parsedExpiry(item),
                        serviceURL: parsedServiceURL(item),
                        metadataExplicit: true,
                        environment: item.environment,
                        projectId: item.projectId,
                        secretPath: item.secretPath
                    )
                    imported += 1
                } else {
                    try await store.createSecret(
                        name: item.key, value: item.value,
                        comment: item.comment ?? "", tagIds: [],
                        expiryDate: parsedExpiry(item),
                        serviceURL: parsedServiceURL(item),
                        environment: item.environment,
                        projectId: item.projectId,
                        secretPath: item.secretPath
                    )
                    imported += 1
                }
            } catch {
                Helpers.warn("skip \(item.key): \(error.localizedDescription)")
                skipped += 1
            }
        }
        Helpers.warn("imported \(imported), skipped \(skipped)")
    }

    private func parsedExpiry(_ s: BackupSecret) -> Date? {
        guard let raw = s.secretMetadata?.first(where: { $0.key == SecretMetadataKey.expiryDate })?.value,
              !raw.isEmpty else { return nil }
        return SecretMetadataDateFormatter.date(from: raw)
    }

    private func parsedServiceURL(_ s: BackupSecret) -> String? {
        s.secretMetadata?.first(where: { $0.key == SecretMetadataKey.serviceUrl })?.value
    }
}
