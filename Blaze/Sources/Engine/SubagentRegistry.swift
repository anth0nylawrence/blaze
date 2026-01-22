import Foundation

// MARK: - Subagent Token Usage

public struct SubagentTokenUsage: Codable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let durationMs: Int?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        durationMs: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.durationMs = durationMs
    }
}

// MARK: - Subagent Status

public enum SubagentStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case failed
    case cancelled
}

// MARK: - Subagent Correlation

/// Dual correlation: CLI's tool_use.id + Blaze's internal UUID
public struct SubagentCorrelation: Codable, Sendable {
    public let toolUseId: String
    public let internalId: UUID
    public let parentSessionId: UUID
    public let subagentType: String
    public let description: String
    public let prompt: String
    public var status: SubagentStatus
    public var queuePosition: Int?
    public var priority: Int
    public var tokenUsage: SubagentTokenUsage?
    public var startedAt: Date?
    public var completedAt: Date?
    public var error: String?

    public init(
        toolUseId: String,
        internalId: UUID,
        parentSessionId: UUID,
        subagentType: String,
        description: String,
        prompt: String,
        status: SubagentStatus = .queued,
        queuePosition: Int? = nil,
        priority: Int = 0,
        tokenUsage: SubagentTokenUsage? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        error: String? = nil
    ) {
        self.toolUseId = toolUseId
        self.internalId = internalId
        self.parentSessionId = parentSessionId
        self.subagentType = subagentType
        self.description = description
        self.prompt = prompt
        self.status = status
        self.queuePosition = queuePosition
        self.priority = priority
        self.tokenUsage = tokenUsage
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.error = error
    }
}

// MARK: - Subagent Registry

/// Thread-safe registry for tracking subagent execution with dual correlation.
///
/// **Dual Correlation:**
/// - `toolUseId`: CLI-provided tool_use.id from streaming events
/// - `internalId`: Blaze-generated UUID for internal tracking
///
/// **Purpose:**
/// - Map CLI tool_use.id to internal UUID for event correlation
/// - Track subagent status, queue position, and telemetry
/// - Support queue management and priority scheduling
///
/// **Thread Safety:**
/// - All methods are async and isolated to the actor
/// - Safe to call from multiple tasks concurrently
public actor SubagentRegistry {
    private var byToolUseId: [String: SubagentCorrelation] = [:]
    private var byInternalId: [UUID: SubagentCorrelation] = [:]

    public init() {}

    /// Register a new subagent with dual correlation IDs
    ///
    /// - Parameters:
    ///   - toolUseId: CLI's tool_use.id from streaming event
    ///   - parentSessionId: Session that spawned this subagent
    ///   - subagentType: Type of subagent (e.g., "plan-agent", "implement-agent")
    ///   - description: Human-readable description
    ///   - prompt: Full prompt sent to subagent
    ///   - priority: Queue priority (higher = earlier execution)
    /// - Returns: The created correlation with both IDs
    @discardableResult
    public func register(
        toolUseId: String,
        parentSessionId: UUID,
        subagentType: String,
        description: String,
        prompt: String,
        priority: Int = 0
    ) -> SubagentCorrelation {
        let internalId = UUID()
        let correlation = SubagentCorrelation(
            toolUseId: toolUseId,
            internalId: internalId,
            parentSessionId: parentSessionId,
            subagentType: subagentType,
            description: description,
            prompt: prompt,
            priority: priority
        )

        byToolUseId[toolUseId] = correlation
        byInternalId[internalId] = correlation

        return correlation
    }

    /// Lookup subagent by CLI tool_use.id
    ///
    /// - Parameter toolUseId: The CLI's tool_use.id
    /// - Returns: Correlation if found, nil otherwise
    public func lookup(toolUseId: String) -> SubagentCorrelation? {
        return byToolUseId[toolUseId]
    }

    /// Lookup subagent by Blaze internal UUID
    ///
    /// - Parameter internalId: The internal UUID
    /// - Returns: Correlation if found, nil otherwise
    public func lookup(internalId: UUID) -> SubagentCorrelation? {
        return byInternalId[internalId]
    }

    /// Update the status of a subagent
    ///
    /// - Parameters:
    ///   - toolUseId: The CLI's tool_use.id
    ///   - status: New status
    public func updateStatus(_ toolUseId: String, status: SubagentStatus) {
        guard var correlation = byToolUseId[toolUseId] else { return }

        correlation.status = status

        // Update timestamps based on status
        switch status {
        case .running:
            correlation.startedAt = Date()
        case .completed, .failed, .cancelled:
            correlation.completedAt = Date()
        case .queued:
            break
        }

        // Update both indexes
        byToolUseId[toolUseId] = correlation
        byInternalId[correlation.internalId] = correlation
    }

    /// Update token usage for a subagent
    ///
    /// - Parameters:
    ///   - toolUseId: The CLI's tool_use.id
    ///   - tokenUsage: Token usage data
    public func updateTokenUsage(_ toolUseId: String, tokenUsage: SubagentTokenUsage) {
        guard var correlation = byToolUseId[toolUseId] else { return }

        correlation.tokenUsage = tokenUsage

        // Update both indexes
        byToolUseId[toolUseId] = correlation
        byInternalId[correlation.internalId] = correlation
    }

    /// Update queue position for a subagent
    ///
    /// - Parameters:
    ///   - toolUseId: The CLI's tool_use.id
    ///   - position: New queue position (1-indexed)
    public func updateQueuePosition(_ toolUseId: String, position: Int) {
        guard var correlation = byToolUseId[toolUseId] else { return }

        correlation.queuePosition = position

        // Update both indexes
        byToolUseId[toolUseId] = correlation
        byInternalId[correlation.internalId] = correlation
    }

    /// Record an error for a subagent
    ///
    /// - Parameters:
    ///   - toolUseId: The CLI's tool_use.id
    ///   - error: Error message
    public func recordError(_ toolUseId: String, error: String) {
        guard var correlation = byToolUseId[toolUseId] else { return }

        correlation.error = error
        correlation.status = .failed
        correlation.completedAt = Date()

        // Update both indexes
        byToolUseId[toolUseId] = correlation
        byInternalId[correlation.internalId] = correlation
    }

    /// Get all subagents for a parent session
    ///
    /// - Parameter parentSessionId: The parent session UUID
    /// - Returns: Array of correlations for this session
    public func getAll(for parentSessionId: UUID) -> [SubagentCorrelation] {
        return byInternalId.values.filter { $0.parentSessionId == parentSessionId }
    }

    /// Get all subagents sorted by queue priority (highest first)
    ///
    /// - Returns: Array of correlations sorted by priority descending
    public func getAllByPriority() -> [SubagentCorrelation] {
        return byInternalId.values.sorted { $0.priority > $1.priority }
    }

    /// Get count of subagents by status
    ///
    /// - Parameter status: Status to filter by
    /// - Returns: Count of subagents in that status
    public func count(status: SubagentStatus) -> Int {
        return byInternalId.values.filter { $0.status == status }.count
    }

    /// Clear all registrations (for testing)
    public func clear() {
        byToolUseId.removeAll()
        byInternalId.removeAll()
    }

    // MARK: - Token Aggregation

    /// Get total tokens for a parent session (parent + all subagents)
    ///
    /// - Parameter parentSessionId: The parent session UUID
    /// - Returns: Sum of totalTokens across all subagents
    public func getTotalTokens(for parentSessionId: UUID) -> Int {
        let subagents = getAll(for: parentSessionId)
        return subagents.reduce(0) { $0 + ($1.tokenUsage?.totalTokens ?? 0) }
    }

    /// Get token breakdown by subagent for hierarchy view
    ///
    /// - Parameter parentSessionId: The parent session UUID
    /// - Returns: Array of (subagent, tokens) tuples sorted by token count descending
    public func getTokenHierarchy(for parentSessionId: UUID) -> [(subagent: SubagentCorrelation, tokens: Int)] {
        let subagents = getAll(for: parentSessionId)
        return subagents.map { ($0, $0.tokenUsage?.totalTokens ?? 0) }
            .sorted { $0.tokens > $1.tokens }
    }

    /// Get running total over time for timeline chart
    ///
    /// - Parameter parentSessionId: The parent session UUID
    /// - Returns: Array of (date, cumulativeTokens, agentLabel) tuples for completed subagents
    public func getTokenTimeline(for parentSessionId: UUID) -> [(date: Date, cumulativeTokens: Int, agentLabel: String)] {
        var timeline: [(Date, Int, String)] = []
        var cumulative = 0

        let subagents = getAll(for: parentSessionId)
            .filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? .distantFuture) < ($1.completedAt ?? .distantFuture) }

        for agent in subagents {
            cumulative += agent.tokenUsage?.totalTokens ?? 0
            if let completed = agent.completedAt {
                timeline.append((completed, cumulative, "\(agent.subagentType)-\(agent.internalId.uuidString.prefix(4))"))
            }
        }
        return timeline
    }
}
