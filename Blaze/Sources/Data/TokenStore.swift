import Foundation
import GRDB

// MARK: - Token Store

/// Persistent storage for token usage per session and turn.
/// Tracks input/output/cache tokens and calculates estimated costs.
///
/// **Phase 2 System Contract:**
/// - Aggregates token usage across turns per session
/// - Calculates estimated costs based on model pricing
/// - Uses GRDB with WAL mode for concurrent reads
/// - Schema managed via MigrationRunner
actor TokenStore {
    private let dbPool: DatabasePool

    /// Initialize with existing database pool.
    /// Assumes migrations have already run via SessionStore.
    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    // MARK: - CRUD Operations

    /// Record token usage for a specific turn
    func recordUsage(_ usage: TokenUsageRecord) async throws {
        try await dbPool.write { db in
            try TokenUsageDBRecord(usage).insert(db)
        }
    }

    /// Get all token usage records for a session
    func getUsage(sessionId: UUID) async throws -> [TokenUsageRecord] {
        try await dbPool.read { db in
            try TokenUsageDBRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .order(Column("turn_number"))
                .fetchAll(db)
                .map { $0.toTokenUsageRecord() }
        }
    }

    /// Get aggregated token usage for a session
    func getAggregatedUsage(sessionId: UUID) async throws -> AggregatedTokenUsage {
        try await dbPool.read { db in
            let records = try TokenUsageDBRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .fetchAll(db)

            guard !records.isEmpty else {
                // Return empty aggregate
                return AggregatedTokenUsage(
                    sessionId: sessionId,
                    totalInputTokens: 0,
                    totalOutputTokens: 0,
                    totalCacheReadTokens: 0,
                    totalCacheWriteTokens: 0,
                    totalEstimatedCost: 0,
                    turnCount: 0
                )
            }

            let totalInput = records.reduce(0) { $0 + $1.inputTokens }
            let totalOutput = records.reduce(0) { $0 + $1.outputTokens }
            let totalCacheRead = records.reduce(0) { $0 + ($1.cacheReadTokens ?? 0) }
            let totalCacheWrite = records.reduce(0) { $0 + ($1.cacheWriteTokens ?? 0) }
            let totalCost = records.reduce(Decimal(0)) { result, record in
                result + (Decimal(string: record.estimatedCost) ?? 0)
            }

            return AggregatedTokenUsage(
                sessionId: sessionId,
                totalInputTokens: totalInput,
                totalOutputTokens: totalOutput,
                totalCacheReadTokens: totalCacheRead,
                totalCacheWriteTokens: totalCacheWrite,
                totalEstimatedCost: totalCost,
                turnCount: records.count
            )
        }
    }

    /// Delete all token usage records for a session
    func deleteUsage(sessionId: UUID) async throws {
        try await dbPool.write { db in
            try TokenUsageDBRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .deleteAll(db)
        }
    }

    /// Get token usage for a specific turn
    func getUsage(sessionId: UUID, turnNumber: Int) async throws -> TokenUsageRecord? {
        try await dbPool.read { db in
            try TokenUsageDBRecord
                .filter(Column("session_id") == sessionId.uuidString)
                .filter(Column("turn_number") == turnNumber)
                .fetchOne(db)?
                .toTokenUsageRecord()
        }
    }

    /// Update existing token usage record
    func updateUsage(_ usage: TokenUsageRecord) async throws {
        try await dbPool.write { db in
            try TokenUsageDBRecord(usage).update(db)
        }
    }
}

// MARK: - Token Usage Record

/// A single token usage record for a turn in a session
public struct TokenUsageRecord: Identifiable {
    public let id: UUID
    public let sessionId: UUID
    public let turnNumber: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int?
    public let cacheWriteTokens: Int?
    public let estimatedCost: Decimal
    public let modelId: String
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        turnNumber: Int,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int? = nil,
        cacheWriteTokens: Int? = nil,
        estimatedCost: Decimal = 0,
        modelId: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.turnNumber = turnNumber
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.estimatedCost = estimatedCost
        self.modelId = modelId
        self.timestamp = timestamp
    }

    /// Calculate total tokens for this turn
    public var totalTokens: Int {
        inputTokens + outputTokens + (cacheReadTokens ?? 0) + (cacheWriteTokens ?? 0)
    }
}

// MARK: - Aggregated Token Usage

/// Aggregated token usage across all turns in a session
public struct AggregatedTokenUsage {
    public let sessionId: UUID
    public let totalInputTokens: Int
    public let totalOutputTokens: Int
    public let totalCacheReadTokens: Int
    public let totalCacheWriteTokens: Int
    public let totalEstimatedCost: Decimal
    public let turnCount: Int

    /// Calculate grand total tokens
    public var grandTotalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheReadTokens + totalCacheWriteTokens
    }

    /// Average tokens per turn
    public var averageTokensPerTurn: Int {
        turnCount > 0 ? grandTotalTokens / turnCount : 0
    }

    /// Average cost per turn
    public var averageCostPerTurn: Decimal {
        turnCount > 0 ? totalEstimatedCost / Decimal(turnCount) : 0
    }
}

// MARK: - Database Record

/// Private database record for token usage
/// Maps between TokenUsageRecord and GRDB persistence
private struct TokenUsageDBRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "token_usage"

    let id: String
    let sessionId: String
    let turnNumber: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int?
    let cacheWriteTokens: Int?
    let estimatedCost: String
    let modelId: String
    let timestamp: Date

    init(_ record: TokenUsageRecord) {
        self.id = record.id.uuidString
        self.sessionId = record.sessionId.uuidString
        self.turnNumber = record.turnNumber
        self.inputTokens = record.inputTokens
        self.outputTokens = record.outputTokens
        self.cacheReadTokens = record.cacheReadTokens
        self.cacheWriteTokens = record.cacheWriteTokens
        self.estimatedCost = record.estimatedCost.description
        self.modelId = record.modelId
        self.timestamp = record.timestamp
    }

    func toTokenUsageRecord() -> TokenUsageRecord {
        TokenUsageRecord(
            id: UUID(uuidString: id)!,
            sessionId: UUID(uuidString: sessionId)!,
            turnNumber: turnNumber,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheWriteTokens: cacheWriteTokens,
            estimatedCost: Decimal(string: estimatedCost) ?? 0,
            modelId: modelId,
            timestamp: timestamp
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case turnNumber = "turn_number"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case cacheWriteTokens = "cache_write_tokens"
        case estimatedCost = "estimated_cost"
        case modelId = "model_id"
        case timestamp
    }
}
