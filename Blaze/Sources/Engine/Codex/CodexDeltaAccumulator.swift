import Foundation

/// Thread-safe accumulator for Codex streaming text deltas.
///
/// Codex streams text via `item/agentMessage/delta` events with small fragments
/// per itemId. This actor buffers fragments and emits normalized events.
///
/// **Usage:**
/// ```swift
/// let accumulator = CodexDeltaAccumulator()
/// let deltaEvent = await accumulator.accumulateDelta(itemId: "msg_123", delta: "Hello ")
/// // deltaEvent is .assistantDelta with text "Hello "
///
/// let completeEvent = await accumulator.finalizeItem(itemId: "msg_123")
/// // completeEvent is .assistantComplete with fullText "Hello "
/// ```
public actor CodexDeltaAccumulator {
    // MARK: - State

    /// Maps itemId to accumulated text
    private var buffer: [String: String] = [:]

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Append a delta fragment to the buffer for the given itemId.
    ///
    /// - Parameters:
    ///   - itemId: The unique identifier for this message item
    ///   - delta: The text fragment to append
    /// - Returns: An `assistantDelta` event for the incoming fragment
    public func accumulateDelta(itemId: String, delta: String) -> NormalizedEvent {
        buffer[itemId, default: ""] += delta

        return .assistantDelta(AssistantDelta(
            text: delta,
            timestamp: Date()
        ))
    }

    /// Finalize an item, returning the complete accumulated text and clearing the buffer entry.
    ///
    /// - Parameter itemId: The unique identifier for the message item
    /// - Returns: An `assistantComplete` event with the full accumulated text,
    ///            or an event with empty text if no content was accumulated
    public func finalizeItem(itemId: String) -> NormalizedEvent {
        let fullText = buffer.removeValue(forKey: itemId) ?? ""

        return .assistantComplete(AssistantComplete(
            fullText: fullText,
            timestamp: Date(),
            stopReason: .endTurn
        ))
    }

    /// Clear all accumulated state.
    ///
    /// Call this when starting a new turn or resetting the adapter state.
    public func reset() {
        buffer.removeAll()
    }

    /// Number of items currently being accumulated.
    ///
    /// Useful for debugging and monitoring incomplete streams.
    public var itemCount: Int {
        buffer.count
    }

    /// Check if an item exists in the buffer.
    ///
    /// - Parameter itemId: The unique identifier to check
    /// - Returns: `true` if the item has accumulated content
    public func hasItem(_ itemId: String) -> Bool {
        buffer[itemId] != nil
    }

    /// Get the current accumulated text for an item without finalizing.
    ///
    /// - Parameter itemId: The unique identifier to peek
    /// - Returns: The accumulated text, or `nil` if the item doesn't exist
    public func peek(itemId: String) -> String? {
        buffer[itemId]
    }
}
