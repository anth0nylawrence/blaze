import Foundation

// MARK: - Tool Approval Pipeline

/// Manages the tool approval flow per Phase 2 System Contract.
///
/// **Contract Guarantees:**
/// - Strict ordering: ToolRequest -> ToolDecision -> ToolResult
/// - Tool execution BLOCKS until decision is recorded
/// - Decisions are persisted and auditable
/// - Allowlist rules can auto-approve matching requests
public actor ToolApprovalPipeline {

    // MARK: - State

    /// Pending tool requests awaiting decisions
    private var pendingRequests: [UUID: ToolRequestEvent] = [:]

    /// Recorded decisions (for audit trail and lookup)
    private var decisions: [UUID: ToolDecisionEvent] = [:]

    /// Results for completed tools
    private var results: [UUID: ToolResultEvent] = [:]

    /// Allowlist rules for auto-approval
    private var allowlistRules: [AllowlistRule] = []

    /// Continuations waiting for decisions (for blocking await)
    private var decisionWaiters: [UUID: CheckedContinuation<ToolDecisionEvent, Never>] = [:]

    /// Delegate for persisting events
    public weak var delegate: (any ToolApprovalPipelineDelegate)?

    /// Trust mode for this session
    public var trustMode: TrustMode = .prompt

    // MARK: - Initialization

    public init(trustMode: TrustMode = .prompt, allowlistRules: [AllowlistRule] = []) {
        self.trustMode = trustMode
        self.allowlistRules = allowlistRules
    }

    // MARK: - Pipeline Operations

    /// Submit a tool request and wait for decision.
    /// This is a BLOCKING call per System Contract.
    public func submitRequest(_ request: ToolRequestEvent) async -> ToolDecisionEvent {
        // Store the pending request
        pendingRequests[request.id] = request

        // Notify delegate of request
        await delegate?.pipelineDidReceiveRequest(request)

        // Check for auto-approval based on trust mode and allowlist
        if let autoDecision = checkAutoApproval(for: request) {
            return recordDecision(autoDecision)
        }

        // Block until decision is made
        let decision = await withCheckedContinuation { (continuation: CheckedContinuation<ToolDecisionEvent, Never>) in
            decisionWaiters[request.id] = continuation
        }

        return decision
    }

    /// Record a decision for a pending request.
    /// Called by UI or system when user approves/rejects.
    public func recordDecision(_ decision: ToolDecisionEvent) -> ToolDecisionEvent {
        // Store the decision
        decisions[decision.toolRequestId] = decision

        // Remove from pending
        pendingRequests.removeValue(forKey: decision.toolRequestId)

        // Notify delegate
        Task {
            await delegate?.pipelineDidRecordDecision(decision)
        }

        // Resume any waiter
        if let waiter = decisionWaiters.removeValue(forKey: decision.toolRequestId) {
            waiter.resume(returning: decision)
        }

        return decision
    }

    /// Record a tool result after execution.
    public func recordResult(_ result: ToolResultEvent) {
        results[result.toolRequestId] = result

        // Notify delegate
        Task {
            await delegate?.pipelineDidRecordResult(result)
        }
    }

    /// Approve a pending request (convenience method for UI).
    public func approve(requestId: UUID, decidedBy: String = "user", rationale: String? = nil) -> ToolDecisionEvent? {
        guard pendingRequests[requestId] != nil else { return nil }

        let decision = ToolDecisionEvent(
            toolRequestId: requestId,
            decision: .approved,
            decidedBy: decidedBy,
            rationale: rationale
        )

        return recordDecision(decision)
    }

    /// Reject a pending request (convenience method for UI).
    public func reject(requestId: UUID, decidedBy: String = "user", rationale: String? = nil) -> ToolDecisionEvent? {
        guard pendingRequests[requestId] != nil else { return nil }

        let decision = ToolDecisionEvent(
            toolRequestId: requestId,
            decision: .rejected,
            decidedBy: decidedBy,
            rationale: rationale
        )

        return recordDecision(decision)
    }

    /// Always allow a tool (adds to allowlist).
    public func alwaysAllow(requestId: UUID, decidedBy: String = "user") -> (ToolDecisionEvent?, AllowlistRule?) {
        guard let request = pendingRequests[requestId] else { return (nil, nil) }

        // Create allowlist rule
        let rule = AllowlistRule(
            toolName: request.toolName,
            scope: request.scope,
            riskLevel: request.riskLevel
        )
        allowlistRules.append(rule)

        let decision = ToolDecisionEvent(
            toolRequestId: requestId,
            decision: .alwaysAllow,
            decidedBy: decidedBy,
            allowlistRuleId: rule.id
        )

        return (recordDecision(decision), rule)
    }

    // MARK: - Queries

    /// Get pending requests.
    public var pendingToolRequests: [ToolRequestEvent] {
        Array(pendingRequests.values)
    }

    /// Get decision for a request.
    public func getDecision(for requestId: UUID) -> ToolDecisionEvent? {
        decisions[requestId]
    }

    /// Get result for a request.
    public func getResult(for requestId: UUID) -> ToolResultEvent? {
        results[requestId]
    }

    /// Check if a request is pending.
    public func isPending(_ requestId: UUID) -> Bool {
        pendingRequests[requestId] != nil
    }

    /// Get current allowlist rules.
    public var currentAllowlistRules: [AllowlistRule] {
        allowlistRules
    }

    // MARK: - Auto-Approval Logic

    /// Check if request should be auto-approved based on trust mode and allowlist.
    private func checkAutoApproval(for request: ToolRequestEvent) -> ToolDecisionEvent? {
        // Get request risk order for comparison
        let requestRiskOrder = riskOrder(request.riskLevel)

        // Check trust mode using the Phase 2 contract
        switch trustMode {
        case .unrestricted:
            // Unrestricted mode auto-approves low/medium risk
            if let threshold = trustMode.autoApproveThreshold {
                let thresholdOrder = riskOrder(threshold)
                if requestRiskOrder <= thresholdOrder {
                    return ToolDecisionEvent(
                        toolRequestId: request.id,
                        decision: .approved,
                        decidedBy: "system:unrestricted_mode"
                    )
                }
            }

        case .lockedDown:
            // LockedDown only allows low-risk (read-only)
            if let threshold = trustMode.autoApproveThreshold {
                let thresholdOrder = riskOrder(threshold)
                if requestRiskOrder <= thresholdOrder {
                    return ToolDecisionEvent(
                        toolRequestId: request.id,
                        decision: .approved,
                        decidedBy: "system:locked_down_mode"
                    )
                }
            }
            // Auto-reject above threshold in locked down mode
            if trustMode.autoRejectAboveThreshold {
                return ToolDecisionEvent(
                    toolRequestId: request.id,
                    decision: .rejected,
                    decidedBy: "system:locked_down_mode",
                    rationale: "Locked down mode only allows read-only tools"
                )
            }

        case .prompt:
            // Prompt mode requires explicit approval, only check allowlist
            break

        case .allowlisted:
            // Allowlisted mode uses allowlist rules (handled below)
            break
        }

        // Check allowlist rules (for all modes)
        for rule in allowlistRules {
            if rule.matches(request) {
                return ToolDecisionEvent(
                    toolRequestId: request.id,
                    decision: .approved,
                    decidedBy: "system:allowlist",
                    allowlistRuleId: rule.id
                )
            }
        }

        // No auto-approval, will block for user decision
        return nil
    }

    private func riskOrder(_ level: ToolRiskLevel) -> Int {
        switch level {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    // MARK: - Configuration

    /// Update trust mode.
    public func setTrustMode(_ mode: TrustMode) {
        trustMode = mode
    }

    /// Add allowlist rule.
    public func addAllowlistRule(_ rule: AllowlistRule) {
        allowlistRules.append(rule)
    }

    /// Remove allowlist rule.
    public func removeAllowlistRule(id: UUID) {
        allowlistRules.removeAll { $0.id == id }
    }

    /// Reset pipeline state (for new session).
    public func reset() {
        pendingRequests.removeAll()
        decisions.removeAll()
        results.removeAll()
        // Note: allowlistRules are preserved across sessions
        // Cancel any waiters
        for (_, waiter) in decisionWaiters {
            // Create a rejection decision for cancelled waiters
            waiter.resume(returning: ToolDecisionEvent(
                toolRequestId: UUID(),
                decision: .rejected,
                decidedBy: "system:reset",
                rationale: "Pipeline reset"
            ))
        }
        decisionWaiters.removeAll()
    }
}

// MARK: - Allowlist Rule

/// Rule for auto-approving tool requests.
public struct AllowlistRule: Codable, Identifiable, Sendable {
    public let id: UUID
    public let toolName: String
    public let scope: ToolScope?
    public let riskLevel: ToolRiskLevel?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        toolName: String,
        scope: ToolScope? = nil,
        riskLevel: ToolRiskLevel? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.scope = scope
        self.riskLevel = riskLevel
        self.createdAt = createdAt
    }

    /// Check if this rule matches a request.
    public func matches(_ request: ToolRequestEvent) -> Bool {
        // Tool name must match
        guard request.toolName == toolName else { return false }

        // If rule has risk level, request must be at or below that level
        if let ruleRisk = riskLevel {
            let requestRiskOrder = riskOrder(request.riskLevel)
            let ruleRiskOrder = riskOrder(ruleRisk)
            if requestRiskOrder > ruleRiskOrder {
                return false
            }
        }

        // If rule has scope, request scope must be within rule scope
        if let ruleScope = scope, let requestScope = request.scope {
            if let rulePaths = ruleScope.paths, let requestPaths = requestScope.paths {
                // Check if request paths are within rule paths
                for requestPath in requestPaths {
                    let isAllowed = rulePaths.contains { rulePath in
                        requestPath.hasPrefix(rulePath) || requestPath == rulePath
                    }
                    if !isAllowed { return false }
                }
            }
        }

        return true
    }

    private func riskOrder(_ level: ToolRiskLevel) -> Int {
        switch level {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
}

// MARK: - Delegate Protocol

/// Delegate for persisting pipeline events.
public protocol ToolApprovalPipelineDelegate: AnyObject, Sendable {
    /// Called when a new tool request is received.
    func pipelineDidReceiveRequest(_ request: ToolRequestEvent) async

    /// Called when a decision is recorded.
    func pipelineDidRecordDecision(_ decision: ToolDecisionEvent) async

    /// Called when a result is recorded.
    func pipelineDidRecordResult(_ result: ToolResultEvent) async
}

// MARK: - Tool Risk Classification

/// Classifies tool risk level based on tool name and scope.
public struct ToolRiskClassifier {

    /// Safe tools that are always low risk (read-only).
    public static let safeTools = Set(["Read", "Glob", "Grep", "WebFetch", "WebSearch"])

    /// Dangerous tools that are always high risk.
    public static let dangerousTools = Set(["Bash", "Task"])

    /// Classify risk level for a tool.
    public static func classify(toolName: String, scope: ToolScope?) -> ToolRiskLevel {
        // Check safe tools
        if safeTools.contains(toolName) {
            return .low
        }

        // Check dangerous tools
        if dangerousTools.contains(toolName) {
            return .high
        }

        // Write/Edit are medium risk if within worktree
        if toolName == "Write" || toolName == "Edit" {
            // If scope has paths outside worktree, it's high risk
            // This will be determined by PathUtilities in Atom A006
            return .medium
        }

        // Default to medium for unknown tools
        return .medium
    }
}
