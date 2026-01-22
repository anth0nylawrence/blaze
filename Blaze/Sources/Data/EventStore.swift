import Foundation
import GRDB

// MARK: - Event Store

/// Persistent storage for normalized events.
/// Uses SQLite for primary storage + per-session NDJSON for crash recovery.
///
/// **Phase 2 System Contract:**
/// - Events are strictly ordered by emission time
/// - Per-session NDJSON logs at ~/Library/Application Support/Blaze/sessions/<sessionId>/events.ndjson
/// - Belt-and-suspenders: writes to both SQLite and NDJSON
actor EventStore {
    private let dbPool: DatabasePool

    /// Per-session NDJSON loggers (lazy-initialized)
    private var sessionLoggers: [UUID: NDJSONLogger] = [:]

    /// Base directory for NDJSON logs
    private let ndjsonBaseDirectory: URL?

    init(dbPath: String, ndjsonBaseDirectory: URL? = nil) throws {
        // Open database (assumes migrations run via SessionStore)
        dbPool = try DatabasePool(path: dbPath)
        self.ndjsonBaseDirectory = ndjsonBaseDirectory
    }

    /// Legacy initializer for compatibility
    init(dbPath: String, jsonlPath: String) throws {
        dbPool = try DatabasePool(path: dbPath)
        self.ndjsonBaseDirectory = URL(fileURLWithPath: jsonlPath).deletingLastPathComponent()
    }

    // MARK: - Session Logger Management

    /// Get or create NDJSON logger for a session.
    private func getLogger(for sessionId: UUID) throws -> NDJSONLogger {
        if let existing = sessionLoggers[sessionId] {
            return existing
        }

        let logger = try NDJSONLogger(sessionId: sessionId, baseDirectory: ndjsonBaseDirectory)
        sessionLoggers[sessionId] = logger
        return logger
    }

    /// Close logger for a session (call when session ends).
    func closeSession(_ sessionId: UUID) async throws {
        if let logger = sessionLoggers[sessionId] {
            try await logger.close()
            sessionLoggers.removeValue(forKey: sessionId)
        }
    }

    // MARK: - Event Operations

    /// Append an event for a session.
    /// Writes to both SQLite and per-session NDJSON for durability.
    func append(_ event: NormalizedEvent, sessionId: UUID, sequence: Int) async throws {
        let envelope = EventEnvelope(sessionId: sessionId, sequence: sequence, event: event)

        // Get or create per-session logger
        let logger = try getLogger(for: sessionId)

        // Write to both SQLite and NDJSON (belt and suspenders, idempotent)
        async let dbWrite: Void = writeToDatabase(envelope)
        async let ndjsonWrite: Void = logger.append(envelope)

        _ = try await (dbWrite, ndjsonWrite)
    }

    /// Append an event envelope directly.
    func appendEnvelope(_ envelope: EventEnvelope) async throws {
        let logger = try getLogger(for: envelope.sessionId)

        async let dbWrite: Void = writeToDatabase(envelope)
        async let ndjsonWrite: Void = logger.append(envelope)

        _ = try await (dbWrite, ndjsonWrite)
    }

    /// Append multiple events in a batch (more efficient).
    func appendBatch(_ envelopes: [EventEnvelope]) async throws {
        guard !envelopes.isEmpty else { return }

        // Group by session
        let grouped = Dictionary(grouping: envelopes) { $0.sessionId }

        // Write to database in one transaction
        try await dbPool.write { db in
            for envelope in envelopes {
                try EventRecord(envelope).insert(db)
            }
        }

        // Write to per-session NDJSON logs
        for (sessionId, sessionEnvelopes) in grouped {
            let logger = try getLogger(for: sessionId)
            try await logger.appendBatch(sessionEnvelopes)
        }
    }

    private func writeToDatabase(_ envelope: EventEnvelope) async throws {
        try await dbPool.write { db in
            try EventRecord(envelope).insert(db)
        }
    }

    /// Get all events for a session
    func getEvents(sessionId: UUID) async throws -> [EventEnvelope] {
        try await dbPool.read { db in
            try EventRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .order(Column("sequence"))
                .fetchAll(db)
                .compactMap { $0.toEnvelope() }
        }
    }

    /// Get events after a specific sequence number
    func getEvents(sessionId: UUID, afterSequence: Int) async throws -> [EventEnvelope] {
        try await dbPool.read { db in
            try EventRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .filter(Column("sequence") > afterSequence)
                .order(Column("sequence"))
                .fetchAll(db)
                .compactMap { $0.toEnvelope() }
        }
    }

    /// Get the latest sequence number for a session
    func latestSequence(sessionId: UUID) async throws -> Int {
        try await dbPool.read { db in
            try EventRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .select(max(Column("sequence")))
                .fetchOne(db) ?? 0
        }
    }

    /// Delete all events for a session
    func deleteEvents(sessionId: UUID) async throws {
        _ = try await dbPool.write { db in
            try EventRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .deleteAll(db)
        }
    }

    /// Recover events from per-session NDJSON log (crash recovery).
    /// Returns events from NDJSON that are not in the database.
    func recoverFromNDJSON(sessionId: UUID) async throws -> [EventEnvelope] {
        // Check if log exists
        guard NDJSONLogger.logExists(for: sessionId, baseDirectory: ndjsonBaseDirectory) else {
            return []
        }

        // Get events from NDJSON
        let logger = try getLogger(for: sessionId)
        let ndjsonEvents = try await logger.readAll()

        // Get latest sequence from database
        let dbSequence = try await latestSequence(sessionId: sessionId)

        // Return events that are newer than what's in the database
        return ndjsonEvents.filter { $0.sequence > dbSequence }
    }

    /// Sync NDJSON events to database (call during app startup for crash recovery).
    func syncFromNDJSON(sessionId: UUID) async throws -> Int {
        let missingEvents = try await recoverFromNDJSON(sessionId: sessionId)

        if !missingEvents.isEmpty {
            try await dbPool.write { db in
                for envelope in missingEvents {
                    try EventRecord(envelope).insert(db)
                }
            }
            print("[EventStore] Recovered \(missingEvents.count) events from NDJSON for session \(sessionId)")
        }

        return missingEvents.count
    }

    /// Get the NDJSON log path for a session.
    func getNDJSONPath(for sessionId: UUID) -> URL {
        NDJSONLogger.logPath(for: sessionId, baseDirectory: ndjsonBaseDirectory)
    }

    /// List all sessions with NDJSON logs.
    func listSessionsWithLogs() throws -> [UUID] {
        try NDJSONLogger.listSessions(baseDirectory: ndjsonBaseDirectory)
    }

    /// Delete NDJSON log for a session.
    func deleteNDJSONLog(for sessionId: UUID) throws {
        try NDJSONLogger.deleteLog(for: sessionId, baseDirectory: ndjsonBaseDirectory)
    }
}

// MARK: - Event Record

private struct EventRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "events"

    let id: String
    let sessionId: String
    let sequence: Int
    let timestamp: Date
    let eventType: String
    let eventJson: String

    init(_ envelope: EventEnvelope) {
        self.id = envelope.id.uuidString
        self.sessionId = envelope.sessionId.uuidString
        self.sequence = envelope.sequence
        self.timestamp = envelope.timestamp
        self.eventType = Self.eventTypeName(envelope.event)

        let encoder = JSONEncoder()
        self.eventJson = (try? String(data: encoder.encode(envelope.event), encoding: .utf8)) ?? "{}"
    }

    func toEnvelope() -> EventEnvelope? {
        guard let event = decodeEvent() else { return nil }
        return EventEnvelope(
            sessionId: UUID(uuidString: sessionId)!,
            sequence: sequence,
            event: event
        )
    }

    private func decodeEvent() -> NormalizedEvent? {
        let decoder = JSONDecoder()
        return try? decoder.decode(NormalizedEvent.self, from: Data(eventJson.utf8))
    }

    private static func eventTypeName(_ event: NormalizedEvent) -> String {
        // Use the built-in eventType property from NormalizedEvent
        event.eventType.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case sequence
        case timestamp
        case eventType = "event_type"
        case eventJson = "event_json"
    }
}

// MARK: - JSONL Event Writer

/// Append-only JSONL writer for crash recovery.
/// Events are written immediately to disk for durability.
actor JSONLEventWriter {
    private let fileHandle: FileHandle
    private let path: String
    private let encoder: JSONEncoder

    init(path: String) throws {
        self.path = path
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // Create file if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            fileManager.createFile(atPath: path, contents: nil)
        }

        // Open for appending
        fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        try fileHandle.seekToEnd()
    }

    deinit {
        try? fileHandle.close()
    }

    /// Append an event envelope to the JSONL file
    func append(_ envelope: EventEnvelope) async throws {
        var data = try encoder.encode(envelope)
        data.append(contentsOf: "\n".utf8)
        try fileHandle.write(contentsOf: data)
        try fileHandle.synchronize()
    }

    /// Read all events from the JSONL file
    func readAll(sessionId: UUID? = nil) async throws -> [EventEnvelope] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let lines = String(data: data, encoding: .utf8)?.split(separator: "\n") ?? []
        var envelopes: [EventEnvelope] = []

        for line in lines {
            guard let envelope = try? decoder.decode(EventEnvelope.self, from: Data(line.utf8)) else {
                continue
            }
            if let sessionId, envelope.sessionId != sessionId {
                continue
            }
            envelopes.append(envelope)
        }

        return envelopes.sorted { $0.sequence < $1.sequence }
    }

    /// Truncate the JSONL file (after successful DB recovery)
    func truncate() async throws {
        try fileHandle.truncate(atOffset: 0)
    }
}
