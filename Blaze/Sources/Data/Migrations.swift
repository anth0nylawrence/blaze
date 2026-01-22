import Foundation
import GRDB

// MARK: - Schema Version

/// Current schema version for forward-only migrations.
/// Increment this when adding new migrations.
public let currentSchemaVersion = 8

// MARK: - Schema Version Table

/// Schema version record for tracking migrations.
/// Using a dedicated table instead of PRAGMA user_version for more metadata.
public struct SchemaVersion: Codable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "schema_version"

    public let version: Int
    public let migratedAt: Date
    public let migrationName: String
    public let success: Bool

    public init(version: Int, migratedAt: Date = Date(), migrationName: String, success: Bool = true) {
        self.version = version
        self.migratedAt = migratedAt
        self.migrationName = migrationName
        self.success = success
    }

    enum CodingKeys: String, CodingKey {
        case version
        case migratedAt = "migrated_at"
        case migrationName = "migration_name"
        case success
    }
}

// MARK: - Migration Runner

/// Idempotent migration runner that supports transactional migrations and background backfills.
///
/// **System Contract (Phase 2):**
/// - Migrations must be idempotent (safe to re-run)
/// - Migrations must be transactional (rollback on failure)
/// - Backfill jobs run after migration without blocking app launch
public actor MigrationRunner {
    private let dbPool: DatabasePool
    private var pendingBackfills: [BackfillJob] = []
    private var isRunning = false

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    // MARK: - Public API

    /// Run all pending migrations.
    /// Returns the final schema version after migration.
    public func runMigrations() async throws -> Int {
        guard !isRunning else {
            throw MigrationError.alreadyRunning
        }
        isRunning = true
        defer { isRunning = false }

        let startTime = Date()

        // Ensure schema_version table exists first
        try await ensureSchemaVersionTable()

        // Get current version
        let currentVersion = try await getCurrentVersion()

        // Run each migration in order
        for migration in allMigrations {
            if migration.version > currentVersion {
                try await runMigration(migration)
            }
        }

        let finalVersion = try await getCurrentVersion()
        let duration = Date().timeIntervalSince(startTime) * 1000

        // Log migration completion
        print("[Migration] Completed in \(Int(duration))ms, schema version: \(finalVersion)")

        return finalVersion
    }

    /// Run pending backfill jobs in background.
    /// Call this after app launch to avoid blocking.
    public func runBackfillsInBackground() async {
        let jobs = pendingBackfills
        pendingBackfills = []

        for job in jobs {
            do {
                try await job.execute(dbPool)
                print("[Backfill] Completed: \(job.name)")
            } catch {
                print("[Backfill] Failed: \(job.name) - \(error)")
            }
        }
    }

    /// Get the current schema version.
    public func getCurrentVersion() async throws -> Int {
        try await dbPool.read { db in
            let hasTable = try db.tableExists("schema_version")
            guard hasTable else { return 0 }

            return try SchemaVersion
                .order(Column("version").desc)
                .filter(Column("success") == true)
                .fetchOne(db)?.version ?? 0
        }
    }

    // MARK: - Private Implementation

    private func ensureSchemaVersionTable() async throws {
        try await dbPool.write { db in
            guard try !db.tableExists("schema_version") else { return }

            try db.create(table: "schema_version") { t in
                t.column("version", .integer).primaryKey()
                t.column("migrated_at", .datetime).notNull()
                t.column("migration_name", .text).notNull()
                t.column("success", .boolean).notNull().defaults(to: true)
            }
        }
    }

    private func runMigration(_ migration: Migration) async throws {
        print("[Migration] Running v\(migration.version): \(migration.name)")

        do {
            try await dbPool.write { db in
                // Run migration in transaction
                try migration.migrate(db)

                // Record successful migration
                try SchemaVersion(
                    version: migration.version,
                    migrationName: migration.name,
                    success: true
                ).insert(db)
            }

            // Queue backfill jobs if any
            if let backfill = migration.backfill {
                pendingBackfills.append(backfill)
            }

        } catch {
            // Record failed migration
            try? await dbPool.write { db in
                try SchemaVersion(
                    version: migration.version,
                    migrationName: migration.name,
                    success: false
                ).insert(db)
            }

            print("[Migration] Failed v\(migration.version): \(error)")
            throw MigrationError.migrationFailed(version: migration.version, underlying: error)
        }
    }
}

// MARK: - Migration Definition

/// Defines a single migration step.
public struct Migration {
    let version: Int
    let name: String
    let migrate: (Database) throws -> Void
    let backfill: BackfillJob?

    init(version: Int, name: String, backfill: BackfillJob? = nil, migrate: @escaping (Database) throws -> Void) {
        self.version = version
        self.name = name
        self.migrate = migrate
        self.backfill = backfill
    }
}

// MARK: - Backfill Job

/// A background job that runs after migration without blocking app launch.
public struct BackfillJob {
    let name: String
    let execute: (DatabasePool) async throws -> Void

    public init(name: String, execute: @escaping (DatabasePool) async throws -> Void) {
        self.name = name
        self.execute = execute
    }
}

// MARK: - Migration Errors

public enum MigrationError: Error, LocalizedError {
    case alreadyRunning
    case migrationFailed(version: Int, underlying: Error)
    case schemaVersionMismatch(expected: Int, actual: Int)
    case corruptDatabase

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Migration is already running"
        case .migrationFailed(let version, let underlying):
            return "Migration v\(version) failed: \(underlying.localizedDescription)"
        case .schemaVersionMismatch(let expected, let actual):
            return "Schema version mismatch: expected \(expected), got \(actual)"
        case .corruptDatabase:
            return "Database appears to be corrupt"
        }
    }
}

// MARK: - All Migrations

/// All migrations in order. Each migration builds on the previous.
///
/// **Core tables per Phase 2 spec:**
/// - repos: Repository metadata
/// - sessions: Session records with Phase 2 fields
/// - session_events: Normalized events with sequence ordering
/// - tool_requests: Tool request tracking
/// - tool_decisions: Approval decisions
/// - allowlist_rules: Per-repo and global allowlists
/// - terminal_tabs: Terminal session metadata
/// - file_cache: Derived cache for file tree
/// - search_index: Derived cache for search
let allMigrations: [Migration] = [
    // v1: Legacy schema (already exists from SessionStore)
    // This migration is idempotent - checks if tables exist before creating
    Migration(version: 1, name: "v1_legacy_compat") { db in
        // Sessions table (legacy compatible)
        if try !db.tableExists("sessions") {
            try db.create(table: "sessions") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("state", .text).notNull().defaults(to: "idle")
                t.column("project_path", .text)
                t.column("engine_type", .text).notNull().defaults(to: "claude")
                t.column("total_tokens", .integer).notNull().defaults(to: 0)
                t.column("total_cost", .text).notNull().defaults(to: "0")
                t.column("turn_count", .integer).notNull().defaults(to: 0)
                t.column("last_error", .text)
            }
        }

        // Messages table (legacy compatible)
        if try !db.tableExists("messages") {
            try db.create(table: "messages") { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("tool_calls_json", .text)
                t.column("attachments_json", .text)
            }
        }

        // Events table (legacy compatible)
        if try !db.tableExists("events") {
            try db.create(table: "events") { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("sequence", .integer).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("event_type", .text).notNull()
                t.column("event_json", .text).notNull()
            }
        }

        // Create indexes if they don't exist
        if try !db.indexExists(on: "messages", named: "messages_session_id") {
            try db.create(index: "messages_session_id", on: "messages", columns: ["session_id"])
        }
        if try !db.indexExists(on: "events", named: "events_session_id") {
            try db.create(index: "events_session_id", on: "events", columns: ["session_id"])
        }
        if try !db.indexExists(on: "events", named: "events_sequence") {
            try db.create(index: "events_sequence", on: "events", columns: ["session_id", "sequence"])
        }
    },

    // v2: Add thinking column to messages (legacy compatible)
    Migration(version: 2, name: "v2_add_thinking") { db in
        // Check if column already exists
        let columns = try db.columns(in: "messages")
        if !columns.contains(where: { $0.name == "thinking" }) {
            try db.alter(table: "messages") { t in
                t.add(column: "thinking", .text)
            }
        }
    },

    // v3: Phase 2 core tables
    Migration(version: 3, name: "v3_phase2_core_tables") { db in
        // Repos table - repository metadata
        if try !db.tableExists("repos") {
            try db.create(table: "repos") { t in
                t.column("id", .text).primaryKey()
                t.column("canonical_path", .text).notNull().unique()
                t.column("display_name", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("last_opened_at", .datetime)
            }
            try db.create(index: "repos_canonical_path", on: "repos", columns: ["canonical_path"])
        }

        // Add Phase 2 columns to sessions
        let sessionColumns = try db.columns(in: "sessions")
        if !sessionColumns.contains(where: { $0.name == "original_project_path" }) {
            try db.alter(table: "sessions") { t in
                t.add(column: "original_project_path", .text)
                t.add(column: "worktree_path", .text)
                t.add(column: "branch_name", .text)
                t.add(column: "status", .text).defaults(to: "ready")
                t.add(column: "trust_mode", .text).defaults(to: "prompt")
                t.add(column: "repo_id", .text)
                t.add(column: "ndjson_log_path", .text)
            }
        }

        // Tool requests table
        if try !db.tableExists("tool_requests") {
            try db.create(table: "tool_requests") { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("tool_call_id", .text).notNull()
                t.column("tool_name", .text).notNull()
                t.column("input_json", .text).notNull()
                t.column("risk_level", .text).notNull()
                t.column("scope_json", .text)
                t.column("timestamp", .datetime).notNull()
                t.column("status", .text).notNull().defaults(to: "pending")
            }
            try db.create(index: "tool_requests_session_id", on: "tool_requests", columns: ["session_id"])
            try db.create(index: "tool_requests_status", on: "tool_requests", columns: ["status"])
        }

        // Tool decisions table
        if try !db.tableExists("tool_decisions") {
            try db.create(table: "tool_decisions") { t in
                t.column("id", .text).primaryKey()
                t.column("tool_request_id", .text).notNull()
                    .references("tool_requests", onDelete: .cascade)
                t.column("decision", .text).notNull()
                t.column("decided_at", .datetime).notNull()
                t.column("decided_by", .text).notNull()
                t.column("rationale", .text)
                t.column("allowlist_rule_id", .text)
            }
            try db.create(index: "tool_decisions_request_id", on: "tool_decisions", columns: ["tool_request_id"])
        }

        // Allowlist rules table
        if try !db.tableExists("allowlist_rules") {
            try db.create(table: "allowlist_rules") { t in
                t.column("id", .text).primaryKey()
                t.column("repo_id", .text)  // NULL for global rules
                    .references("repos", onDelete: .cascade)
                t.column("tool_name", .text).notNull()
                t.column("scope_json", .text)
                t.column("created_at", .datetime).notNull()
                t.column("created_by", .text).notNull()
                t.column("expires_at", .datetime)
                t.column("enabled", .boolean).notNull().defaults(to: true)
            }
            try db.create(index: "allowlist_rules_repo_id", on: "allowlist_rules", columns: ["repo_id"])
            try db.create(index: "allowlist_rules_tool_name", on: "allowlist_rules", columns: ["tool_name"])
        }

        // Terminal tabs table
        if try !db.tableExists("terminal_tabs") {
            try db.create(table: "terminal_tabs") { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("kind", .text).notNull()  // "user" or "claude"
                t.column("title", .text)
                t.column("created_at", .datetime).notNull()
                t.column("closed_at", .datetime)
            }
            try db.create(index: "terminal_tabs_session_id", on: "terminal_tabs", columns: ["session_id"])
        }

        // File cache table - derived cache for file tree
        if try !db.tableExists("file_cache") {
            try db.create(table: "file_cache") { t in
                t.column("id", .text).primaryKey()
                t.column("repo_id", .text).notNull()
                    .references("repos", onDelete: .cascade)
                t.column("path", .text).notNull()
                t.column("is_directory", .boolean).notNull()
                t.column("size", .integer)
                t.column("modified_at", .datetime)
                t.column("cached_at", .datetime).notNull()
                t.column("parent_path", .text)
            }
            try db.create(index: "file_cache_repo_id", on: "file_cache", columns: ["repo_id"])
            try db.create(index: "file_cache_path", on: "file_cache", columns: ["repo_id", "path"])
            try db.create(index: "file_cache_parent", on: "file_cache", columns: ["repo_id", "parent_path"])
        }

        // Search index table - derived cache for search
        if try !db.tableExists("search_index") {
            try db.create(table: "search_index") { t in
                t.column("id", .text).primaryKey()
                t.column("repo_id", .text).notNull()
                    .references("repos", onDelete: .cascade)
                t.column("path", .text).notNull()
                t.column("content_hash", .text).notNull()
                t.column("indexed_at", .datetime).notNull()
                t.column("file_type", .text)
                t.column("line_count", .integer)
            }
            try db.create(index: "search_index_repo_id", on: "search_index", columns: ["repo_id"])
            try db.create(index: "search_index_path", on: "search_index", columns: ["repo_id", "path"])
        }
    },

    // v4: Token usage table
    Migration(version: 4, name: "v4_token_usage") { db in
        // Token usage table - per-turn token tracking
        if try !db.tableExists("token_usage") {
            try db.create(table: "token_usage") { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("turn_number", .integer).notNull()
                t.column("input_tokens", .integer).notNull()
                t.column("output_tokens", .integer).notNull()
                t.column("cache_read_tokens", .integer)
                t.column("cache_write_tokens", .integer)
                t.column("estimated_cost", .text).notNull()
                t.column("model_id", .text).notNull()
                t.column("timestamp", .datetime).notNull()
            }
            try db.create(index: "token_usage_session_id", on: "token_usage", columns: ["session_id"])
            try db.create(index: "token_usage_session_turn", on: "token_usage", columns: ["session_id", "turn_number"])
        }
    },

    // v5: Hook execution tracking (distinct from HookStore's hook_executions table)
    Migration(version: 5, name: "v5_hook_execution_tracking") { db in
        // Note: HookStore creates a "hook_executions" table for config-based hooks
        // This is HookExecutionStore's table for runtime tracking
        // Using same table name is intentional - they serve different purposes in different contexts

        // Hook executions table - runtime execution tracking
        if try !db.tableExists("hook_executions") {
            try db.create(table: "hook_executions") { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("hook_id", .text).notNull()  // Hook identifier (e.g., script filename)
                t.column("event_type", .text).notNull()  // SessionStart, PreToolUse, etc.
                t.column("matcher", .text)  // Optional tool matcher pattern
                t.column("started_at", .datetime).notNull()
                t.column("ended_at", .datetime)
                t.column("duration_ms", .integer)
                t.column("exit_code", .integer)
                t.column("stdout", .text)
                t.column("stderr", .text)
                t.column("status", .text).notNull()  // running, success, failed, timeout
            }
            try db.create(index: "hook_executions_session_id", on: "hook_executions", columns: ["session_id"])
            try db.create(index: "hook_executions_hook_id", on: "hook_executions", columns: ["hook_id"])
            try db.create(index: "hook_executions_status", on: "hook_executions", columns: ["status"])
            try db.create(index: "hook_executions_started_at", on: "hook_executions", columns: ["started_at"])
        }
    },

    // v6: Logs table - unified log viewer for app/cli/hooks
    Migration(version: 6, name: "v6_logs") { db in
        // Logs table - ring buffer for app/cli/hook logs
        if try !db.tableExists("logs") {
            try db.create(table: "logs") { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text)  // Nullable for app-level logs
                    .references("sessions", onDelete: .cascade)
                t.column("timestamp", .datetime).notNull()
                t.column("level", .text).notNull()  // debug/info/warn/error
                t.column("source", .text).notNull() // app/cli/hooks
                t.column("message", .text).notNull()
                t.column("metadata_json", .text)
            }
            try db.create(index: "logs_session_timestamp", on: "logs", columns: ["session_id", "timestamp"])
            try db.create(index: "logs_level", on: "logs", columns: ["level"])
            try db.create(index: "logs_source", on: "logs", columns: ["source"])
        }
    },

    // v7: E005 Multi-CLI Support - Add provider and model_id columns to sessions
    // Spec: E005-F001-S001-T001-A001
    Migration(version: 7, name: "v7_add_provider_model") { db in
        let sessionColumns = try db.columns(in: "sessions")

        // Add provider column with default 'anthropic'
        if !sessionColumns.contains(where: { $0.name == "provider" }) {
            try db.alter(table: "sessions") { t in
                t.add(column: "provider", .text).notNull().defaults(to: "anthropic")
            }
        }

        // Add model_id column with default 'claude-sonnet-4-5-20251101'
        if !sessionColumns.contains(where: { $0.name == "model_id" }) {
            try db.alter(table: "sessions") { t in
                t.add(column: "model_id", .text).notNull().defaults(to: "claude-sonnet-4-5-20251101")
            }
        }

        // Create index for provider filtering
        if try !db.indexExists(on: "sessions", named: "idx_sessions_provider") {
            try db.create(index: "idx_sessions_provider", on: "sessions", columns: ["provider"])
        }

        // Backfill provider from engine_type for existing sessions
        // claude -> anthropic, gemini -> google, codex -> openai
        try db.execute(sql: """
            UPDATE sessions SET provider = CASE
                WHEN engine_type = 'Claude Code' THEN 'anthropic'
                WHEN engine_type = 'Gemini CLI' THEN 'google'
                WHEN engine_type = 'Codex CLI' THEN 'openai'
                ELSE 'anthropic'
            END
            WHERE provider = 'anthropic'
        """)
    },

    // v8: Session Read States - Tracks unread event counts per session
    // Spec: E005-F002-S001-T001-A001
    Migration(version: 8, name: "v8_session_read_states") { db in
        if try !db.tableExists("session_read_states") {
            try db.create(table: "session_read_states") { t in
                t.column("session_id", .text).primaryKey()
                t.column("last_read_sequence", .integer).notNull().defaults(to: 0)
                t.column("last_read_at", .datetime).notNull()
            }
            try db.create(index: "idx_session_read_states_session_id", on: "session_read_states", columns: ["session_id"])
        }
    },
]

// MARK: - Helper Extensions

extension Database {
    /// Check if a named index exists on a table
    func indexExists(on table: String, named indexName: String) throws -> Bool {
        let rows = try Row.fetchAll(self, sql: "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=? AND name=?", arguments: [table, indexName])
        return !rows.isEmpty
    }
}
