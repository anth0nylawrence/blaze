import Foundation
import GRDB

// MARK: - Hook Execution Store

/// Persistent storage for hook execution history using SQLite via GRDB.
///
/// **Purpose:**
/// - Track every hook execution: when run, duration, exit code, output
/// - Link executions to sessions for debugging
/// - Support querying by hook ID or session ID
///
/// **Distinct from HookStore:**
/// - HookStore: Hook *configurations* (from settings.json)
/// - HookExecutionStore: Hook *execution history* (runtime tracking)
actor HookExecutionStore {
    private let dbPool: DatabasePool

    /// Initialize with database pool (shared with SessionStore)
    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    // MARK: - CRUD Operations

    /// Record the start of a hook execution.
    /// Returns the execution ID for later updates.
    func recordStart(
        sessionId: UUID,
        hookId: String,
        eventType: String,
        matcher: String? = nil
    ) async throws -> UUID {
        let executionId = UUID()
        let now = Date()

        try await dbPool.write { db in
            try HookExecutionRecord(
                id: executionId.uuidString,
                sessionId: sessionId.uuidString,
                hookId: hookId,
                eventType: eventType,
                matcher: matcher,
                startedAt: now,
                endedAt: nil,
                durationMs: nil,
                exitCode: nil,
                stdout: nil,
                stderr: nil,
                status: HookExecutionStatus.running.rawValue
            ).insert(db)
        }

        return executionId
    }

    /// Record completion of a hook execution.
    /// Calculates duration and updates status based on exit code.
    func recordComplete(
        executionId: UUID,
        exitCode: Int,
        stdout: String? = nil,
        stderr: String? = nil
    ) async throws {
        try await dbPool.write { db in
            // Get the start time to calculate duration
            guard let record = try HookExecutionRecord.fetchOne(db, key: executionId.uuidString) else {
                throw HookExecutionError.executionNotFound(executionId)
            }

            let endedAt = Date()
            let durationMs = Int(endedAt.timeIntervalSince(record.startedAt) * 1000)
            let status: HookExecutionStatus = (exitCode == 0) ? .success : .failed

            try db.execute(sql: """
                UPDATE hook_executions
                SET ended_at = ?,
                    duration_ms = ?,
                    exit_code = ?,
                    stdout = ?,
                    stderr = ?,
                    status = ?
                WHERE id = ?
            """, arguments: [endedAt, durationMs, exitCode, stdout, stderr, status.rawValue, executionId.uuidString])
        }
    }

    /// Record a hook execution timeout.
    func recordTimeout(executionId: UUID) async throws {
        try await dbPool.write { db in
            guard let record = try HookExecutionRecord.fetchOne(db, key: executionId.uuidString) else {
                throw HookExecutionError.executionNotFound(executionId)
            }

            let endedAt = Date()
            let durationMs = Int(endedAt.timeIntervalSince(record.startedAt) * 1000)

            try db.execute(sql: """
                UPDATE hook_executions
                SET ended_at = ?,
                    duration_ms = ?,
                    status = ?
                WHERE id = ?
            """, arguments: [endedAt, durationMs, HookExecutionStatus.timeout.rawValue, executionId.uuidString])
        }
    }

    /// Get all executions for a session, ordered by start time (newest first)
    func getExecutions(sessionId: UUID) async throws -> [HookExecutionInfo] {
        try await dbPool.read { db in
            try HookExecutionRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .order(Column("started_at").desc)
                .fetchAll(db)
                .map { $0.toHookExecutionInfo() }
        }
    }

    /// Get all executions for a specific hook ID, ordered by start time (newest first)
    func getExecutions(hookId: String) async throws -> [HookExecutionInfo] {
        try await dbPool.read { db in
            try HookExecutionRecord
                .filter(Column("hook_id") == hookId)
                .order(Column("started_at").desc)
                .fetchAll(db)
                .map { $0.toHookExecutionInfo() }
        }
    }

    /// Get the most recent execution for a specific hook in a session
    func getLatestExecution(hookId: String, sessionId: UUID) async throws -> HookExecutionInfo? {
        try await dbPool.read { db in
            try HookExecutionRecord
                .filter(Column("hook_id") == hookId && Column("session_id") == sessionId.uuidString)
                .order(Column("started_at").desc)
                .limit(1)
                .fetchOne(db)?
                .toHookExecutionInfo()
        }
    }

    /// Clear all executions for a session (useful for cleanup)
    func clearExecutions(sessionId: UUID) async throws {
        _ = try await dbPool.write { db in
            try HookExecutionRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .deleteAll(db)
        }
    }

    /// Get execution statistics for a hook (success rate, avg duration, etc.)
    func getStatistics(hookId: String) async throws -> HookExecutionStatistics {
        try await dbPool.read { db in
            let records = try HookExecutionRecord
                .filter(Column("hook_id") == hookId)
                .filter(Column("status") != HookExecutionStatus.running.rawValue)
                .fetchAll(db)

            let totalExecutions = records.count
            let successfulExecutions = records.filter { $0.status == HookExecutionStatus.success.rawValue }.count
            let failedExecutions = records.filter { $0.status == HookExecutionStatus.failed.rawValue }.count
            let timeoutExecutions = records.filter { $0.status == HookExecutionStatus.timeout.rawValue }.count

            let durations = records.compactMap { $0.durationMs }
            let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / durations.count

            return HookExecutionStatistics(
                totalExecutions: totalExecutions,
                successfulExecutions: successfulExecutions,
                failedExecutions: failedExecutions,
                timeoutExecutions: timeoutExecutions,
                averageDurationMs: avgDuration
            )
        }
    }
}

// MARK: - Supporting Types

/// Represents a single hook execution for sidebar display
struct HookExecutionInfo: Identifiable {
    let id: UUID
    let sessionId: UUID
    let hookId: String
    let eventType: String
    let matcher: String?
    let startedAt: Date
    var endedAt: Date?
    var durationMs: Int?
    var exitCode: Int?
    var stdout: String?
    var stderr: String?
    var status: HookExecutionStatus
}

/// Hook execution status
enum HookExecutionStatus: String, Codable {
    case running
    case success
    case failed
    case timeout
}

/// Execution statistics for a hook
struct HookExecutionStatistics {
    let totalExecutions: Int
    let successfulExecutions: Int
    let failedExecutions: Int
    let timeoutExecutions: Int
    let averageDurationMs: Int

    var successRate: Double {
        guard totalExecutions > 0 else { return 0.0 }
        return Double(successfulExecutions) / Double(totalExecutions)
    }
}

// MARK: - Errors

enum HookExecutionError: Error, LocalizedError {
    case executionNotFound(UUID)
    case invalidStatus

    var errorDescription: String? {
        switch self {
        case .executionNotFound(let id):
            return "Hook execution not found: \(id)"
        case .invalidStatus:
            return "Invalid hook execution status"
        }
    }
}

// MARK: - Database Record

private struct HookExecutionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "hook_executions"

    let id: String
    let sessionId: String
    let hookId: String
    let eventType: String
    let matcher: String?
    let startedAt: Date
    var endedAt: Date?
    var durationMs: Int?
    var exitCode: Int?
    var stdout: String?
    var stderr: String?
    var status: String

    func toHookExecutionInfo() -> HookExecutionInfo {
        HookExecutionInfo(
            id: UUID(uuidString: id)!,
            sessionId: UUID(uuidString: sessionId)!,
            hookId: hookId,
            eventType: eventType,
            matcher: matcher,
            startedAt: startedAt,
            endedAt: endedAt,
            durationMs: durationMs,
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            status: HookExecutionStatus(rawValue: status) ?? .failed
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case hookId = "hook_id"
        case eventType = "event_type"
        case matcher
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMs = "duration_ms"
        case exitCode = "exit_code"
        case stdout
        case stderr
        case status
    }
}
