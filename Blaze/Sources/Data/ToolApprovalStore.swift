import Foundation
import GRDB

// MARK: - Tool Approval Store

/// Persistent storage for tool approval events.
///
/// **Phase 2 System Contract:**
/// - Stores tool requests, decisions, and results
/// - Provides audit trail for all tool executions
/// - Supports querying by session, status, risk level
public actor ToolApprovalStore: ToolApprovalPipelineDelegate {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) throws {
        self.dbPool = dbPool
        try ensureTables()
    }

    // MARK: - Table Setup

    private nonisolated func ensureTables() throws {
        try dbPool.write { db in
            // Tool requests table
            guard try !db.tableExists("tool_requests") else { return }

            try db.create(table: "tool_requests") { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text)
                    .references("sessions", onDelete: .cascade)
                t.column("tool_call_id", .text).notNull()
                t.column("tool_name", .text).notNull()
                t.column("input", .text)
                t.column("risk_level", .text).notNull()
                t.column("scope_json", .text)
                t.column("timestamp", .datetime).notNull()
            }
            try db.create(index: "tool_requests_session_id", on: "tool_requests", columns: ["session_id"])
            try db.create(index: "tool_requests_timestamp", on: "tool_requests", columns: ["timestamp"])

            // Tool decisions table
            try db.create(table: "tool_decisions") { t in
                t.column("id", .text).primaryKey()
                t.column("tool_request_id", .text).notNull()
                    .references("tool_requests", onDelete: .cascade)
                t.column("decision", .text).notNull()
                t.column("decided_by", .text).notNull()
                t.column("rationale", .text)
                t.column("allowlist_rule_id", .text)
                t.column("timestamp", .datetime).notNull()
            }
            try db.create(index: "tool_decisions_request_id", on: "tool_decisions", columns: ["tool_request_id"])

            // Tool results table
            try db.create(table: "tool_results") { t in
                t.column("id", .text).primaryKey()
                t.column("tool_request_id", .text).notNull()
                    .references("tool_requests", onDelete: .cascade)
                t.column("tool_call_id", .text).notNull()
                t.column("tool_name", .text).notNull()
                t.column("output", .text)
                t.column("error", .text)
                t.column("duration_ms", .integer).notNull()
                t.column("timestamp", .datetime).notNull()
            }
            try db.create(index: "tool_results_request_id", on: "tool_results", columns: ["tool_request_id"])
        }
    }

    // MARK: - ToolApprovalPipelineDelegate

    public nonisolated func pipelineDidReceiveRequest(_ request: ToolRequestEvent) async {
        do {
            try await saveRequest(request)
        } catch {
            print("Failed to save tool request: \(error)")
        }
    }

    public nonisolated func pipelineDidRecordDecision(_ decision: ToolDecisionEvent) async {
        do {
            try await saveDecision(decision)
        } catch {
            print("Failed to save tool decision: \(error)")
        }
    }

    public nonisolated func pipelineDidRecordResult(_ result: ToolResultEvent) async {
        do {
            try await saveResult(result)
        } catch {
            print("Failed to save tool result: \(error)")
        }
    }

    // MARK: - Request Operations

    /// Save a tool request
    public func saveRequest(_ request: ToolRequestEvent, sessionId: UUID? = nil) async throws {
        try await dbPool.write { db in
            try ToolRequestRecord(request, sessionId: sessionId).insert(db)
        }
    }

    /// Get a request by ID
    public func getRequest(id: UUID) async throws -> ToolRequestEvent? {
        try await dbPool.read { db in
            try ToolRequestRecord.fetchOne(db, key: id.uuidString)?.toEvent()
        }
    }

    /// Get all pending requests (no decision yet)
    public func getPendingRequests(sessionId: UUID? = nil) async throws -> [ToolRequestEvent] {
        try await dbPool.read { db in
            var query = """
                SELECT r.* FROM tool_requests r
                LEFT JOIN tool_decisions d ON r.id = d.tool_request_id
                WHERE d.id IS NULL
            """
            if let sessionId = sessionId {
                query += " AND r.session_id = '\(sessionId.uuidString)'"
            }
            query += " ORDER BY r.timestamp DESC"

            return try ToolRequestRecord.fetchAll(db, sql: query).map { $0.toEvent() }
        }
    }

    /// Get requests for a session
    public func getRequests(sessionId: UUID, limit: Int = 100) async throws -> [ToolRequestEvent] {
        try await dbPool.read { db in
            try ToolRequestRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
                .map { $0.toEvent() }
        }
    }

    // MARK: - Decision Operations

    /// Save a tool decision
    public func saveDecision(_ decision: ToolDecisionEvent) async throws {
        try await dbPool.write { db in
            try ToolDecisionRecord(decision).insert(db)
        }
    }

    /// Get decision for a request
    public func getDecision(requestId: UUID) async throws -> ToolDecisionEvent? {
        try await dbPool.read { db in
            try ToolDecisionRecord
                .filter(Column("tool_request_id") == requestId.uuidString)
                .fetchOne(db)?
                .toEvent()
        }
    }

    // MARK: - Result Operations

    /// Save a tool result
    public func saveResult(_ result: ToolResultEvent) async throws {
        try await dbPool.write { db in
            try ToolResultRecord(result).insert(db)
        }
    }

    /// Get result for a request
    public func getResult(requestId: UUID) async throws -> ToolResultEvent? {
        try await dbPool.read { db in
            try ToolResultRecord
                .filter(Column("tool_request_id") == requestId.uuidString)
                .fetchOne(db)?
                .toEvent()
        }
    }

    // MARK: - Analytics

    /// Get tool usage stats for a session
    public func getToolStats(sessionId: UUID) async throws -> ToolUsageStats {
        try await dbPool.read { db in
            let totalRequests = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM tool_requests WHERE session_id = ?
            """, arguments: [sessionId.uuidString]) ?? 0

            let approvedCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM tool_decisions d
                JOIN tool_requests r ON d.tool_request_id = r.id
                WHERE r.session_id = ? AND d.decision = 'approved'
            """, arguments: [sessionId.uuidString]) ?? 0

            let rejectedCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM tool_decisions d
                JOIN tool_requests r ON d.tool_request_id = r.id
                WHERE r.session_id = ? AND d.decision = 'rejected'
            """, arguments: [sessionId.uuidString]) ?? 0

            let byToolName = try Row.fetchAll(db, sql: """
                SELECT tool_name, COUNT(*) as count FROM tool_requests
                WHERE session_id = ?
                GROUP BY tool_name
            """, arguments: [sessionId.uuidString]).reduce(into: [String: Int]()) { dict, row in
                if let name = row["tool_name"] as? String, let count = row["count"] as? Int {
                    dict[name] = count
                }
            }

            return ToolUsageStats(
                totalRequests: totalRequests,
                approvedCount: approvedCount,
                rejectedCount: rejectedCount,
                pendingCount: totalRequests - approvedCount - rejectedCount,
                byToolName: byToolName
            )
        }
    }
}

// MARK: - Tool Usage Stats

/// Statistics about tool usage in a session
public struct ToolUsageStats: Sendable {
    public let totalRequests: Int
    public let approvedCount: Int
    public let rejectedCount: Int
    public let pendingCount: Int
    public let byToolName: [String: Int]
}

// MARK: - Database Records

private struct ToolRequestRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tool_requests"

    let id: String
    let sessionId: String?
    let toolCallId: String
    let toolName: String
    let input: String?
    let riskLevel: String
    let scopeJson: String?
    let timestamp: Date

    init(_ event: ToolRequestEvent, sessionId: UUID? = nil) {
        self.id = event.id.uuidString
        self.sessionId = sessionId?.uuidString
        self.toolCallId = event.toolCallId
        self.toolName = event.toolName
        self.input = event.input
        self.riskLevel = event.riskLevel.rawValue
        self.scopeJson = event.scope.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
        self.timestamp = event.timestamp
    }

    func toEvent() -> ToolRequestEvent {
        ToolRequestEvent(
            id: UUID(uuidString: id)!,
            toolCallId: toolCallId,
            toolName: toolName,
            input: input ?? "",
            riskLevel: ToolRiskLevel(rawValue: riskLevel) ?? .medium,
            scope: scopeJson.flatMap { try? JSONDecoder().decode(ToolScope.self, from: Data($0.utf8)) },
            timestamp: timestamp
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case toolCallId = "tool_call_id"
        case toolName = "tool_name"
        case input
        case riskLevel = "risk_level"
        case scopeJson = "scope_json"
        case timestamp
    }
}

private struct ToolDecisionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tool_decisions"

    let id: String
    let toolRequestId: String
    let decision: String
    let decidedBy: String
    let rationale: String?
    let allowlistRuleId: String?
    let timestamp: Date

    init(_ event: ToolDecisionEvent) {
        self.id = UUID().uuidString
        self.toolRequestId = event.toolRequestId.uuidString
        self.decision = event.decision.rawValue
        self.decidedBy = event.decidedBy
        self.rationale = event.rationale
        self.allowlistRuleId = event.allowlistRuleId?.uuidString
        self.timestamp = event.timestamp
    }

    func toEvent() -> ToolDecisionEvent {
        ToolDecisionEvent(
            toolRequestId: UUID(uuidString: toolRequestId)!,
            decision: ToolDecisionType(rawValue: decision) ?? .rejected,
            decidedBy: decidedBy,
            rationale: rationale,
            allowlistRuleId: allowlistRuleId.flatMap { UUID(uuidString: $0) },
            timestamp: timestamp
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case toolRequestId = "tool_request_id"
        case decision
        case decidedBy = "decided_by"
        case rationale
        case allowlistRuleId = "allowlist_rule_id"
        case timestamp
    }
}

private struct ToolResultRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tool_results"

    let id: String
    let toolRequestId: String
    let toolCallId: String
    let toolName: String
    let output: String?
    let error: String?
    let durationMs: Int
    let timestamp: Date

    init(_ event: ToolResultEvent) {
        self.id = UUID().uuidString
        self.toolRequestId = event.toolRequestId.uuidString
        self.toolCallId = event.toolCallId
        self.toolName = event.toolName
        self.output = event.output
        self.error = event.error
        self.durationMs = event.durationMs
        self.timestamp = event.timestamp
    }

    func toEvent() -> ToolResultEvent {
        ToolResultEvent(
            toolRequestId: UUID(uuidString: toolRequestId)!,
            toolCallId: toolCallId,
            toolName: toolName,
            output: output,
            error: error,
            durationMs: durationMs,
            timestamp: timestamp
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case toolRequestId = "tool_request_id"
        case toolCallId = "tool_call_id"
        case toolName = "tool_name"
        case output
        case error
        case durationMs = "duration_ms"
        case timestamp
    }
}
