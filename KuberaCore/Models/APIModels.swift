import Foundation

public struct InfisicalOrg: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let slug: String?
}

public struct InfisicalProject: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let slug: String?
    public let environments: [InfisicalEnvironment]
}

public struct InfisicalEnvironment: Codable, Identifiable, Hashable {
    public let name: String
    public let slug: String

    public var id: String { slug }
}

public struct OrgsResponse: Codable {
    public let organizations: [InfisicalOrg]
}

public struct WorkspacesResponse: Codable {
    public let workspaces: [InfisicalProject]
}

public struct InfisicalTag: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String?
    public let slug: String
    public let color: String?

    /// Display name: use name if available, otherwise slug
    public var displayName: String { name ?? slug }
}

public struct TagsResponse: Codable {
    public let workspaceTags: [InfisicalTag]
}

public struct SecretsListResponse: Codable {
    public let secrets: [SecretItem]
}
