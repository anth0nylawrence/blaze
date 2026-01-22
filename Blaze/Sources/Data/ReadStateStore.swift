import Foundation
import GRDB

// MARK: - Read State Model

/// Tracks the last read sequence number for a session.
/// Used to calculate unread event counts in the session sidebar.
public struct ReadState {
    public let sessionId: UUID
    public let lastReadSequence: Int64
    public let lastReadAt: Date

    public init(sessionId: UUID, lastReadSequence: Int64, lastReadAt: Date = Date()) {
        self.sessionId = sessionId
        self.lastReadSequence = lastReadSequence
        self.lastReadAt = lastReadAt
    }
}

// MARK: - Read State Store

/// Persistent storage for session read states.
/// Tracks which events have been read per session to show unread badges.
///
/// **Phase 2 System Contract:**
/// - Uses GRDB with WAL mode for concurrent reads
/// - Schema managed via MigrationRunner (v8 migration)
/// - Actor-isolated for thread safety
actor ReadStateStore {
    private let dbPool: DatabasePool

    /// Initialize with existing database pool.
    /// Assumes migrations have already run via SessionStore.
    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    // MARK: - Public API

    /// Get the last read sequence for a session.
    /// Returns 0 if no read state exists (all events unread).
    func getLastReadSequence(sessionId: UUID) async throws -> Int64 {
        try await dbPool.read { db in
            guard let record = try ReadStateRecord.fetchOne(db, key: sessionId.uuidString) else {
                return 0
            }
            return record.lastReadSequence
        }
    }

    /// Mark all events up to (and including) the given sequence as read.
    /// Uses INSERT OR REPLACE for atomic upsert.
    func markAsRead(sessionId: UUID, sequence: Int64) async throws {
        try await dbPool.write { db in
            let record = ReadStateRecord(
                sessionId: sessionId.uuidString,
                lastReadSequence: sequence,
                lastReadAt: Date()
            )
            try record.save(db)
        }
    }

    /// Calculate unread count given total events in session.
    /// Returns max(0, totalEvents - lastReadSequence).
    func getUnreadCount(sessionId: UUID, totalEvents: Int) async throws -> Int {
        let lastRead = try await getLastReadSequence(sessionId: sessionId)
        return max(0, totalEvents - Int(lastRead))
    }

    /// Load all read states for app startup.
    /// Returns dictionary mapping sessionId to ReadState.
    func loadAllReadStates() async throws -> [UUID: ReadState] {
        try await dbPool.read { db in
            let records = try ReadStateRecord.fetchAll(db)
            var states: [UUID: ReadState] = [:]
            for record in records {
                guard let sessionId = UUID(uuidString: record.sessionId) else { continue }
                states[sessionId] = ReadState(
                    sessionId: sessionId,
                    lastReadSequence: record.lastReadSequence,
                    lastReadAt: record.lastReadAt
                )
            }
            return states
        }
    }

    /// Persist a read state to SQLite.
    /// Called by markAsRead internally; exposed for batch operations.
    func persistReadState(sessionId: UUID, sequence: Int64) async throws {
        try await markAsRead(sessionId: sessionId, sequence: sequence)
    }
}

// MARK: - Database Record

/// Private database record for session read states.
private struct ReadStateRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "session_read_states"

    let sessionId: String
    let lastReadSequence: Int64
    let lastReadAt: Date

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case lastReadSequence = "last_read_sequence"
        case lastReadAt = "last_read_at"
    }
}
