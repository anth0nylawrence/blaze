import Foundation
import GRDB

// MARK: - Session Store

/// Persistent storage for sessions using SQLite via GRDB.
/// Fallback from LanceDB (no Swift bindings available).
///
/// **Phase 2 System Contract:**
/// - Uses MigrationRunner for idempotent, transactional migrations
/// - WAL mode for concurrency and durability
/// - Schema version tracked in schema_version table
actor SessionStore {
    private let dbPool: DatabasePool
    private let migrationRunner: MigrationRunner
    private var schemaVersion: Int = 0

    /// Initialize with database path.
    /// Migrations run automatically on init.
    init(path: String) throws {
        // Create database directory if needed
        let dbURL = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: dbURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Open database with WAL mode for better concurrency
        var config = Configuration()
        config.prepareDatabase { db in
            // Enable WAL mode per System Contract
            try? db.execute(sql: "PRAGMA journal_mode = WAL")
            try? db.execute(sql: "PRAGMA synchronous = NORMAL")
            // Only trace in debug builds
            #if DEBUG
            db.trace { print("SQL: \($0)") }
            #endif
        }

        dbPool = try DatabasePool(path: path, configuration: config)
        migrationRunner = MigrationRunner(dbPool: dbPool)
    }

    /// Run migrations and return schema version.
    /// Call this after init to run migrations.
    func runMigrations() async throws -> Int {
        schemaVersion = try await migrationRunner.runMigrations()
        return schemaVersion
    }

    /// Run background backfills after app launch.
    func runBackfillsInBackground() async {
        await migrationRunner.runBackfillsInBackground()
    }

    /// Get current schema version.
    func getSchemaVersion() async throws -> Int {
        try await migrationRunner.getCurrentVersion()
    }

    /// Get the database pool for direct access (use sparingly).
    nonisolated var database: DatabasePool { dbPool }

    // MARK: - CRUD Operations

    /// Create a new session
    func create(_ session: Session) async throws {
        try await dbPool.write { db in
            try SessionRecord(session).insert(db)
        }
    }

    /// Get a session by ID
    func get(id: UUID) async throws -> Session? {
        try await dbPool.read { db in
            guard let record = try SessionRecord.fetchOne(db, key: id.uuidString) else {
                return nil
            }
            let messages = try MessageRecord
                .filter(Column("session_id") == id.uuidString)
                .order(Column("timestamp"))
                .fetchAll(db)
            return record.toSession(messages: messages.map { $0.toMessage() })
        }
    }

    /// Get all sessions
    func getAll() async throws -> [Session] {
        try await dbPool.read { db in
            let records = try SessionRecord.order(Column("updated_at").desc).fetchAll(db)
            return try records.map { record in
                let messages = try MessageRecord
                    .filter(Column("session_id") == record.id)
                    .order(Column("timestamp"))
                    .fetchAll(db)
                return record.toSession(messages: messages.map { $0.toMessage() })
            }
        }
    }

    /// Update a session
    func update(_ session: Session) async throws {
        try await dbPool.write { db in
            try SessionRecord(session).update(db)
        }
    }

    /// Delete a session
    func delete(id: UUID) async throws {
        _ = try await dbPool.write { db in
            try SessionRecord.deleteOne(db, key: id.uuidString)
        }
    }

    /// Add a message to a session
    func addMessage(_ message: Message, sessionId: UUID) async throws {
        try await dbPool.write { db in
            try MessageRecord(message, sessionId: sessionId).insert(db)
        }
    }

    /// Get messages for a session
    func getMessages(sessionId: UUID) async throws -> [Message] {
        try await dbPool.read { db in
            try MessageRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .order(Column("timestamp"))
                .fetchAll(db)
                .map { $0.toMessage() }
        }
    }

    // MARK: - Phase 2: Project Grouping

    /// Get sessions grouped by project (originalProjectPath).
    /// Returns a dictionary mapping canonical project paths to sessions.
    func getSessionsGroupedByProject() async throws -> [String: [Session]] {
        try await dbPool.read { db in
            let records = try SessionRecord.order(Column("updated_at").desc).fetchAll(db)

            var grouped: [String: [Session]] = [:]

            for record in records {
                let messages = try MessageRecord
                    .filter(Column("session_id") == record.id)
                    .order(Column("timestamp"))
                    .fetchAll(db)
                let session = record.toSession(messages: messages.map { $0.toMessage() })

                // Use originalProjectPath for grouping, fall back to projectPath, then "Uncategorized"
                let projectKey = session.originalProjectPath ?? session.projectPath ?? ""

                if grouped[projectKey] == nil {
                    grouped[projectKey] = []
                }
                grouped[projectKey]?.append(session)
            }

            return grouped
        }
    }

    /// Get sessions for a specific project path
    func getSessions(forProject projectPath: String) async throws -> [Session] {
        try await dbPool.read { db in
            let canonicalPath = PathUtilities.canonicalize(projectPath) ?? projectPath
            let records = try SessionRecord
                .filter(Column("original_project_path") == canonicalPath || Column("project_path") == canonicalPath)
                .order(Column("updated_at").desc)
                .fetchAll(db)

            return try records.map { record in
                let messages = try MessageRecord
                    .filter(Column("session_id") == record.id)
                    .order(Column("timestamp"))
                    .fetchAll(db)
                return record.toSession(messages: messages.map { $0.toMessage() })
            }
        }
    }

    /// Get all unique project paths (for sidebar project list)
    func getUniqueProjectPaths() async throws -> [String] {
        try await dbPool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT DISTINCT COALESCE(original_project_path, project_path) as project_path
                FROM sessions
                WHERE COALESCE(original_project_path, project_path) IS NOT NULL
                ORDER BY MAX(updated_at) DESC
            """)
            return rows.compactMap { $0["project_path"] as? String }
        }
    }

    /// Check if a session exists by ID
    func exists(id: UUID) async throws -> Bool {
        try await dbPool.read { db in
            try SessionRecord.fetchOne(db, key: id.uuidString) != nil
        }
    }

    /// Update session status
    func updateStatus(_ sessionId: UUID, status: SessionStatus) async throws {
        try await dbPool.write { db in
            try db.execute(sql: """
                UPDATE sessions SET status = ?, updated_at = ? WHERE id = ?
            """, arguments: [status.rawValue, Date(), sessionId.uuidString])
        }
    }

    /// Update session worktree path and branch name
    func updateWorktree(_ sessionId: UUID, worktreePath: String, branchName: String) async throws {
        try await dbPool.write { db in
            try db.execute(sql: """
                UPDATE sessions
                SET worktree_path = ?, branch_name = ?, status = ?, updated_at = ?
                WHERE id = ?
            """, arguments: [worktreePath, branchName, SessionStatus.ready.rawValue, Date(), sessionId.uuidString])
        }
    }
}

// MARK: - Database Records

private struct SessionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "sessions"

    let id: String
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var state: String
    var projectPath: String?
    var engineType: String
    var totalTokens: Int
    var totalCost: String
    var turnCount: Int
    var lastError: String?

    // Phase 2 fields
    var originalProjectPath: String?
    var worktreePath: String?
    var branchName: String?
    var status: String?
    var trustMode: String?
    var repoId: String?
    var ndjsonLogPath: String?
    var provider: String?
    var modelId: String?

    init(_ session: Session) {
        self.id = session.id.uuidString
        self.name = session.name
        self.createdAt = session.createdAt
        self.updatedAt = session.updatedAt
        self.state = session.state.rawValue
        self.projectPath = session.projectPath
        self.engineType = session.engineType.rawValue
        self.totalTokens = session.metadata.totalTokens
        self.totalCost = session.metadata.totalCost.description
        self.turnCount = session.metadata.turnCount
        self.lastError = session.metadata.lastError

        // Phase 2 fields
        self.originalProjectPath = session.originalProjectPath
        self.worktreePath = session.worktreePath
        self.branchName = session.branchName
        self.status = session.status.rawValue
        self.trustMode = session.trustMode.rawValue
        self.repoId = session.repoId?.uuidString
        self.ndjsonLogPath = session.ndjsonLogPath
        self.provider = session.provider.rawValue
        self.modelId = session.modelId
    }

    func toSession(messages: [Message]) -> Session {
        let resolvedProvider = AIProvider(rawValue: provider ?? "anthropic") ?? .anthropic
        // If modelId is missing/empty, derive from provider default
        let resolvedModelId: String
        if let storedModelId = modelId, !storedModelId.isEmpty {
            resolvedModelId = storedModelId
        } else {
            resolvedModelId = AIModelRegistry.defaultModel(for: resolvedProvider)?.id ?? "sonnet"
        }

        var session = Session(
            id: UUID(uuidString: id)!,
            name: name,
            originalProjectPath: originalProjectPath ?? projectPath,
            worktreePath: worktreePath,
            branchName: branchName,
            status: SessionStatus(rawValue: status ?? "ready") ?? .ready,
            trustMode: TrustMode(rawValue: trustMode ?? "prompt") ?? .prompt,
            engineType: EngineType(rawValue: engineType) ?? .claude,
            provider: resolvedProvider,
            modelId: resolvedModelId
        )
        session.projectPath = projectPath
        session.updatedAt = updatedAt
        session.state = SessionState(rawValue: state) ?? .idle
        session.messages = messages
        session.metadata = SessionMetadata(
            totalTokens: totalTokens,
            totalCost: Decimal(string: totalCost) ?? 0,
            turnCount: turnCount,
            lastError: lastError
        )
        session.repoId = repoId.flatMap { UUID(uuidString: $0) }
        session.ndjsonLogPath = ndjsonLogPath
        return session
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case state
        case projectPath = "project_path"
        case engineType = "engine_type"
        case totalTokens = "total_tokens"
        case totalCost = "total_cost"
        case turnCount = "turn_count"
        case lastError = "last_error"
        // Phase 2 fields
        case originalProjectPath = "original_project_path"
        case worktreePath = "worktree_path"
        case branchName = "branch_name"
        case status
        case trustMode = "trust_mode"
        case repoId = "repo_id"
        case ndjsonLogPath = "ndjson_log_path"
        case provider
        case modelId = "model_id"
    }
}

private struct MessageRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "messages"

    let id: String
    let sessionId: String
    let role: String
    var content: String
    var thinking: String?
    let timestamp: Date
    var toolCallsJson: String?
    var attachmentsJson: String?

    init(_ message: Message, sessionId: UUID) {
        self.id = message.id.uuidString
        self.sessionId = sessionId.uuidString
        self.role = message.role.rawValue
        self.content = message.content
        self.thinking = message.thinking
        self.timestamp = message.timestamp

        if !message.toolCalls.isEmpty {
            let encoder = JSONEncoder()
            self.toolCallsJson = try? String(data: encoder.encode(message.toolCalls), encoding: .utf8)
        }
        if !message.attachments.isEmpty {
            let encoder = JSONEncoder()
            self.attachmentsJson = try? String(data: encoder.encode(message.attachments), encoding: .utf8)
        }
    }

    func toMessage() -> Message {
        let decoder = JSONDecoder()
        let toolCalls: [ToolCall] = toolCallsJson.flatMap {
            try? decoder.decode([ToolCall].self, from: Data($0.utf8))
        } ?? []
        let attachments: [Attachment] = attachmentsJson.flatMap {
            try? decoder.decode([Attachment].self, from: Data($0.utf8))
        } ?? []

        return Message(
            id: UUID(uuidString: id)!,
            role: MessageRole(rawValue: role) ?? .user,
            content: content,
            thinking: thinking,
            toolCalls: toolCalls,
            attachments: attachments
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case role
        case content
        case thinking
        case timestamp
        case toolCallsJson = "tool_calls_json"
        case attachmentsJson = "attachments_json"
    }
}
