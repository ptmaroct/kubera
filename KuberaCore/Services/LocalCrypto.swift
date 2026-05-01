import Foundation
import CryptoKit
import CommonCrypto

public enum LocalCryptoError: LocalizedError {
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidArchive(String)

    public var errorDescription: String? {
        switch self {
        case .keyDerivationFailed: return "Failed to derive encryption key from password."
        case .encryptionFailed: return "Encryption failed."
        case .decryptionFailed: return "Decryption failed — wrong password or corrupted data."
        case .invalidArchive(let msg): return "Invalid backup archive: \(msg)"
        }
    }
}

/// AES-256-GCM seal/open + PBKDF2-SHA256 KDF for password-based archives.
/// Used by `KeychainSecretStore` (metadata file) and the encrypted backup format.
public enum LocalCrypto {

    // MARK: - Symmetric key seal/open

    /// Encrypt with a 32-byte symmetric key. Returns combined nonce+ciphertext+tag.
    public static func seal(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw LocalCryptoError.encryptionFailed
        }
        return combined
    }

    /// Decrypt combined data produced by `seal(_:key:)`.
    public static func open(_ combined: Data, key: SymmetricKey) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw LocalCryptoError.decryptionFailed
        }
    }

    // MARK: - PBKDF2

    /// Derive a 256-bit symmetric key from a password using PBKDF2-HMAC-SHA256.
    /// Default iteration count is OWASP 2023 recommendation for PBKDF2-SHA256.
    public static func deriveKey(
        password: String,
        salt: Data,
        iterations: Int = 600_000
    ) throws -> SymmetricKey {
        var derived = Data(count: 32)
        let passwordBytes = Array(password.utf8)
        let saltBytes = [UInt8](salt)

        let status = derived.withUnsafeMutableBytes { (derivedPtr: UnsafeMutableRawBufferPointer) -> Int32 in
            guard let derivedBase = derivedPtr.baseAddress else { return -1 }
            return CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordBytes, passwordBytes.count,
                saltBytes, saltBytes.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(iterations),
                derivedBase.assumingMemoryBound(to: UInt8.self), 32
            )
        }
        guard status == kCCSuccess else {
            throw LocalCryptoError.keyDerivationFailed
        }
        return SymmetricKey(data: derived)
    }

    public static func randomBytes(_ count: Int) -> Data {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return -1 }
            return Int32(SecRandomCopyBytes(kSecRandomDefault, count,
                                            base.assumingMemoryBound(to: UInt8.self)))
        }
        return data
    }
}

// MARK: - Backup archive format
//
// Layout (binary):
//   [0..3]    magic "KBRA"  (4 bytes)
//   [4]       version       (1 byte, currently 1)
//   [5]       reserved      (1 byte, must be 0)
//   [6..7]    iter exponent (2 bytes BE; iterations = 1 << exp; default exp = 19 → 524288)
//   [8..23]   salt          (16 bytes)
//   [24..]    AES-GCM combined: nonce(12) + ciphertext + tag(16)
//
// Plaintext = JSON-encoded `BackupPayload`.

public struct BackupPayload: Codable {
    public var version: Int
    public var createdAt: Date
    public var backendId: String
    public var secrets: [BackupSecret]
    public var tags: [SecretTag]?

    public init(version: Int = 1, createdAt: Date = Date(), backendId: String,
                secrets: [BackupSecret], tags: [SecretTag]? = nil) {
        self.version = version
        self.createdAt = createdAt
        self.backendId = backendId
        self.secrets = secrets
        self.tags = tags
    }
}

/// One secret in a backup archive. Mirrors `SecretItem` plus its environment/path
/// so a restore can place it back in the right namespace.
public struct BackupSecret: Codable {
    public var key: String
    public var value: String
    public var comment: String?
    public var tags: [SecretTag]?
    public var secretMetadata: [SecretMetadataEntry]?
    public var environment: String
    public var projectId: String
    public var secretPath: String

    public init(key: String, value: String, comment: String? = nil,
                tags: [SecretTag]? = nil, secretMetadata: [SecretMetadataEntry]? = nil,
                environment: String, projectId: String, secretPath: String) {
        self.key = key
        self.value = value
        self.comment = comment
        self.tags = tags
        self.secretMetadata = secretMetadata
        self.environment = environment
        self.projectId = projectId
        self.secretPath = secretPath
    }
}

public enum BackupArchive {
    static let magic: [UInt8] = [0x4B, 0x42, 0x52, 0x41] // "KBRA"
    static let currentVersion: UInt8 = 1
    static let saltSize = 16
    static let defaultIterExponent: UInt16 = 19 // 524_288 PBKDF2 rounds

    public static func encode(_ payload: BackupPayload, password: String) throws -> Data {
        let json = try jsonEncoder().encode(payload)
        let salt = LocalCrypto.randomBytes(saltSize)
        let iterations = 1 << Int(defaultIterExponent)
        let key = try LocalCrypto.deriveKey(password: password, salt: salt, iterations: iterations)
        let body = try LocalCrypto.seal(json, key: key)

        var out = Data()
        out.append(contentsOf: magic)
        out.append(currentVersion)
        out.append(0) // reserved
        out.append(UInt8((defaultIterExponent >> 8) & 0xFF))
        out.append(UInt8(defaultIterExponent & 0xFF))
        out.append(salt)
        out.append(body)
        return out
    }

    public static func decode(_ data: Data, password: String) throws -> BackupPayload {
        guard data.count > 24 else {
            throw LocalCryptoError.invalidArchive("file too small")
        }
        let bytes = [UInt8](data)
        guard Array(bytes[0..<4]) == magic else {
            throw LocalCryptoError.invalidArchive("bad magic")
        }
        let version = bytes[4]
        guard version == currentVersion else {
            throw LocalCryptoError.invalidArchive("unsupported version \(version)")
        }
        let iterExp = (UInt16(bytes[6]) << 8) | UInt16(bytes[7])
        guard iterExp >= 16 && iterExp <= 24 else {
            throw LocalCryptoError.invalidArchive("invalid PBKDF2 iter exponent")
        }
        let salt = Data(bytes[8..<(8 + saltSize)])
        let body = Data(bytes[(8 + saltSize)...])

        let key = try LocalCrypto.deriveKey(password: password, salt: salt,
                                            iterations: 1 << Int(iterExp))
        let json = try LocalCrypto.open(body, key: key)
        return try jsonDecoder().decode(BackupPayload.self, from: json)
    }

    private static func jsonEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
    private static func jsonDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
