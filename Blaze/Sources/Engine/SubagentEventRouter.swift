import Foundation

// MARK: - Subagent Event Router

/// Routes subagent events to the correct tracker based on correlation.
///
/// **Purpose:**
/// - Intercepts subagent-specific events (spawned/progress/completed/failed)
/// - Updates SubagentRegistry with status, token usage, errors
/// - Coordinates with SubagentPool for queue management
///
/// **Integration:**
/// - Called from SessionOrchestrator.handleEvent() before normal processing
/// - Returns true if event was a subagent event (routed), false otherwise
/// - Events still flow to EventStore and UI for audit trail
///
/// **Thread Safety:**
/// - All methods are async and call actor-isolated components
/// - Safe to call from MainActor (SessionOrchestrator)
public actor SubagentEventRouter {
    private let registry: SubagentRegistry
    private let pool: SubagentPool

    public init(registry: SubagentRegistry, pool: SubagentPool) {
        self.registry = registry
        self.pool = pool
    }

    /// Route a normalized event - returns true if it was a subagent event that was routed
    ///
    /// - Parameters:
    ///   - event: The normalized event to route
    ///   - parentSessionId: The session that spawned this subagent (for correlation)
    /// - Returns: True if event was routed (subagent-specific), false otherwise
    public func route(_ event: NormalizedEvent, parentSessionId: UUID) async -> Bool {
        switch event {
        case .subagentSpawned(let spawned):
            // Register new subagent with dual correlation
            let correlation = await registry.register(
                toolUseId: spawned.toolUseId,
                parentSessionId: parentSessionId,
                subagentType: spawned.subagentType,
                description: spawned.description,
                prompt: spawned.prompt
            )

            // Enqueue in pool (may start immediately if slots available)
            _ = await pool.enqueue(correlation.internalId)
            return true

        case .subagentProgress(let progress):
            // Progress events are passive - just log/forward
            // Could update registry with progress metadata in future
            return true

        case .subagentCompleted(let completed):
            // Update status to completed
            await registry.updateStatus(completed.toolUseId, status: .completed)

            // Record token usage
            await registry.updateTokenUsage(completed.toolUseId, tokenUsage: completed.tokenUsage)

            // Notify pool of completion (auto-drains queue)
            if let correlation = await registry.lookup(toolUseId: completed.toolUseId) {
                _ = await pool.onComplete(correlation.internalId)
            }
            return true

        case .subagentFailed(let failed):
            // Update status and record error
            await registry.recordError(failed.toolUseId, error: failed.error)

            // Notify pool of completion (failed = done, auto-drains queue)
            if let correlation = await registry.lookup(toolUseId: failed.toolUseId) {
                _ = await pool.onComplete(correlation.internalId)
            }
            return true

        default:
            // Not a subagent event - return false so caller processes normally
            return false
        }
    }
}
