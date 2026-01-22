import Foundation
import GRDB

// MARK: - Log Store

/// Persistent storage for unified logs (app, CLI stderr, hooks) using SQLite via GRDB.
///
/// **Phase 2 System Contract:**
/// - Ring buffer: Max 10,000 entries per session, auto-prune oldest
/// - Supports filtering by level (debug/info/warn/error) and source (app/cli/hooks)
/// - Session-scoped or app-level (nil sessionId)
/// - WAL mode for concurrency and durability
actor LogStore {
    private let dbPool: DatabasePool
    private let maxEntriesPerSession: Int = 10_000

    /// Initialize with database pool from SessionStore.
    /// Assumes migrations have already been run.
    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    /// Get the database pool for direct access (use sparingly).
    nonisolated var database: DatabasePool { dbPool }

    // MARK: - CRUD Operations

    /// Append a single log entry.
    /// Automatically prunes old entries if session limit exceeded.
    func append(_ entry: LogEntry) async throws {
        try await dbPool.write { db in
            try LogRecord(entry).insert(db)
        }

        // Prune if needed (only for session-scoped logs)
        if let sessionId = entry.sessionId {
            try await pruneIfNeeded(sessionId: sessionId)
        }
    }

    /// Append multiple log entries in a single transaction.
    /// Automatically prunes old entries if session limit exceeded.
    func appendBatch(_ entries: [LogEntry]) async throws {
        guard !entries.isEmpty else { return }

        try await dbPool.write { db in
            for entry in entries {
                try LogRecord(entry).insert(db)
            }
        }

        // Prune for each affected session
        let sessionIds = Set(entries.compactMap { $0.sessionId })
        for sessionId in sessionIds {
            try await pruneIfNeeded(sessionId: sessionId)
        }
    }

    /// Get logs with optional filters.
    /// - Parameters:
    ///   - sessionId: Filter by session (nil = app-level logs only, omit = all logs)
    ///   - level: Filter by log level
    ///   - source: Filter by log source
    ///   - limit: Max number of entries to return (default 1000)
    func getLogs(
        sessionId: UUID? = nil,
        level: LogLevel? = nil,
        source: LogSource? = nil,
        limit: Int = 1000
    ) async throws -> [LogEntry] {
        try await dbPool.read { db in
            var request = LogRecord.order(Column("timestamp").desc).limit(limit)

            // Session filter
            if let sessionId = sessionId {
                request = request.filter(Column("session_id") == sessionId.uuidString)
            }

            // Level filter
            if let level = level {
                request = request.filter(Column("level") == level.rawValue)
            }

            // Source filter
            if let source = source {
                request = request.filter(Column("source") == source.rawValue)
            }

            return try request.fetchAll(db).map { $0.toLogEntry() }
        }
    }

    /// Get logs for a specific session, ordered by timestamp ascending.
    func getLogsForSession(_ sessionId: UUID) async throws -> [LogEntry] {
        try await dbPool.read { db in
            try LogRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .order(Column("timestamp"))
                .fetchAll(db)
                .map { $0.toLogEntry() }
        }
    }

    /// Get log count for a session.
    func getLogCount(sessionId: UUID) async throws -> Int {
        try await dbPool.read { db in
            try LogRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .fetchCount(db)
        }
    }

    /// Clear all logs (optionally for a specific session).
    /// - Parameter sessionId: If provided, only clear logs for this session. If nil, clear all logs.
    func clear(sessionId: UUID? = nil) async throws {
        try await dbPool.write { db in
            if let sessionId = sessionId {
                try db.execute(
                    sql: "DELETE FROM logs WHERE session_id = ?",
                    arguments: [sessionId.uuidString]
                )
            } else {
                try db.execute(sql: "DELETE FROM logs")
            }
        }
    }

    /// Prune old entries for all sessions to enforce ring buffer limit.
    /// Called periodically (e.g., on app launch or background task).
    func pruneOldEntries() async throws {
        // Get all session IDs that have logs
        let sessionIds = try await dbPool.read { db -> [String] in
            let rows = try Row.fetchAll(db, sql: """
                SELECT DISTINCT session_id
                FROM logs
                WHERE session_id IS NOT NULL
            """)
            return rows.compactMap { $0["session_id"] as? String }
        }

        // Prune each session
        for sessionIdString in sessionIds {
            guard let sessionId = UUID(uuidString: sessionIdString) else { continue }
            try await pruneIfNeeded(sessionId: sessionId)
        }
    }

    // MARK: - Private Helpers

    /// Prune oldest entries for a session if count exceeds limit.
    private func pruneIfNeeded(sessionId: UUID) async throws {
        let count = try await getLogCount(sessionId: sessionId)

        if count > maxEntriesPerSession {
            let deleteCount = count - maxEntriesPerSession

            try await dbPool.write { db in
                // Delete oldest entries beyond limit
                try db.execute(sql: """
                    DELETE FROM logs
                    WHERE id IN (
                        SELECT id FROM logs
                        WHERE session_id = ?
                        ORDER BY timestamp ASC
                        LIMIT ?
                    )
                """, arguments: [sessionId.uuidString, deleteCount])
            }

            #if DEBUG
            print("[LogStore] Pruned \(deleteCount) old entries for session \(sessionId)")
            #endif
        }
    }
}

// MARK: - Database Records

private struct LogRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "logs"

    let id: String
    let sessionId: String?
    let timestamp: Date
    let level: String
    let source: String
    let message: String
    let metadataJson: String?

    init(_ entry: LogEntry) {
        self.id = entry.id.uuidString
        self.sessionId = entry.sessionId?.uuidString
        self.timestamp = entry.timestamp
        self.level = entry.level.rawValue
        self.source = entry.source.rawValue
        self.message = entry.message

        // Encode metadata if present
        if let metadata = entry.metadata, !metadata.isEmpty {
            let encoder = JSONEncoder()
            self.metadataJson = try? String(data: encoder.encode(metadata), encoding: .utf8)
        } else {
            self.metadataJson = nil
        }
    }

    func toLogEntry() -> LogEntry {
        // Decode metadata if present
        var metadata: [String: String]? = nil
        if let json = metadataJson {
            let decoder = JSONDecoder()
            metadata = try? decoder.decode([String: String].self, from: Data(json.utf8))
        }

        return LogEntry(
            id: UUID(uuidString: id)!,
            sessionId: sessionId.flatMap { UUID(uuidString: $0) },
            timestamp: timestamp,
            level: LogLevel(rawValue: level) ?? .info,
            source: LogSource(rawValue: source) ?? .app,
            message: message,
            metadata: metadata
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case timestamp
        case level
        case source
        case message
        case metadataJson = "metadata_json"
    }
}

// MARK: - Supporting Types

/// Log entry model (updated from LogsSidebarView to be Codable and support metadata)
public struct LogEntry: Identifiable, Codable {
    public let id: UUID
    public let sessionId: UUID?
    public let timestamp: Date
    public let level: LogLevel
    public let source: LogSource
    public let message: String
    public let metadata: [String: String]?

    public init(
        id: UUID = UUID(),
        sessionId: UUID? = nil,
        timestamp: Date = Date(),
        level: LogLevel,
        source: LogSource,
        message: String,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.level = level
        self.source = source
        self.message = message
        self.metadata = metadata
    }
}

/// Log level enum (matches LogsSidebarView)
public enum LogLevel: String, Codable, CaseIterable {
    case debug = "Debug"
    case info = "Info"
    case warn = "Warn"
    case error = "Error"
}

/// Log source enum (matches LogsSidebarView)
public enum LogSource: String, Codable, CaseIterable {
    case app = "App"
    case cli = "CLI"
    case hooks = "Hooks"
}
