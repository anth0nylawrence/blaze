import Foundation

// MARK: - Prompt Queue

/// FIFO queue for pending tool prompts with per-prompt submission state machine.
///
/// ## Design
/// - **FIFO ordering**: Prompts are processed in the order they arrive
/// - **Fast lookup**: O(1) lookup by prompt ID via dictionary
/// - **State machine**: Each prompt tracks its submission state independently
/// - **Idempotent**: Submission checks state before transitioning
///
/// ## Usage
/// ```swift
/// let queue = PromptQueue()
/// queue.enqueue(prompt)
/// queue.setSubmissionState(.submitting, for: prompt.toolUseId)
/// // On success:
/// queue.setSubmissionState(.submitted, for: prompt.toolUseId)
/// queue.dequeue(promptId: prompt.id)
/// ```
@MainActor
public final class PromptQueue: ObservableObject {

    // MARK: - Storage

    /// FIFO queue (first element is current prompt)
    @Published private var queue: [ToolPromptEvent] = []

    /// Fast lookup by prompt ID
    private var byId: [String: ToolPromptEvent] = [:]

    /// Submission state per prompt
    private var states: [String: SubmissionState] = [:]

    public init() {}

    // MARK: - Queue Properties

    /// Current prompt (front of queue)
    public var currentPrompt: ToolPromptEvent? {
        queue.first
    }

    /// Number of pending prompts
    public var pendingCount: Int {
        queue.count
    }

    /// Whether there are more prompts after current
    public var hasMorePrompts: Bool {
        queue.count > 1
    }

    // MARK: - Queue Operations

    /// Add a prompt to the back of the queue
    public func enqueue(_ prompt: ToolPromptEvent) {
        queue.append(prompt)
        byId[prompt.id] = prompt
        states[prompt.id] = .idle
    }

    /// Remove a prompt by prompt ID
    /// - Returns: The removed prompt, or nil if not found
    @discardableResult
    public func dequeue(promptId: String) -> ToolPromptEvent? {
        guard let prompt = byId.removeValue(forKey: promptId) else {
            return nil
        }

        queue.removeAll { $0.id == promptId }
        states.removeValue(forKey: promptId)

        return prompt
    }

    /// Remove all prompts
    public func clear() {
        queue.removeAll()
        byId.removeAll()
        states.removeAll()
    }

    // MARK: - Lookup

    /// Get a prompt by prompt ID
    public func prompt(for promptId: String) -> ToolPromptEvent? {
        byId[promptId]
    }

    // MARK: - State Machine

    /// Get submission state for a prompt
    public func submissionState(for promptId: String) -> SubmissionState {
        states[promptId] ?? .idle
    }

    /// Set submission state for a prompt
    public func setSubmissionState(_ state: SubmissionState, for promptId: String) {
        states[promptId] = state
    }

    /// Check if a prompt can be retried (only from failed state)
    public func canRetry(promptId: String) -> Bool {
        if case .failed = states[promptId] {
            return true
        }
        return false
    }

    /// Check if a prompt can be submitted (only from idle state)
    public func canSubmit(promptId: String) -> Bool {
        states[promptId] == .idle
    }
}
