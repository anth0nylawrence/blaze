import Foundation
import GRDB

// MARK: - Hook Store

/// Persistent storage for automation hooks.
///
/// **Phase 2 System Contract:**
/// - Hooks can be repo-scoped or global
/// - Support for pre/post events on file operations, tool calls, etc.
/// - Execution history for debugging
public actor HookStore {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) throws {
        self.dbPool = dbPool
        try ensureTable()
    }

    // MARK: - Table Setup

    private func ensureTable() throws {
        try dbPool.write { db in
            // Hooks table
            guard try !db.tableExists("hooks") else { return }

            try db.create(table: "hooks") { t in
                t.column("id", .text).primaryKey()
                t.column("repo_id", .text)
                    .references("repos", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("event_type", .text).notNull()
                t.column("trigger_pattern", .text)  // Glob/regex for file paths or tool names
                t.column("script_path", .text)      // Path to script to execute
                t.column("inline_script", .text)    // Inline script content
                t.column("script_type", .text).notNull().defaults(to: "shell")
                t.column("enabled", .boolean).notNull().defaults(to: true)
                t.column("priority", .integer).notNull().defaults(to: 0)  // Lower = run first
                t.column("timeout_ms", .integer).notNull().defaults(to: 30000)
                t.column("run_async", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }
            try db.create(index: "hooks_repo_id", on: "hooks", columns: ["repo_id"])
            try db.create(index: "hooks_event_type", on: "hooks", columns: ["event_type"])

            // Hook executions table for history
            try db.create(table: "hook_executions") { t in
                t.column("id", .text).primaryKey()
                t.column("hook_id", .text).notNull()
                    .references("hooks", onDelete: .cascade)
                t.column("session_id", .text)
                t.column("started_at", .datetime).notNull()
                t.column("completed_at", .datetime)
                t.column("exit_code", .integer)
                t.column("stdout", .text)
                t.column("stderr", .text)
                t.column("success", .boolean)
                t.column("trigger_data_json", .text)  // JSON of trigger context
            }
            try db.create(index: "hook_executions_hook_id", on: "hook_executions", columns: ["hook_id"])
            try db.create(index: "hook_executions_session_id", on: "hook_executions", columns: ["session_id"])
        }
    }

    // MARK: - Hook CRUD

    /// Create a new hook
    public func create(_ hook: Hook) async throws {
        try await dbPool.write { db in
            try HookRecord(hook).insert(db)
        }
    }

    /// Get a hook by ID
    public func get(id: UUID) async throws -> Hook? {
        try await dbPool.read { db in
            try HookRecord.fetchOne(db, key: id.uuidString)?.toHook()
        }
    }

    /// Get all hooks for a repo (including global hooks)
    public func getHooks(repoId: UUID?) async throws -> [Hook] {
        try await dbPool.read { db in
            if let repoId = repoId {
                return try HookRecord
                    .filter(Column("repo_id") == repoId.uuidString || Column("repo_id") == nil)
                    .order(Column("priority"), Column("name"))
                    .fetchAll(db)
                    .map { $0.toHook() }
            } else {
                return try HookRecord
                    .filter(Column("repo_id") == nil)
                    .order(Column("priority"), Column("name"))
                    .fetchAll(db)
                    .map { $0.toHook() }
            }
        }
    }

    /// Get hooks for a specific event type
    public func getHooks(eventType: HookEventType, repoId: UUID? = nil) async throws -> [Hook] {
        try await dbPool.read { db in
            var query = HookRecord
                .filter(Column("event_type") == eventType.rawValue)
                .filter(Column("enabled") == true)

            if let repoId = repoId {
                query = query.filter(Column("repo_id") == repoId.uuidString || Column("repo_id") == nil)
            }

            return try query
                .order(Column("priority"), Column("name"))
                .fetchAll(db)
                .map { $0.toHook() }
        }
    }

    /// Update a hook
    public func update(_ hook: Hook) async throws {
        try await dbPool.write { db in
            try HookRecord(hook).update(db)
        }
    }

    /// Delete a hook
    public func delete(id: UUID) async throws {
        _ = try await dbPool.write { db in
            try HookRecord.deleteOne(db, key: id.uuidString)
        }
    }

    /// Toggle hook enabled state
    public func setEnabled(id: UUID, enabled: Bool) async throws {
        try await dbPool.write { db in
            try db.execute(sql: """
                UPDATE hooks SET enabled = ?, updated_at = ? WHERE id = ?
            """, arguments: [enabled, Date(), id.uuidString])
        }
    }

    // MARK: - Execution History

    /// Record a hook execution
    public func recordExecution(_ execution: HookExecution) async throws {
        try await dbPool.write { db in
            try HookExecutionRecord(execution).insert(db)
        }
    }

    /// Get recent executions for a hook
    public func getExecutions(hookId: UUID, limit: Int = 20) async throws -> [HookExecution] {
        try await dbPool.read { db in
            try HookExecutionRecord
                .filter(Column("hook_id") == hookId.uuidString)
                .order(Column("started_at").desc)
                .limit(limit)
                .fetchAll(db)
                .map { $0.toExecution() }
        }
    }

    /// Get recent executions for a session
    public func getExecutions(sessionId: UUID, limit: Int = 50) async throws -> [HookExecution] {
        try await dbPool.read { db in
            try HookExecutionRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .order(Column("started_at").desc)
                .limit(limit)
                .fetchAll(db)
                .map { $0.toExecution() }
        }
    }

    /// Prune old execution history
    public func pruneExecutions(olderThan date: Date) async throws {
        try await dbPool.write { db in
            try db.execute(sql: """
                DELETE FROM hook_executions WHERE started_at < ?
            """, arguments: [date])
        }
    }
}

// MARK: - Hook Model

/// An automation hook that runs on specific events
public struct Hook: Identifiable, Codable, Sendable {
    public let id: UUID
    public let repoId: UUID?
    public var name: String
    public var description: String?
    public var eventType: HookEventType
    public var triggerPattern: String?
    public var scriptPath: String?
    public var inlineScript: String?
    public var scriptType: HookScriptType
    public var enabled: Bool
    public var priority: Int
    public var timeoutMs: Int
    public var runAsync: Bool
    public let createdAt: Date
    public var updatedAt: Date

    /// Whether the hook has a valid script
    public var hasScript: Bool {
        (scriptPath != nil && !scriptPath!.isEmpty) || (inlineScript != nil && !inlineScript!.isEmpty)
    }

    public init(
        id: UUID = UUID(),
        repoId: UUID? = nil,
        name: String,
        description: String? = nil,
        eventType: HookEventType,
        triggerPattern: String? = nil,
        scriptPath: String? = nil,
        inlineScript: String? = nil,
        scriptType: HookScriptType = .shell,
        enabled: Bool = true,
        priority: Int = 0,
        timeoutMs: Int = 30000,
        runAsync: Bool = false
    ) {
        self.id = id
        self.repoId = repoId
        self.name = name
        self.description = description
        self.eventType = eventType
        self.triggerPattern = triggerPattern
        self.scriptPath = scriptPath
        self.inlineScript = inlineScript
        self.scriptType = scriptType
        self.enabled = enabled
        self.priority = priority
        self.timeoutMs = timeoutMs
        self.runAsync = runAsync
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Hook Event Types

/// Events that can trigger hooks
public enum HookEventType: String, Codable, CaseIterable, Sendable {
    // File events
    case preFileWrite = "pre_file_write"
    case postFileWrite = "post_file_write"
    case preFileDelete = "pre_file_delete"
    case postFileDelete = "post_file_delete"

    // Tool events
    case preToolCall = "pre_tool_call"
    case postToolCall = "post_tool_call"
    case toolApproved = "tool_approved"
    case toolRejected = "tool_rejected"

    // Session events
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case turnStart = "turn_start"
    case turnEnd = "turn_end"

    // Git events
    case preCommit = "pre_commit"
    case postCommit = "post_commit"

    public var displayName: String {
        switch self {
        case .preFileWrite: return "Before File Write"
        case .postFileWrite: return "After File Write"
        case .preFileDelete: return "Before File Delete"
        case .postFileDelete: return "After File Delete"
        case .preToolCall: return "Before Tool Call"
        case .postToolCall: return "After Tool Call"
        case .toolApproved: return "Tool Approved"
        case .toolRejected: return "Tool Rejected"
        case .sessionStart: return "Session Start"
        case .sessionEnd: return "Session End"
        case .turnStart: return "Turn Start"
        case .turnEnd: return "Turn End"
        case .preCommit: return "Before Commit"
        case .postCommit: return "After Commit"
        }
    }

    public var category: String {
        switch self {
        case .preFileWrite, .postFileWrite, .preFileDelete, .postFileDelete:
            return "File"
        case .preToolCall, .postToolCall, .toolApproved, .toolRejected:
            return "Tool"
        case .sessionStart, .sessionEnd, .turnStart, .turnEnd:
            return "Session"
        case .preCommit, .postCommit:
            return "Git"
        }
    }
}

// MARK: - Hook Script Types

/// Supported script types for hooks
public enum HookScriptType: String, Codable, CaseIterable, Sendable {
    case shell = "shell"
    case python = "python"
    case node = "node"
    case applescript = "applescript"

    public var displayName: String {
        switch self {
        case .shell: return "Shell (bash/zsh)"
        case .python: return "Python"
        case .node: return "Node.js"
        case .applescript: return "AppleScript"
        }
    }

    public var executable: String {
        switch self {
        case .shell: return "/bin/bash"
        case .python: return "/usr/bin/env python3"
        case .node: return "/usr/bin/env node"
        case .applescript: return "/usr/bin/osascript"
        }
    }
}

// MARK: - Hook Execution

/// Record of a hook execution
public struct HookExecution: Identifiable, Codable, Sendable {
    public let id: UUID
    public let hookId: UUID
    public let sessionId: UUID?
    public let startedAt: Date
    public var completedAt: Date?
    public var exitCode: Int?
    public var stdout: String?
    public var stderr: String?
    public var success: Bool?
    public var triggerData: [String: String]?

    public var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(startedAt)
    }

    public init(
        id: UUID = UUID(),
        hookId: UUID,
        sessionId: UUID? = nil,
        triggerData: [String: String]? = nil
    ) {
        self.id = id
        self.hookId = hookId
        self.sessionId = sessionId
        self.startedAt = Date()
        self.triggerData = triggerData
    }
}

// MARK: - Database Records

private struct HookRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "hooks"

    let id: String
    let repoId: String?
    var name: String
    var description: String?
    var eventType: String
    var triggerPattern: String?
    var scriptPath: String?
    var inlineScript: String?
    var scriptType: String
    var enabled: Bool
    var priority: Int
    var timeoutMs: Int
    var runAsync: Bool
    let createdAt: Date
    var updatedAt: Date

    init(_ hook: Hook) {
        self.id = hook.id.uuidString
        self.repoId = hook.repoId?.uuidString
        self.name = hook.name
        self.description = hook.description
        self.eventType = hook.eventType.rawValue
        self.triggerPattern = hook.triggerPattern
        self.scriptPath = hook.scriptPath
        self.inlineScript = hook.inlineScript
        self.scriptType = hook.scriptType.rawValue
        self.enabled = hook.enabled
        self.priority = hook.priority
        self.timeoutMs = hook.timeoutMs
        self.runAsync = hook.runAsync
        self.createdAt = hook.createdAt
        self.updatedAt = hook.updatedAt
    }

    func toHook() -> Hook {
        var hook = Hook(
            id: UUID(uuidString: id)!,
            repoId: repoId.flatMap { UUID(uuidString: $0) },
            name: name,
            description: description,
            eventType: HookEventType(rawValue: eventType) ?? .postToolCall,
            triggerPattern: triggerPattern,
            scriptPath: scriptPath,
            inlineScript: inlineScript,
            scriptType: HookScriptType(rawValue: scriptType) ?? .shell,
            enabled: enabled,
            priority: priority,
            timeoutMs: timeoutMs,
            runAsync: runAsync
        )
        hook.updatedAt = updatedAt
        return hook
    }

    enum CodingKeys: String, CodingKey {
        case id
        case repoId = "repo_id"
        case name
        case description
        case eventType = "event_type"
        case triggerPattern = "trigger_pattern"
        case scriptPath = "script_path"
        case inlineScript = "inline_script"
        case scriptType = "script_type"
        case enabled
        case priority
        case timeoutMs = "timeout_ms"
        case runAsync = "run_async"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct HookExecutionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "hook_executions"

    let id: String
    let hookId: String
    let sessionId: String?
    let startedAt: Date
    var completedAt: Date?
    var exitCode: Int?
    var stdout: String?
    var stderr: String?
    var success: Bool?
    var triggerDataJson: String?

    init(_ execution: HookExecution) {
        self.id = execution.id.uuidString
        self.hookId = execution.hookId.uuidString
        self.sessionId = execution.sessionId?.uuidString
        self.startedAt = execution.startedAt
        self.completedAt = execution.completedAt
        self.exitCode = execution.exitCode
        self.stdout = execution.stdout
        self.stderr = execution.stderr
        self.success = execution.success
        self.triggerDataJson = execution.triggerData.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
    }

    func toExecution() -> HookExecution {
        var exec = HookExecution(
            id: UUID(uuidString: id)!,
            hookId: UUID(uuidString: hookId)!,
            sessionId: sessionId.flatMap { UUID(uuidString: $0) },
            triggerData: triggerDataJson.flatMap { try? JSONDecoder().decode([String: String].self, from: Data($0.utf8)) }
        )
        exec.completedAt = completedAt
        exec.exitCode = exitCode
        exec.stdout = stdout
        exec.stderr = stderr
        exec.success = success
        return exec
    }

    enum CodingKeys: String, CodingKey {
        case id
        case hookId = "hook_id"
        case sessionId = "session_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case exitCode = "exit_code"
        case stdout
        case stderr
        case success
        case triggerDataJson = "trigger_data_json"
    }
}
