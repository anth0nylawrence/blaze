import Foundation

// MARK: - Top-level Response

/// Container for all registry items from the community registry API
public struct RegistryResponse: Codable, Sendable, Hashable {
    public let skills: [SkillItem]
    public let plugins: [PluginItem]
    public let agents: [AgentItem]
    public let lastUpdated: Date

    public init(
        skills: [SkillItem],
        plugins: [PluginItem],
        agents: [AgentItem],
        lastUpdated: Date
    ) {
        self.skills = skills
        self.plugins = plugins
        self.agents = agents
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Skill Item

/// A community skill installable via the registry
public struct SkillItem: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let author: String
    public let version: String
    public let category: String
    public let compatibleCLIs: [String]
    public let permissions: RegistryPermissions
    public let metadata: RegistryMetadata?
    /// URL to download the skill archive
    public let downloadURL: URL?
    /// SHA256 checksum of the download archive
    public let sha256Checksum: String?

    public init(
        id: String,
        name: String,
        description: String,
        author: String,
        version: String,
        category: String,
        compatibleCLIs: [String],
        permissions: RegistryPermissions,
        metadata: RegistryMetadata? = nil,
        downloadURL: URL? = nil,
        sha256Checksum: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.category = category
        self.compatibleCLIs = compatibleCLIs
        self.permissions = permissions
        self.metadata = metadata
        self.downloadURL = downloadURL
        self.sha256Checksum = sha256Checksum
    }
}

// MARK: - Plugin Item

/// A community plugin installable via the registry
public struct PluginItem: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let author: String
    public let version: String
    public let category: String
    public let forCLI: String
    public let permissions: RegistryPermissions
    public let metadata: RegistryMetadata?
    /// URL to download the plugin archive
    public let downloadURL: URL?
    /// SHA256 checksum of the download archive
    public let sha256Checksum: String?

    public init(
        id: String,
        name: String,
        description: String,
        author: String,
        version: String,
        category: String,
        forCLI: String,
        permissions: RegistryPermissions,
        metadata: RegistryMetadata? = nil,
        downloadURL: URL? = nil,
        sha256Checksum: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.category = category
        self.forCLI = forCLI
        self.permissions = permissions
        self.metadata = metadata
        self.downloadURL = downloadURL
        self.sha256Checksum = sha256Checksum
    }
}

// MARK: - Agent Item

/// A community agent installable via the registry
public struct AgentItem: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let author: String
    public let version: String
    public let category: String
    public let useCase: AgentUseCase
    public let permissions: RegistryPermissions
    public let metadata: RegistryMetadata?
    /// URL to download the agent archive
    public let downloadURL: URL?
    /// SHA256 checksum of the download archive
    public let sha256Checksum: String?

    public init(
        id: String,
        name: String,
        description: String,
        author: String,
        version: String,
        category: String,
        useCase: AgentUseCase,
        permissions: RegistryPermissions,
        metadata: RegistryMetadata? = nil,
        downloadURL: URL? = nil,
        sha256Checksum: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.category = category
        self.useCase = useCase
        self.permissions = permissions
        self.metadata = metadata
        self.downloadURL = downloadURL
        self.sha256Checksum = sha256Checksum
    }
}

// MARK: - Agent Use Case

/// Categories of agent specialization
public enum AgentUseCase: String, Codable, Sendable, Hashable, CaseIterable {
    case planning
    case debugging
    case security
    case research
    case refactoring
    case testing
    case documentation
    case other
}

// MARK: - Registry Metadata

/// Author and licensing metadata for registry items
public struct RegistryMetadata: Codable, Sendable, Hashable {
    public let authorEmail: String?
    public let license: String
    public let repositoryURL: URL?
    public let homepage: URL?
    public let versionConstraint: VersionConstraint?

    public init(
        authorEmail: String? = nil,
        license: String,
        repositoryURL: URL? = nil,
        homepage: URL? = nil,
        versionConstraint: VersionConstraint? = nil
    ) {
        self.authorEmail = authorEmail
        self.license = license
        self.repositoryURL = repositoryURL
        self.homepage = homepage
        self.versionConstraint = versionConstraint
    }
}

// MARK: - Registry Permissions

/// Permissions required by a registry item
public struct RegistryPermissions: Codable, Sendable, Hashable {
    public let tools: [String]
    public let fileAccess: Bool
    public let networkAccess: Bool

    public init(
        tools: [String] = [],
        fileAccess: Bool = false,
        networkAccess: Bool = false
    ) {
        self.tools = tools
        self.fileAccess = fileAccess
        self.networkAccess = networkAccess
    }

    /// A safe default with no permissions
    public static let none = RegistryPermissions()
}

// MARK: - Version Constraint

/// Semantic version constraints for compatibility checking
public struct VersionConstraint: Codable, Sendable, Hashable {
    public let minVersion: String?
    public let maxVersion: String?

    public init(minVersion: String? = nil, maxVersion: String? = nil) {
        self.minVersion = minVersion
        self.maxVersion = maxVersion
    }

    /// Check if a given version string satisfies this constraint
    /// Uses basic semantic version comparison (major.minor.patch)
    public func isSatisfied(by version: String) -> Bool {
        if let min = minVersion, version.compare(min, options: .numeric) == .orderedAscending {
            return false
        }
        if let max = maxVersion, version.compare(max, options: .numeric) == .orderedDescending {
            return false
        }
        return true
    }
}
