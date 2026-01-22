import Foundation
import GRDB

// MARK: - Prompt Store

/// Persistent storage for saved prompts and templates.
///
/// **Phase 2 System Contract:**
/// - Supports both user prompts and system templates
/// - Per-repo scoping for project-specific prompts
/// - Variable substitution for templates
public actor PromptStore {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) throws {
        self.dbPool = dbPool
        try ensureTable()
    }

    // MARK: - Table Setup

    private func ensureTable() throws {
        try dbPool.write { db in
            guard try !db.tableExists("prompts") else { return }

            try db.create(table: "prompts") { t in
                t.column("id", .text).primaryKey()
                t.column("repo_id", .text)
                    .references("repos", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("content", .text).notNull()
                t.column("description", .text)
                t.column("category", .text)
                t.column("is_template", .boolean).notNull().defaults(to: false)
                t.column("variables_json", .text)  // JSON array of variable names
                t.column("shortcut", .text)  // Keyboard shortcut e.g., "cmd+1"
                t.column("display_order", .integer).notNull().defaults(to: 0)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("use_count", .integer).notNull().defaults(to: 0)
                t.column("last_used_at", .datetime)
            }
            try db.create(index: "prompts_repo_id", on: "prompts", columns: ["repo_id"])
            try db.create(index: "prompts_category", on: "prompts", columns: ["category"])
        }
    }

    // MARK: - CRUD Operations

    /// Create a new prompt
    public func create(_ prompt: SavedPrompt) async throws {
        try await dbPool.write { db in
            try PromptRecord(prompt).insert(db)
        }
    }

    /// Get a prompt by ID
    public func get(id: UUID) async throws -> SavedPrompt? {
        try await dbPool.read { db in
            try PromptRecord.fetchOne(db, key: id.uuidString)?.toPrompt()
        }
    }

    /// Get all prompts for a repo
    public func getPrompts(repoId: UUID?) async throws -> [SavedPrompt] {
        try await dbPool.read { db in
            if let repoId = repoId {
                return try PromptRecord
                    .filter(Column("repo_id") == repoId.uuidString || Column("repo_id") == nil)
                    .order(Column("display_order"), Column("name"))
                    .fetchAll(db)
                    .map { $0.toPrompt() }
            } else {
                return try PromptRecord
                    .filter(Column("repo_id") == nil)
                    .order(Column("display_order"), Column("name"))
                    .fetchAll(db)
                    .map { $0.toPrompt() }
            }
        }
    }

    /// Get prompts by category
    public func getPrompts(category: String, repoId: UUID? = nil) async throws -> [SavedPrompt] {
        try await dbPool.read { db in
            var query = PromptRecord.filter(Column("category") == category)
            if let repoId = repoId {
                query = query.filter(Column("repo_id") == repoId.uuidString || Column("repo_id") == nil)
            }
            return try query
                .order(Column("display_order"), Column("name"))
                .fetchAll(db)
                .map { $0.toPrompt() }
        }
    }

    /// Get frequently used prompts
    public func getFrequentlyUsed(limit: Int = 10) async throws -> [SavedPrompt] {
        try await dbPool.read { db in
            try PromptRecord
                .filter(Column("use_count") > 0)
                .order(Column("use_count").desc)
                .limit(limit)
                .fetchAll(db)
                .map { $0.toPrompt() }
        }
    }

    /// Get recently used prompts
    public func getRecentlyUsed(limit: Int = 10) async throws -> [SavedPrompt] {
        try await dbPool.read { db in
            try PromptRecord
                .filter(Column("last_used_at") != nil)
                .order(Column("last_used_at").desc)
                .limit(limit)
                .fetchAll(db)
                .map { $0.toPrompt() }
        }
    }

    /// Update a prompt
    public func update(_ prompt: SavedPrompt) async throws {
        try await dbPool.write { db in
            try PromptRecord(prompt).update(db)
        }
    }

    /// Delete a prompt
    public func delete(id: UUID) async throws {
        _ = try await dbPool.write { db in
            try PromptRecord.deleteOne(db, key: id.uuidString)
        }
    }

    /// Record a prompt use
    public func recordUse(id: UUID) async throws {
        try await dbPool.write { db in
            try db.execute(sql: """
                UPDATE prompts
                SET use_count = use_count + 1, last_used_at = ?
                WHERE id = ?
            """, arguments: [Date(), id.uuidString])
        }
    }

    /// Search prompts
    public func search(query: String, repoId: UUID? = nil) async throws -> [SavedPrompt] {
        try await dbPool.read { db in
            let pattern = "%\(query)%"
            var sql = PromptRecord
                .filter(Column("name").like(pattern) || Column("content").like(pattern) || Column("description").like(pattern))

            if let repoId = repoId {
                sql = sql.filter(Column("repo_id") == repoId.uuidString || Column("repo_id") == nil)
            }

            return try sql
                .order(Column("name"))
                .fetchAll(db)
                .map { $0.toPrompt() }
        }
    }
}

// MARK: - SavedPrompt Model

/// A saved prompt or template
public struct SavedPrompt: Identifiable, Codable, Sendable {
    public let id: UUID
    public let repoId: UUID?
    public var name: String
    public var content: String
    public var description: String?
    public var category: String?
    public var isTemplate: Bool
    public var variables: [String]
    public var shortcut: String?
    public var displayOrder: Int
    public let createdAt: Date
    public var updatedAt: Date
    public var useCount: Int
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        repoId: UUID? = nil,
        name: String,
        content: String,
        description: String? = nil,
        category: String? = nil,
        isTemplate: Bool = false,
        variables: [String] = [],
        shortcut: String? = nil,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.repoId = repoId
        self.name = name
        self.content = content
        self.description = description
        self.category = category
        self.isTemplate = isTemplate
        self.variables = variables
        self.shortcut = shortcut
        self.displayOrder = displayOrder
        self.createdAt = Date()
        self.updatedAt = Date()
        self.useCount = 0
        self.lastUsedAt = nil
    }

    /// Substitute variables in the template content
    public func substitute(values: [String: String]) -> String {
        var result = content
        for (variable, value) in values {
            result = result.replacingOccurrences(of: "{{\(variable)}}", with: value)
        }
        return result
    }
}

// MARK: - Prompt Categories

/// Standard prompt categories
public enum PromptCategory: String, CaseIterable, Sendable {
    case general = "General"
    case refactoring = "Refactoring"
    case debugging = "Debugging"
    case documentation = "Documentation"
    case testing = "Testing"
    case review = "Code Review"
    case explanation = "Explanation"
    case custom = "Custom"
}

// MARK: - Database Record

private struct PromptRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "prompts"

    let id: String
    let repoId: String?
    var name: String
    var content: String
    var description: String?
    var category: String?
    var isTemplate: Bool
    var variablesJson: String?
    var shortcut: String?
    var displayOrder: Int
    let createdAt: Date
    var updatedAt: Date
    var useCount: Int
    var lastUsedAt: Date?

    init(_ prompt: SavedPrompt) {
        self.id = prompt.id.uuidString
        self.repoId = prompt.repoId?.uuidString
        self.name = prompt.name
        self.content = prompt.content
        self.description = prompt.description
        self.category = prompt.category
        self.isTemplate = prompt.isTemplate
        self.variablesJson = prompt.variables.isEmpty ? nil : (try? JSONEncoder().encode(prompt.variables)).flatMap { String(data: $0, encoding: .utf8) }
        self.shortcut = prompt.shortcut
        self.displayOrder = prompt.displayOrder
        self.createdAt = prompt.createdAt
        self.updatedAt = prompt.updatedAt
        self.useCount = prompt.useCount
        self.lastUsedAt = prompt.lastUsedAt
    }

    func toPrompt() -> SavedPrompt {
        var prompt = SavedPrompt(
            id: UUID(uuidString: id)!,
            repoId: repoId.flatMap { UUID(uuidString: $0) },
            name: name,
            content: content,
            description: description,
            category: category,
            isTemplate: isTemplate,
            variables: variablesJson.flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) } ?? [],
            shortcut: shortcut,
            displayOrder: displayOrder
        )
        prompt.useCount = useCount
        prompt.lastUsedAt = lastUsedAt
        return prompt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case repoId = "repo_id"
        case name
        case content
        case description
        case category
        case isTemplate = "is_template"
        case variablesJson = "variables_json"
        case shortcut
        case displayOrder = "display_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case useCount = "use_count"
        case lastUsedAt = "last_used_at"
    }
}
