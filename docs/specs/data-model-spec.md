# Cogit0 Blaze - Data Model Specification

**Version:** 1.0.0
**Last Updated:** 2025-12-25
**Status:** Draft

---

## Executive Summary

This document specifies the data model for Cogit0 Blaze, using **LanceDB** as the primary storage engine. LanceDB provides:

- **Vector-native storage** for semantic search and embeddings
- **Columnar format** (Lance) for efficient analytical queries
- **Zero-copy access** for high-performance reads
- **Embedded mode** - no separate server process required
- **Native Swift/Rust bindings** via FFI

---

## Table of Contents

1. [Storage Architecture](#1-storage-architecture)
2. [Entity-Relationship Diagram](#2-entity-relationship-diagram)
3. [Table Schemas](#3-table-schemas)
4. [Index Strategy](#4-index-strategy)
5. [Migration Strategy](#5-migration-strategy)
6. [Query Patterns](#6-query-patterns)
7. [Backup & Recovery](#7-backup--recovery)
8. [Performance Considerations](#8-performance-considerations)

---

## 1. Storage Architecture

### 1.1 Storage Layout

```
~/.cogit0-blaze/
├── db/
│   └── blaze.lance/              # Main LanceDB database
│       ├── sessions.lance/       # Session table
│       ├── events.lance/         # Event log table
│       ├── projects.lance/       # Project configurations
│       ├── diffs.lance/          # File diff storage
│       ├── policies.lance/       # Security policies
│       ├── approvals.lance/      # Approval decisions
│       ├── hooks.lance/          # Hook configurations
│       ├── branches.lance/       # Conversation branches
│       └── _versions/            # Version metadata
├── events/
│   └── <session_id>.jsonl        # Append-only event journal (crash recovery)
├── cache/
│   └── embeddings/               # Cached embedding vectors
└── exports/
    └── <export_id>/              # Exported session bundles
```

### 1.2 Hybrid Storage Strategy

| Data Type | Primary Storage | Secondary Storage | Rationale |
|-----------|-----------------|-------------------|-----------|
| Structured data | LanceDB | - | Queryable, indexed |
| Event stream | JSONL (append) | LanceDB (async) | Crash-safe writes |
| Embeddings | LanceDB | - | Vector-native |
| Large diffs | LanceDB | Compressed files | Balance size/speed |
| Binary assets | File system | References in DB | Avoid DB bloat |

### 1.3 LanceDB Configuration

```swift
struct LanceDBConfig {
    let path: URL                           // ~/.cogit0-blaze/db/blaze.lance
    let cacheSize: UInt64 = 256 * 1024 * 1024  // 256 MB read cache
    let writeBufferSize: UInt64 = 64 * 1024 * 1024  // 64 MB write buffer
    let compressionCodec: String = "zstd"   // Compression for cold data
    let vectorIndexType: String = "IVF_PQ"  // Index type for embeddings
    let numPartitions: Int = 256            // IVF partitions
    let numSubVectors: Int = 96             // PQ sub-vectors
}
```

---

## 2. Entity-Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           COGIT0 BLAZE DATA MODEL                                │
└─────────────────────────────────────────────────────────────────────────────────┘

┌──────────────┐       1:N       ┌──────────────┐       1:N       ┌──────────────┐
│   Project    │────────────────▶│   Session    │────────────────▶│    Event     │
│──────────────│                 │──────────────│                 │──────────────│
│ id           │                 │ id           │                 │ id           │
│ path         │                 │ project_id   │◀────────────────│ session_id   │
│ name         │                 │ engine_id    │                 │ sequence     │
│ trust_level  │                 │ name         │                 │ timestamp    │
│ created_at   │                 │ parent_id    │─┐ (branching)   │ event_type   │
│ settings     │                 │ branch_point │ │               │ source       │
│ policy_ids[] │─┐               │ created_at   │ │               │ payload      │
└──────────────┘ │               │ last_used_at │ │               │ embedding[]  │
                 │               │ state        │ │               └──────────────┘
                 │               │ metadata     │ │                      │
                 │               └──────────────┘ │                      │
                 │                      ▲         │                      │ 1:N
                 │                      └─────────┘                      ▼
                 │                                                ┌──────────────┐
                 │               ┌──────────────┐                 │    Diff      │
                 │               │   Branch     │                 │──────────────│
                 │               │──────────────│                 │ id           │
                 │               │ id           │                 │ event_id     │
                 │               │ session_id   │                 │ file_path    │
                 │               │ parent_id    │                 │ before_hash  │
                 │               │ branch_point │                 │ after_hash   │
                 │               │ name         │                 │ unified_diff │
                 │               │ created_at   │                 │ stats        │
                 │               │ status       │                 │ decision     │
                 │               └──────────────┘                 │ decided_at   │
                 │                                                └──────────────┘
                 │
                 ▼
┌──────────────┐       N:M       ┌──────────────┐
│   Policy     │◀───────────────▶│  Approval    │
│──────────────│                 │──────────────│
│ id           │                 │ id           │
│ name         │                 │ session_id   │
│ scope        │                 │ event_id     │
│ rules[]      │                 │ policy_id    │
│ enabled      │                 │ decision     │
│ created_at   │                 │ scope        │
│ updated_at   │                 │ created_at   │
└──────────────┘                 │ expires_at   │
                                 └──────────────┘


┌──────────────┐                 ┌──────────────┐
│    Hook      │                 │  ToolCall    │
│──────────────│                 │──────────────│
│ id           │                 │ id           │
│ name         │                 │ event_id     │
│ event_type   │                 │ tool_name    │
│ script_path  │                 │ input        │
│ timeout_ms   │                 │ output       │
│ enabled      │                 │ success      │
│ permissions  │                 │ duration_ms  │
│ created_at   │                 │ stderr       │
└──────────────┘                 └──────────────┘


┌──────────────┐                 ┌──────────────┐
│  Analytics   │                 │   Engine     │
│──────────────│                 │──────────────│
│ id           │                 │ id           │
│ session_id   │                 │ name         │
│ tokens_in    │                 │ cli_path     │
│ tokens_out   │                 │ version      │
│ tokens_cache │                 │ capabilities │
│ cost_usd     │                 │ auth_state   │
│ latency_ms   │                 │ last_checked │
│ tool_calls   │                 └──────────────┘
│ timestamp    │
└──────────────┘
```

### 2.1 Relationship Summary

| Parent | Child | Cardinality | On Delete |
|--------|-------|-------------|-----------|
| Project | Session | 1:N | Cascade |
| Session | Event | 1:N | Cascade |
| Session | Branch | 1:N | Cascade |
| Session | Session (branch) | 1:N | Set Null |
| Event | Diff | 1:N | Cascade |
| Event | ToolCall | 1:1 | Cascade |
| Event | Approval | 1:N | Cascade |
| Policy | Project | N:M | Detach |
| Session | Analytics | 1:N | Cascade |

---

## 3. Table Schemas

### 3.1 Projects Table

```python
# LanceDB Schema (PyArrow-compatible)
projects_schema = pa.schema([
    pa.field("id", pa.string(), nullable=False),           # UUID
    pa.field("path", pa.string(), nullable=False),         # Absolute path to project
    pa.field("name", pa.string(), nullable=False),         # Display name
    pa.field("trust_level", pa.string(), nullable=False),  # "review" | "trusted" | "sandbox"
    pa.field("created_at", pa.timestamp("us"), nullable=False),
    pa.field("updated_at", pa.timestamp("us"), nullable=False),
    pa.field("last_session_at", pa.timestamp("us"), nullable=True),
    pa.field("settings", pa.string(), nullable=False),     # JSON blob
    pa.field("policy_ids", pa.list_(pa.string())),         # Array of policy UUIDs
    pa.field("metadata", pa.string(), nullable=True),      # JSON blob for extensibility
])
```

**Swift Model:**

```swift
struct Project: Codable, Identifiable {
    let id: UUID
    var path: URL
    var name: String
    var trustLevel: TrustLevel
    let createdAt: Date
    var updatedAt: Date
    var lastSessionAt: Date?
    var settings: ProjectSettings
    var policyIds: [UUID]
    var metadata: [String: AnyCodable]?

    enum TrustLevel: String, Codable {
        case review     // Default: risky ops gated
        case trusted    // Minimal gates
        case sandbox    // Read-only
    }
}

struct ProjectSettings: Codable {
    var defaultEngine: EngineId?
    var autoSaveInterval: TimeInterval
    var maxSessionHistory: Int
    var environmentVariables: [String: String]
    var excludePatterns: [String]   // Glob patterns for ignored files
}
```

### 3.2 Sessions Table

```python
sessions_schema = pa.schema([
    pa.field("id", pa.string(), nullable=False),           # UUID
    pa.field("project_id", pa.string(), nullable=False),   # FK to projects
    pa.field("engine_id", pa.string(), nullable=False),    # "claude" | "gemini" | "codex"
    pa.field("name", pa.string(), nullable=False),         # User-defined or auto-generated
    pa.field("parent_id", pa.string(), nullable=True),     # For branched sessions
    pa.field("branch_point", pa.int64(), nullable=True),   # Event sequence where branched
    pa.field("branch_name", pa.string(), nullable=True),   # Optional branch label
    pa.field("state", pa.string(), nullable=False),        # "active" | "idle" | "archived"
    pa.field("created_at", pa.timestamp("us"), nullable=False),
    pa.field("last_used_at", pa.timestamp("us"), nullable=False),
    pa.field("turn_count", pa.int32(), nullable=False),
    pa.field("total_tokens", pa.int64(), nullable=False),
    pa.field("total_cost_usd", pa.float64(), nullable=True),
    pa.field("metadata", pa.string(), nullable=True),      # JSON blob
    pa.field("summary", pa.string(), nullable=True),       # Auto-generated summary
    pa.field("summary_embedding", pa.list_(pa.float32(), 1536), nullable=True),  # For search
])
```

**Swift Model:**

```swift
struct Session: Codable, Identifiable {
    let id: UUID
    let projectId: UUID
    let engineId: EngineId
    var name: String

    // Branching support
    let parentId: UUID?
    let branchPoint: Int?          // Event sequence number
    var branchName: String?

    var state: SessionState
    let createdAt: Date
    var lastUsedAt: Date
    var turnCount: Int
    var totalTokens: Int64
    var totalCostUSD: Double?
    var metadata: [String: AnyCodable]?
    var summary: String?
    var summaryEmbedding: [Float]?

    enum SessionState: String, Codable {
        case active
        case idle
        case archived
    }

    /// Returns all ancestor session IDs (for branch history)
    func ancestorChain(using store: SessionStore) async -> [UUID] {
        var chain: [UUID] = []
        var current = self
        while let parentId = current.parentId,
              let parent = await store.session(id: parentId) {
            chain.append(parentId)
            current = parent
        }
        return chain.reversed()
    }
}
```

### 3.3 Events Table

```python
events_schema = pa.schema([
    pa.field("id", pa.string(), nullable=False),           # UUID
    pa.field("session_id", pa.string(), nullable=False),   # FK to sessions
    pa.field("sequence", pa.int64(), nullable=False),      # Monotonic within session
    pa.field("timestamp", pa.timestamp("us"), nullable=False),
    pa.field("event_type", pa.string(), nullable=False),   # Discriminator
    pa.field("source", pa.string(), nullable=False),       # "engine" | "hook" | "user" | "system"
    pa.field("payload", pa.string(), nullable=False),      # JSON blob of event data
    pa.field("parent_event_id", pa.string(), nullable=True),  # For tool call grouping
    pa.field("duration_ms", pa.int64(), nullable=True),
    pa.field("embedding", pa.list_(pa.float32(), 1536), nullable=True),  # For semantic search
    pa.field("tags", pa.list_(pa.string()), nullable=True),
])
```

**Swift Model:**

```swift
struct EventEnvelope: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let sequence: Int64
    let timestamp: Date
    let eventType: String           // Matches NormalizedEvent case
    let source: EventSource
    let payload: NormalizedEvent    // The actual typed event
    let parentEventId: UUID?
    let durationMs: Int64?
    var embedding: [Float]?
    var tags: [String]?
}

enum EventSource: String, Codable {
    case engine     // From CLI process
    case hook       // From user hooks
    case user       // User actions
    case system     // App-generated
}
```

### 3.4 Diffs Table

```python
diffs_schema = pa.schema([
    pa.field("id", pa.string(), nullable=False),
    pa.field("event_id", pa.string(), nullable=False),     # FK to events
    pa.field("session_id", pa.string(), nullable=False),   # Denormalized for queries
    pa.field("file_path", pa.string(), nullable=False),    # Relative to project root
    pa.field("before_hash", pa.string(), nullable=True),   # SHA-256 of original
    pa.field("after_hash", pa.string(), nullable=True),    # SHA-256 of modified
    pa.field("unified_diff", pa.large_string(), nullable=False),  # Full diff text
    pa.field("lines_added", pa.int32(), nullable=False),
    pa.field("lines_removed", pa.int32(), nullable=False),
    pa.field("hunks_count", pa.int32(), nullable=False),
    pa.field("decision", pa.string(), nullable=True),      # "accepted" | "rejected" | "pending"
    pa.field("decided_at", pa.timestamp("us"), nullable=True),
    pa.field("decided_by", pa.string(), nullable=True),    # "user" | "policy" | "hook"
    pa.field("change_set_id", pa.string(), nullable=True), # Group related diffs
    pa.field("created_at", pa.timestamp("us"), nullable=False),
])
```

**Swift Model:**

```swift
struct FileDiff: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let sessionId: UUID
    let filePath: String
    let beforeHash: String?
    let afterHash: String?
    let unifiedDiff: String
    let linesAdded: Int
    let linesRemoved: Int
    let hunksCount: Int
    var decision: DiffDecision?
    var decidedAt: Date?
    var decidedBy: DiffDecider?
    var changeSetId: UUID?          // For batch review
    let createdAt: Date

    enum DiffDecision: String, Codable {
        case accepted
        case rejected
        case pending
        case partial     // Some hunks accepted
    }

    enum DiffDecider: String, Codable {
        case user
        case policy
        case hook
        case autoAccept
    }
}
```

### 3.5 Policies Table

```python
policies_schema = pa.schema([
    pa.field("id", pa.string(), nullable=False),
    pa.field("name", pa.string(), nullable=False),
    pa.field("description", pa.string(), nullable=True),
    pa.field("scope", pa.string(), nullable=False),        # "global" | "project" | "session"
    pa.field("rules", pa.string(), nullable=False),        # JSON array of rules
    pa.field("enabled", pa.bool_(), nullable=False),
    pa.field("priority", pa.int32(), nullable=False),      # Lower = higher priority
    pa.field("version", pa.int32(), nullable=False),       # For updates
    pa.field("created_at", pa.timestamp("us"), nullable=False),
    pa.field("updated_at", pa.timestamp("us"), nullable=False),
    pa.field("author", pa.string(), nullable=True),        # For shared policies
    pa.field("signature", pa.string(), nullable=True),     # For verification
])
```

### 3.6 Branches Table

```python
branches_schema = pa.schema([
    pa.field("id", pa.string(), nullable=False),
    pa.field("session_id", pa.string(), nullable=False),   # Original session
    pa.field("forked_session_id", pa.string(), nullable=False),  # New branched session
    pa.field("parent_branch_id", pa.string(), nullable=True),    # For nested branches
    pa.field("branch_point", pa.int64(), nullable=False),  # Event sequence
    pa.field("name", pa.string(), nullable=True),          # User label
    pa.field("description", pa.string(), nullable=True),
    pa.field("status", pa.string(), nullable=False),       # "active" | "merged" | "abandoned"
    pa.field("created_at", pa.timestamp("us"), nullable=False),
    pa.field("merged_at", pa.timestamp("us"), nullable=True),
    pa.field("merged_into", pa.string(), nullable=True),   # Session ID merged into
])
```

### 3.7 Analytics Table

```python
analytics_schema = pa.schema([
    pa.field("id", pa.string(), nullable=False),
    pa.field("session_id", pa.string(), nullable=False),
    pa.field("timestamp", pa.timestamp("us"), nullable=False),
    pa.field("turn_number", pa.int32(), nullable=False),
    pa.field("tokens_input", pa.int64(), nullable=False),
    pa.field("tokens_output", pa.int64(), nullable=False),
    pa.field("tokens_cached", pa.int64(), nullable=True),
    pa.field("cost_usd", pa.float64(), nullable=True),
    pa.field("latency_first_token_ms", pa.int64(), nullable=True),
    pa.field("latency_total_ms", pa.int64(), nullable=False),
    pa.field("tool_calls", pa.int32(), nullable=False),
    pa.field("tool_successes", pa.int32(), nullable=False),
    pa.field("tool_failures", pa.int32(), nullable=False),
    pa.field("diffs_produced", pa.int32(), nullable=False),
    pa.field("diffs_accepted", pa.int32(), nullable=False),
    pa.field("diffs_rejected", pa.int32(), nullable=False),
    pa.field("model", pa.string(), nullable=True),
    pa.field("engine_version", pa.string(), nullable=True),
])
```

### 3.8 Engines Table

```python
engines_schema = pa.schema([
    pa.field("id", pa.string(), nullable=False),           # "claude" | "gemini" | "codex"
    pa.field("display_name", pa.string(), nullable=False),
    pa.field("cli_path", pa.string(), nullable=True),      # Resolved path to CLI
    pa.field("version", pa.string(), nullable=True),
    pa.field("min_supported_version", pa.string(), nullable=False),
    pa.field("capabilities", pa.string(), nullable=False), # JSON blob
    pa.field("auth_state", pa.string(), nullable=False),   # "authenticated" | "unauthenticated" | "unknown"
    pa.field("last_checked_at", pa.timestamp("us"), nullable=True),
    pa.field("settings", pa.string(), nullable=True),      # Engine-specific settings
])
```

---

## 4. Index Strategy

### 4.1 Primary Indexes (B-Tree)

| Table | Column(s) | Index Type | Purpose |
|-------|-----------|------------|---------|
| sessions | id | Primary | Unique lookup |
| sessions | project_id, last_used_at DESC | Composite | Session list |
| sessions | parent_id | B-Tree | Branch navigation |
| events | session_id, sequence | Composite | Event replay |
| events | timestamp | B-Tree | Time-based queries |
| events | event_type | B-Tree | Filter by type |
| diffs | session_id, decision | Composite | Pending diffs |
| diffs | change_set_id | B-Tree | Batch operations |
| policies | scope, enabled | Composite | Policy evaluation |
| branches | session_id | B-Tree | Branch lookup |
| analytics | session_id, timestamp | Composite | Usage graphs |

### 4.2 Vector Indexes (IVF_PQ)

| Table | Column | Dimensions | Purpose |
|-------|--------|------------|---------|
| sessions | summary_embedding | 1536 | Semantic session search |
| events | embedding | 1536 | Semantic event search |

**Vector Index Configuration:**

```swift
struct VectorIndexConfig {
    let metric: DistanceMetric = .cosine
    let numPartitions: Int = 256        // IVF partitions
    let numSubVectors: Int = 96         // PQ sub-vectors
    let numProbes: Int = 20             // Search probes (accuracy vs speed)
    let refineK: Int = 50               // Re-rank top K
}
```

### 4.3 Full-Text Search

LanceDB supports full-text search via Tantivy integration:

```python
# Create FTS index on session names and summaries
sessions_table.create_fts_index(["name", "summary"])

# Create FTS index on event payloads
events_table.create_fts_index(["payload"])
```

---

## 5. Migration Strategy

### 5.1 Version Tracking

```python
schema_versions_schema = pa.schema([
    pa.field("table_name", pa.string(), nullable=False),
    pa.field("version", pa.int32(), nullable=False),
    pa.field("applied_at", pa.timestamp("us"), nullable=False),
    pa.field("migration_id", pa.string(), nullable=False),   # e.g., "2025_01_15_add_branches"
    pa.field("checksum", pa.string(), nullable=False),       # Schema hash
])
```

### 5.2 Migration Process

```swift
protocol Migration {
    var id: String { get }           // e.g., "2025_01_15_add_branches"
    var version: Int { get }
    var description: String { get }

    func up(db: LanceDatabase) async throws
    func down(db: LanceDatabase) async throws
    func validate(db: LanceDatabase) async throws -> Bool
}

class MigrationRunner {
    func migrate(to targetVersion: Int? = nil) async throws {
        let current = try await getCurrentVersion()
        let pending = migrations.filter { $0.version > current }
                                .sorted { $0.version < $1.version }

        for migration in pending {
            if let target = targetVersion, migration.version > target {
                break
            }

            try await db.transaction {
                try await migration.up(db: db)
                try await recordMigration(migration)
            }

            guard try await migration.validate(db: db) else {
                throw MigrationError.validationFailed(migration.id)
            }
        }
    }
}
```

### 5.3 Migration Examples

```swift
// Example: Adding branches support
struct AddBranchesMigration: Migration {
    let id = "2025_01_15_add_branches"
    let version = 2
    let description = "Add conversation branching support"

    func up(db: LanceDatabase) async throws {
        // 1. Create branches table
        try await db.createTable("branches", schema: branches_schema)

        // 2. Add columns to sessions
        try await db.alterTable("sessions") {
            $0.addColumn("parent_id", type: .string, nullable: true)
            $0.addColumn("branch_point", type: .int64, nullable: true)
            $0.addColumn("branch_name", type: .string, nullable: true)
        }

        // 3. Create indexes
        try await db.createIndex("branches", columns: ["session_id"])
        try await db.createIndex("sessions", columns: ["parent_id"])
    }

    func down(db: LanceDatabase) async throws {
        try await db.dropTable("branches")
        try await db.alterTable("sessions") {
            $0.dropColumn("parent_id")
            $0.dropColumn("branch_point")
            $0.dropColumn("branch_name")
        }
    }

    func validate(db: LanceDatabase) async throws -> Bool {
        let hasBranches = try await db.tableExists("branches")
        let hasParentId = try await db.columnExists("sessions", "parent_id")
        return hasBranches && hasParentId
    }
}
```

### 5.4 Schema Evolution Rules

| Change Type | Strategy | Example |
|-------------|----------|---------|
| Add nullable column | ALTER + default | Add `summary` to sessions |
| Add required column | Migration with backfill | Add `sequence` to events |
| Remove column | Mark deprecated, remove later | Remove unused `legacy_id` |
| Rename column | Add new, migrate, remove old | `path` → `file_path` |
| Change type | Add new column, migrate, swap | `cost` int → float |
| Add table | CREATE | Add `branches` table |
| Add index | CREATE INDEX | Add vector index |

---

## 6. Query Patterns

### 6.1 Common Queries

**List sessions for project:**
```swift
func sessions(for projectId: UUID, limit: Int = 50) async throws -> [Session] {
    try await db.table("sessions")
        .filter("project_id = ?", [projectId.uuidString])
        .filter("state != 'archived'")
        .orderBy("last_used_at", ascending: false)
        .limit(limit)
        .execute()
}
```

**Get events for session replay:**
```swift
func events(for sessionId: UUID, after sequence: Int64 = 0) async throws -> [EventEnvelope] {
    try await db.table("events")
        .filter("session_id = ?", [sessionId.uuidString])
        .filter("sequence > ?", [sequence])
        .orderBy("sequence", ascending: true)
        .execute()
}
```

**Semantic search across sessions:**
```swift
func searchSessions(query: String, embedding: [Float], limit: Int = 10) async throws -> [Session] {
    try await db.table("sessions")
        .search(embedding, column: "summary_embedding")
        .filter("state != 'archived'")
        .limit(limit)
        .execute()
}
```

**Get pending diffs for review:**
```swift
func pendingDiffs(for sessionId: UUID) async throws -> [FileDiff] {
    try await db.table("diffs")
        .filter("session_id = ?", [sessionId.uuidString])
        .filter("decision IS NULL OR decision = 'pending'")
        .orderBy("created_at", ascending: true)
        .execute()
}
```

**Branch tree for session:**
```swift
func branchTree(for sessionId: UUID) async throws -> [Branch] {
    // Get all branches where this session is in the ancestry
    try await db.table("branches")
        .filter("session_id = ? OR forked_session_id = ?",
                [sessionId.uuidString, sessionId.uuidString])
        .orderBy("created_at", ascending: true)
        .execute()
}
```

### 6.2 Analytics Queries

**Token usage over time:**
```swift
func tokenUsage(for projectId: UUID, days: Int = 30) async throws -> [DailyUsage] {
    let cutoff = Date().addingTimeInterval(-Double(days * 86400))

    return try await db.query("""
        SELECT
            DATE(timestamp) as date,
            SUM(tokens_input) as input,
            SUM(tokens_output) as output,
            SUM(tokens_cached) as cached,
            SUM(cost_usd) as cost
        FROM analytics a
        JOIN sessions s ON a.session_id = s.id
        WHERE s.project_id = ?
          AND a.timestamp >= ?
        GROUP BY DATE(timestamp)
        ORDER BY date
    """, params: [projectId.uuidString, cutoff])
}
```

---

## 7. Backup & Recovery

### 7.1 Backup Strategy

```swift
class BackupManager {
    /// Full backup of LanceDB
    func fullBackup(to destination: URL) async throws {
        // LanceDB uses immutable files, so copy is safe
        try await db.checkpoint()  // Flush write buffer
        try FileManager.default.copyItem(at: dbPath, to: destination)
    }

    /// Incremental backup using Lance versioning
    func incrementalBackup(since version: Int64, to destination: URL) async throws {
        let changes = try await db.changesSince(version: version)
        try await changes.export(to: destination)
    }

    /// Export single session as portable bundle
    func exportSession(_ sessionId: UUID, to destination: URL) async throws -> SessionBundle {
        let session = try await getSession(sessionId)
        let events = try await getEvents(for: sessionId)
        let diffs = try await getDiffs(for: sessionId)
        let branches = try await getBranches(for: sessionId)

        return SessionBundle(
            session: session,
            events: events,
            diffs: diffs,
            branches: branches,
            exportedAt: Date(),
            blazeVersion: AppVersion.current
        )
    }
}
```

### 7.2 Crash Recovery

The JSONL event journal provides crash safety:

```swift
class EventJournal {
    /// Append event to journal (sync write)
    func append(_ event: EventEnvelope) throws {
        let line = try encoder.encode(event) + "\n"
        try fileHandle.write(contentsOf: line)
        try fileHandle.synchronize()  // fsync
    }

    /// Recover events from journal to LanceDB
    func recover(session sessionId: UUID) async throws -> Int {
        let journalPath = eventsDir.appendingPathComponent("\(sessionId).jsonl")
        guard FileManager.default.fileExists(atPath: journalPath.path) else {
            return 0
        }

        let lastSequence = try await db.lastEventSequence(for: sessionId)
        var recovered = 0

        for try await line in journalPath.lines {
            let event = try decoder.decode(EventEnvelope.self, from: line)
            if event.sequence > lastSequence {
                try await db.insert("events", event)
                recovered += 1
            }
        }

        return recovered
    }
}
```

---

## 8. Performance Considerations

### 8.1 Capacity Planning

| Metric | Typical | Heavy Use | Maximum |
|--------|---------|-----------|---------|
| Sessions/project | 50 | 500 | 10,000 |
| Events/session | 100 | 1,000 | 50,000 |
| Diffs/session | 20 | 200 | 5,000 |
| DB size/project | 50 MB | 500 MB | 5 GB |
| Total DB size | 500 MB | 5 GB | 50 GB |

### 8.2 Performance Targets

| Operation | Target | Critical |
|-----------|--------|----------|
| Session list load | < 50ms | < 200ms |
| Event stream (1000 events) | < 100ms | < 500ms |
| Semantic search (10 results) | < 200ms | < 1s |
| Full-text search | < 100ms | < 500ms |
| Diff render (10KB) | < 50ms | < 200ms |
| Insert event | < 5ms | < 20ms |

### 8.3 Optimization Strategies

| Strategy | When to Apply |
|----------|---------------|
| Lazy loading | Event payloads, large diffs |
| Pagination | Session lists > 100, event lists > 1000 |
| Caching | Frequently accessed sessions, embeddings |
| Background indexing | Vector index updates, FTS rebuilds |
| Compaction | After large batch operations |
| Partitioning | By project for >1000 projects |

### 8.4 Monitoring Queries

```swift
// Database health check
func healthCheck() async throws -> DatabaseHealth {
    let tableStats = try await db.tableStats()
    let indexStats = try await db.indexStats()
    let fragmentationRatio = try await db.fragmentationRatio()

    return DatabaseHealth(
        totalSize: tableStats.totalBytes,
        tableCount: tableStats.count,
        indexHealth: indexStats.allHealthy,
        fragmentationRatio: fragmentationRatio,
        needsCompaction: fragmentationRatio > 0.3
    )
}
```

---

## Appendix A: LanceDB Swift Bindings

```swift
// Thin Swift wrapper over LanceDB Rust FFI
class LanceDatabase {
    private let handle: OpaquePointer

    init(path: URL) throws {
        self.handle = try lance_db_open(path.path)
    }

    func table(_ name: String) -> LanceTable {
        LanceTable(db: self, name: name)
    }

    func createTable(_ name: String, schema: Schema) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lance_db_create_table(handle, name, schema.toArrow()) { error in
                if let error = error {
                    continuation.resume(throwing: LanceError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func transaction<T>(_ block: () async throws -> T) async throws -> T {
        try await lance_db_begin_transaction(handle)
        do {
            let result = try await block()
            try await lance_db_commit_transaction(handle)
            return result
        } catch {
            try await lance_db_rollback_transaction(handle)
            throw error
        }
    }
}

class LanceTable {
    func filter(_ predicate: String, _ params: [Any] = []) -> Self { ... }
    func orderBy(_ column: String, ascending: Bool = true) -> Self { ... }
    func limit(_ n: Int) -> Self { ... }
    func search(_ vector: [Float], column: String) -> Self { ... }
    func execute<T: Decodable>() async throws -> [T] { ... }
}
```

---

## Appendix B: Sample Data

```json
// Session example
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "project_id": "661e8400-e29b-41d4-a716-446655440001",
  "engine_id": "claude",
  "name": "Implement authentication",
  "parent_id": null,
  "branch_point": null,
  "state": "active",
  "created_at": "2025-12-25T10:00:00Z",
  "last_used_at": "2025-12-25T14:30:00Z",
  "turn_count": 15,
  "total_tokens": 45000,
  "total_cost_usd": 0.45,
  "summary": "Implemented JWT-based authentication with refresh tokens..."
}

// Event example
{
  "id": "772e8400-e29b-41d4-a716-446655440002",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "sequence": 42,
  "timestamp": "2025-12-25T14:25:30.123Z",
  "event_type": "tool_call_completed",
  "source": "engine",
  "payload": {
    "toolCallId": "tc_123",
    "toolName": "edit",
    "output": "Successfully edited src/auth/login.ts",
    "success": true,
    "durationMs": 1250
  }
}
```

---

**End of Document**
