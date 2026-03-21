import Foundation

/// Represents a single secret from Infisical CLI export.
/// CLI `infisical export --format=json` outputs: [{"key": "...", "value": "...", "type": "...", ...}]
struct SecretItem: Codable, Identifiable, Hashable {
    let key: String
    let value: String
    let type: String?
    let comment: String?

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, value, type, comment
    }

    init(key: String, value: String, type: String? = nil, comment: String? = nil) {
        self.key = key
        self.value = value
        self.type = type
        self.comment = comment
    }
}
