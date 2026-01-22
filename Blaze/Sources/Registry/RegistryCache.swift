import Foundation
import GRDB
import os.log

// MARK: - SQLite Registry Cache

/// SQLite-backed registry cache with 24-hour TTL.
///
/// Stores skills, plugins, and agents in normalized tables with JSON serialization
/// for complex fields. Thread-safe via actor isolation.
public actor SQLiteRegistryCache: RegistryCache {

    // MARK: - Properties

    private var dbPool: DatabasePool?
    private let dbPath: URL
    private let logger = Logger(subsystem: "com.cogit0.Blaze", category: "RegistryCache")

    /// Default cache location in user's Caches directory
    public static var defaultCachePath: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches
            .appendingPathComponent("com.cogit0.Blaze", isDirectory: true)
            .appendingPathComponent("registry.sqlite")
    }

    // MARK: - Initialization

    /// Creates a new SQLite registry cache.
    /// - Parameter path: Path to the SQLite database file. Defaults to standard cache location.
    public init(path: URL = SQLiteRegistryCache.defaultCachePath) {
        self.dbPath = path
    }

    // MARK: - RegistryCache Protocol

    public func load() async -> RegistryResponse? {
        do {
            let db = try await getDatabase()

            return try await db.read { db in
                // Get metadata for lastUpdated
                guard let metadata = try CacheMetadata.fetchOne(db, key: "lastUpdated"),
                      let timestamp = TimeInterval(metadata.value) else {
                    return nil
                }

                let lastUpdated = Date(timeIntervalSince1970: timestamp)

                // Load all items
                let skills = try CachedSkill.fetchAll(db).compactMap { $0.toSkillItem() }
                let plugins = try CachedPlugin.fetchAll(db).compactMap { $0.toPluginItem() }
                let agents = try CachedAgent.fetchAll(db).compactMap { $0.toAgentItem() }

                return RegistryResponse(
                    skills: skills,
                    plugins: plugins,
                    agents: agents,
                    lastUpdated: lastUpdated
                )
            }
        } catch {
            logger.error("Failed to load cache: \(error.localizedDescription)")
            return nil
        }
    }

    public func save(_ response: RegistryResponse) async {
        do {
            let db = try await getDatabase()

            try await db.write { db in
                // Clear existing data
                try CachedSkill.deleteAll(db)
                try CachedPlugin.deleteAll(db)
                try CachedAgent.deleteAll(db)

                // Insert skills
                for skill in response.skills {
                    try CachedSkill(from: skill).insert(db)
                }

                // Insert plugins
                for plugin in response.plugins {
                    try CachedPlugin(from: plugin).insert(db)
                }

                // Insert agents
                for agent in response.agents {
                    try CachedAgent(from: agent).insert(db)
                }

                // Update metadata
                try CacheMetadata(
                    key: "lastUpdated",
                    value: String(response.lastUpdated.timeIntervalSince1970)
                ).save(db)
            }

            logger.debug("Saved \(response.skills.count) skills, \(response.plugins.count) plugins, \(response.agents.count) agents to cache")

        } catch {
            logger.error("Failed to save cache: \(error.localizedDescription)")
        }
    }

    public func clear() async {
        do {
            let db = try await getDatabase()

            try await db.write { db in
                try CachedSkill.deleteAll(db)
                try CachedPlugin.deleteAll(db)
                try CachedAgent.deleteAll(db)
                try CacheMetadata.deleteAll(db)
            }

            logger.debug("Cache cleared")

        } catch {
            logger.error("Failed to clear cache: \(error.localizedDescription)")
        }
    }

    // MARK: - Additional API (beyond protocol)

    /// Check if cached data is older than the specified age.
    /// - Parameter maxAge: Maximum age in seconds (default: 24 hours)
    /// - Returns: True if cache is stale or empty
    public func isStale(maxAge: TimeInterval = 86400) async -> Bool {
        do {
            let db = try await getDatabase()

            return try await db.read { db in
                guard let metadata = try CacheMetadata.fetchOne(db, key: "lastUpdated"),
                      let timestamp = TimeInterval(metadata.value) else {
                    return true // No cache = stale
                }

                let age = Date().timeIntervalSince1970 - timestamp
                return age > maxAge
            }
        } catch {
            return true
        }
    }

    // MARK: - Private Helpers

    private func getDatabase() async throws -> DatabasePool {
        if let existing = dbPool {
            return existing
        }

        // Ensure directory exists
        let directory = dbPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Create/open database
        var config = Configuration()
        config.prepareDatabase { db in
            // Enable foreign keys
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        let pool = try DatabasePool(path: dbPath.path, configuration: config)

        // Run migrations
        try await pool.write { db in
            try Self.createSchema(in: db)
        }

        dbPool = pool
        logger.debug("Database opened at \(self.dbPath.path)")

        return pool
    }

    private static func createSchema(in db: Database) throws {
        // Cache metadata table
        try db.create(table: "cache_metadata", ifNotExists: true) { t in
            t.column("key", .text).primaryKey()
            t.column("value", .text).notNull()
        }

        // Skills table
        try db.create(table: "skills", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("description", .text).notNull()
            t.column("author", .text).notNull()
            t.column("version", .text).notNull()
            t.column("category", .text).notNull()
            t.column("compatibleCLIs", .text).notNull() // JSON array
            t.column("permissions", .text).notNull()    // JSON object
            t.column("metadata", .text)                  // JSON object, nullable
            t.column("downloadURL", .text)
            t.column("sha256Checksum", .text)
        }

        // Plugins table
        try db.create(table: "plugins", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("description", .text).notNull()
            t.column("author", .text).notNull()
            t.column("version", .text).notNull()
            t.column("category", .text).notNull()
            t.column("forCLI", .text).notNull()
            t.column("permissions", .text).notNull()
            t.column("metadata", .text)
            t.column("downloadURL", .text)
            t.column("sha256Checksum", .text)
        }

        // Agents table
        try db.create(table: "agents", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("description", .text).notNull()
            t.column("author", .text).notNull()
            t.column("version", .text).notNull()
            t.column("category", .text).notNull()
            t.column("useCase", .text).notNull()
            t.column("permissions", .text).notNull()
            t.column("metadata", .text)
            t.column("downloadURL", .text)
            t.column("sha256Checksum", .text)
        }
    }
}

// MARK: - Cache Metadata Record

private struct CacheMetadata: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "cache_metadata"

    var key: String
    var value: String

    static func fetchOne(_ db: Database, key: String) throws -> CacheMetadata? {
        try CacheMetadata.filter(Column("key") == key).fetchOne(db)
    }
}

// MARK: - Cached Skill Record

private struct CachedSkill: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "skills"

    var id: String
    var name: String
    var description: String
    var author: String
    var version: String
    var category: String
    var compatibleCLIs: String   // JSON
    var permissions: String      // JSON
    var metadata: String?        // JSON
    var downloadURL: String?
    var sha256Checksum: String?

    init(from skill: SkillItem) {
        self.id = skill.id
        self.name = skill.name
        self.description = skill.description
        self.author = skill.author
        self.version = skill.version
        self.category = skill.category
        self.compatibleCLIs = (try? JSONEncoder().encode(skill.compatibleCLIs).base64EncodedString()) ?? "[]"
        self.permissions = (try? String(data: JSONEncoder().encode(skill.permissions), encoding: .utf8)) ?? "{}"
        self.metadata = skill.metadata.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) }
        self.downloadURL = skill.downloadURL?.absoluteString
        self.sha256Checksum = skill.sha256Checksum
    }

    func toSkillItem() -> SkillItem? {
        guard let cliData = Data(base64Encoded: compatibleCLIs),
              let clis = try? JSONDecoder().decode([String].self, from: cliData),
              let permData = permissions.data(using: .utf8),
              let perms = try? JSONDecoder().decode(RegistryPermissions.self, from: permData) else {
            return nil
        }

        let meta: RegistryMetadata? = metadata.flatMap { str in
            guard let data = str.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(RegistryMetadata.self, from: data)
        }

        return SkillItem(
            id: id,
            name: name,
            description: description,
            author: author,
            version: version,
            category: category,
            compatibleCLIs: clis,
            permissions: perms,
            metadata: meta,
            downloadURL: downloadURL.flatMap { URL(string: $0) },
            sha256Checksum: sha256Checksum
        )
    }
}

// MARK: - Cached Plugin Record

private struct CachedPlugin: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "plugins"

    var id: String
    var name: String
    var description: String
    var author: String
    var version: String
    var category: String
    var forCLI: String
    var permissions: String
    var metadata: String?
    var downloadURL: String?
    var sha256Checksum: String?

    init(from plugin: PluginItem) {
        self.id = plugin.id
        self.name = plugin.name
        self.description = plugin.description
        self.author = plugin.author
        self.version = plugin.version
        self.category = plugin.category
        self.forCLI = plugin.forCLI
        self.permissions = (try? String(data: JSONEncoder().encode(plugin.permissions), encoding: .utf8)) ?? "{}"
        self.metadata = plugin.metadata.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) }
        self.downloadURL = plugin.downloadURL?.absoluteString
        self.sha256Checksum = plugin.sha256Checksum
    }

    func toPluginItem() -> PluginItem? {
        guard let permData = permissions.data(using: .utf8),
              let perms = try? JSONDecoder().decode(RegistryPermissions.self, from: permData) else {
            return nil
        }

        let meta: RegistryMetadata? = metadata.flatMap { str in
            guard let data = str.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(RegistryMetadata.self, from: data)
        }

        return PluginItem(
            id: id,
            name: name,
            description: description,
            author: author,
            version: version,
            category: category,
            forCLI: forCLI,
            permissions: perms,
            metadata: meta,
            downloadURL: downloadURL.flatMap { URL(string: $0) },
            sha256Checksum: sha256Checksum
        )
    }
}

// MARK: - Cached Agent Record

private struct CachedAgent: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agents"

    var id: String
    var name: String
    var description: String
    var author: String
    var version: String
    var category: String
    var useCase: String
    var permissions: String
    var metadata: String?
    var downloadURL: String?
    var sha256Checksum: String?

    init(from agent: AgentItem) {
        self.id = agent.id
        self.name = agent.name
        self.description = agent.description
        self.author = agent.author
        self.version = agent.version
        self.category = agent.category
        self.useCase = agent.useCase.rawValue
        self.permissions = (try? String(data: JSONEncoder().encode(agent.permissions), encoding: .utf8)) ?? "{}"
        self.metadata = agent.metadata.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) }
        self.downloadURL = agent.downloadURL?.absoluteString
        self.sha256Checksum = agent.sha256Checksum
    }

    func toAgentItem() -> AgentItem? {
        guard let permData = permissions.data(using: .utf8),
              let perms = try? JSONDecoder().decode(RegistryPermissions.self, from: permData),
              let useCaseEnum = AgentUseCase(rawValue: useCase) else {
            return nil
        }

        let meta: RegistryMetadata? = metadata.flatMap { str in
            guard let data = str.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(RegistryMetadata.self, from: data)
        }

        return AgentItem(
            id: id,
            name: name,
            description: description,
            author: author,
            version: version,
            category: category,
            useCase: useCaseEnum,
            permissions: perms,
            metadata: meta,
            downloadURL: downloadURL.flatMap { URL(string: $0) },
            sha256Checksum: sha256Checksum
        )
    }
}
