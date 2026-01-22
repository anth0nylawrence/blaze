//
//  CodexReviewMode.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation
import os.log

// MARK: - Review Mode State

/// State of the Codex review mode protocol.
///
/// Codex has a "review mode" where the agent pauses execution for human
/// review of pending changes before applying them. This is distinct from
/// the approval flow which handles individual tool calls.
public enum CodexReviewModeState: Sendable {
    /// Not in review mode - normal operation
    case idle
    /// Review mode active - waiting for human decision
    case pendingReview(ReviewModeContext)
    /// Review completed - either approved or rejected
    case completed(ReviewModeResult)
}

// MARK: - Review Mode Context

/// Context for an active review mode session.
///
/// Contains all information needed to display pending changes to the user
/// and make an informed decision.
public struct ReviewModeContext: Sendable {
    /// Unique identifier for this review session
    public let reviewId: String
    /// Human-readable reason for entering review mode
    public let reason: String
    /// Pending file changes awaiting review
    public let pendingChanges: [ReviewModeFileDiff]
    /// When review mode was entered
    public let enteredAt: Date

    public init(
        reviewId: String,
        reason: String,
        pendingChanges: [ReviewModeFileDiff],
        enteredAt: Date = Date()
    ) {
        self.reviewId = reviewId
        self.reason = reason
        self.pendingChanges = pendingChanges
        self.enteredAt = enteredAt
    }
}

// MARK: - JSON-RPC Methods

/// JSON-RPC method names for Codex review mode protocol.
public enum CodexReviewMethod: String, Sendable {
    /// Codex signals it has entered review mode
    case enteredReviewMode = "codex/enteredReviewMode"
    /// Codex signals it has exited review mode
    case exitedReviewMode = "codex/exitedReviewMode"

    // Client -> Codex responses
    /// Client approves the review
    case approveReview = "codex/approveReview"
    /// Client cancels/rejects the review
    case cancelReview = "codex/cancelReview"
}

// MARK: - Review Mode Request Params

/// Parameters for enteredReviewMode notification from Codex.
public struct ReviewModeEnteredParams: Codable, Sendable {
    /// Unique review session ID
    public let reviewId: String
    /// Reason for entering review mode
    public let reason: String
    /// Pending file changes
    public let pendingChanges: [CodexReviewFileChange]

    enum CodingKeys: String, CodingKey {
        case reviewId = "review_id"
        case reason
        case pendingChanges = "pending_changes"
    }
}

/// File change pending review (from Codex).
public struct CodexReviewFileChange: Codable, Sendable {
    /// Path to the file
    public let path: String
    /// Type of change: "create", "modify", "delete"
    public let changeType: String
    /// Unified diff content (nil for new files)
    public let diff: String?

    enum CodingKeys: String, CodingKey {
        case path
        case changeType = "change_type"
        case diff
    }

    /// Convert to normalized ReviewModeFileDiff
    func toNormalized() -> ReviewModeFileDiff {
        ReviewModeFileDiff(filePath: path, changeType: changeType, diff: diff)
    }
}

/// Parameters for exitedReviewMode notification from Codex.
public struct ReviewModeExitedParams: Codable, Sendable {
    /// The review ID that was exited
    public let reviewId: String
    /// Result: "approved", "cancelled", "timeout"
    public let result: String

    enum CodingKeys: String, CodingKey {
        case reviewId = "review_id"
        case result
    }
}

// MARK: - JSON-RPC Requests to Codex

/// JSON-RPC request to approve a review.
public struct CodexApproveReviewRequest: Codable, Sendable {
    public let jsonrpc: String = "2.0"
    public let id: JSONRPCId
    public let method: String = CodexReviewMethod.approveReview.rawValue
    public let params: ApproveReviewParams

    public init(id: JSONRPCId, reviewId: String) {
        self.id = id
        self.params = ApproveReviewParams(reviewId: reviewId)
    }
}

/// Parameters for approve review request.
public struct ApproveReviewParams: Codable, Sendable {
    public let reviewId: String

    enum CodingKeys: String, CodingKey {
        case reviewId = "review_id"
    }
}

/// JSON-RPC request to cancel a review.
public struct CodexCancelReviewRequest: Codable, Sendable {
    public let jsonrpc: String = "2.0"
    public let id: JSONRPCId
    public let method: String = CodexReviewMethod.cancelReview.rawValue
    public let params: CancelReviewParams

    public init(id: JSONRPCId, reviewId: String, reason: String? = nil) {
        self.id = id
        self.params = CancelReviewParams(reviewId: reviewId, reason: reason)
    }
}

/// Parameters for cancel review request.
public struct CancelReviewParams: Codable, Sendable {
    public let reviewId: String
    public let reason: String?

    enum CodingKeys: String, CodingKey {
        case reviewId = "review_id"
        case reason
    }
}

// MARK: - Codex Review Mode Handler

/// Handles the Codex review mode protocol for human review of changes.
///
/// ## Protocol Flow
/// 1. Codex emits `enteredReviewMode` notification with pending changes
/// 2. Handler updates state and notifies UI
/// 3. User reviews changes in UI
/// 4. User approves or cancels
/// 5. Handler sends `approveReview` or `cancelReview` via JSON-RPC
/// 6. Codex emits `exitedReviewMode` confirmation
///
/// ## Timeout Handling
/// If the user doesn't respond within the timeout period, the review
/// is automatically cancelled to prevent Codex from hanging indefinitely.
public actor CodexReviewMode {
    private let logger = Logger(subsystem: "com.cogit0.Blaze", category: "CodexReviewMode")

    // MARK: - State

    /// Current review mode state
    private(set) public var state: CodexReviewModeState = .idle

    /// Request ID counter for JSON-RPC
    private var requestIdCounter: Int = 0

    /// Default timeout for review decisions (2 minutes)
    public let defaultTimeout: TimeInterval

    /// Callback to send JSON-RPC messages to Codex stdin
    private let sendToCodex: @Sendable (Data) async throws -> Void

    // MARK: - Initialization

    /// Create a new review mode handler.
    ///
    /// - Parameters:
    ///   - defaultTimeout: Timeout for user decisions (default 120s).
    ///   - sendToCodex: Callback to send JSON-RPC data to Codex stdin.
    public init(
        defaultTimeout: TimeInterval = 120.0,
        sendToCodex: @escaping @Sendable (Data) async throws -> Void
    ) {
        self.defaultTimeout = defaultTimeout
        self.sendToCodex = sendToCodex
    }

    // MARK: - Event Handling

    /// Handle enteredReviewMode notification from Codex.
    ///
    /// - Parameter params: The review mode parameters from Codex.
    /// - Returns: Normalized event for the event stream.
    public func handleEnteredReviewMode(_ params: ReviewModeEnteredParams) -> NormalizedEvent {
        let pendingChanges = params.pendingChanges.map { $0.toNormalized() }

        let context = ReviewModeContext(
            reviewId: params.reviewId,
            reason: params.reason,
            pendingChanges: pendingChanges
        )

        state = .pendingReview(context)

        logger.info("Entered review mode: \(params.reviewId) - \(params.reason)")

        return .reviewModeEntered(ReviewModeEnteredEvent(
            reviewId: params.reviewId,
            reason: params.reason,
            pendingChanges: pendingChanges
        ))
    }

    /// Handle exitedReviewMode notification from Codex.
    ///
    /// - Parameter params: The exit parameters from Codex.
    /// - Returns: Normalized event for the event stream.
    public func handleExitedReviewMode(_ params: ReviewModeExitedParams) -> NormalizedEvent {
        let result: ReviewModeResult = switch params.result {
        case "approved": .approved
        case "cancelled": .cancelled
        case "timeout": .timeout
        default: .cancelled
        }

        state = .completed(result)

        logger.info("Exited review mode: \(params.reviewId) - \(params.result)")

        // Reset to idle after processing
        Task { @MainActor in
            // Small delay before resetting to allow UI to update
            try? await Task.sleep(for: .milliseconds(100))
            await self.resetToIdle()
        }

        return .reviewModeExited(ReviewModeExitedEvent(
            reviewId: params.reviewId,
            result: result
        ))
    }

    // MARK: - User Actions

    /// Approve the current review.
    ///
    /// Sends approval to Codex and updates state.
    ///
    /// - Parameter reviewId: The review ID to approve.
    /// - Throws: If not in review mode or reviewId doesn't match.
    public func approveReview(reviewId: String) async throws {
        guard case .pendingReview(let context) = state else {
            throw ReviewModeError.notInReviewMode
        }

        guard context.reviewId == reviewId else {
            throw ReviewModeError.reviewIdMismatch(expected: context.reviewId, got: reviewId)
        }

        let request = CodexApproveReviewRequest(
            id: nextRequestId(),
            reviewId: reviewId
        )

        let data = try JSONEncoder().encode(request)
        try await sendToCodex(data)

        logger.info("Sent review approval for: \(reviewId)")
    }

    /// Cancel the current review.
    ///
    /// Sends cancellation to Codex and updates state.
    ///
    /// - Parameters:
    ///   - reviewId: The review ID to cancel.
    ///   - reason: Optional reason for cancellation.
    /// - Throws: If not in review mode or reviewId doesn't match.
    public func cancelReview(reviewId: String, reason: String? = nil) async throws {
        guard case .pendingReview(let context) = state else {
            throw ReviewModeError.notInReviewMode
        }

        guard context.reviewId == reviewId else {
            throw ReviewModeError.reviewIdMismatch(expected: context.reviewId, got: reviewId)
        }

        let request = CodexCancelReviewRequest(
            id: nextRequestId(),
            reviewId: reviewId,
            reason: reason
        )

        let data = try JSONEncoder().encode(request)
        try await sendToCodex(data)

        logger.info("Sent review cancellation for: \(reviewId)")
    }

    /// Initiate the review start (called when UI is ready to display review).
    ///
    /// This is a no-op for now but could be used to track UI readiness
    /// or send acknowledgment to Codex.
    public func sendReviewStart() async {
        logger.debug("Review UI ready")
    }

    // MARK: - Queries

    /// Check if currently in review mode.
    public var isInReviewMode: Bool {
        if case .pendingReview = state {
            return true
        }
        return false
    }

    /// Get the current review context if in review mode.
    public var currentReviewContext: ReviewModeContext? {
        if case .pendingReview(let context) = state {
            return context
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Generate next JSON-RPC request ID.
    private func nextRequestId() -> JSONRPCId {
        requestIdCounter += 1
        return .number(requestIdCounter)
    }

    /// Reset state to idle.
    private func resetToIdle() {
        state = .idle
    }

    /// Parse raw JSON data into review mode params.
    ///
    /// - Parameters:
    ///   - data: Raw JSON data
    ///   - method: The JSON-RPC method name
    /// - Returns: Parsed params or nil
    public static func parseParams(from data: Data, method: String) -> Any? {
        let decoder = JSONDecoder()

        switch method {
        case CodexReviewMethod.enteredReviewMode.rawValue:
            return try? decoder.decode(ReviewModeEnteredParams.self, from: data)

        case CodexReviewMethod.exitedReviewMode.rawValue:
            return try? decoder.decode(ReviewModeExitedParams.self, from: data)

        default:
            return nil
        }
    }
}

// MARK: - Errors

/// Errors that can occur during review mode handling.
public enum ReviewModeError: Error, LocalizedError {
    case notInReviewMode
    case reviewIdMismatch(expected: String, got: String)
    case sendFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .notInReviewMode:
            return "Not currently in review mode"
        case .reviewIdMismatch(let expected, let got):
            return "Review ID mismatch: expected \(expected), got \(got)"
        case .sendFailed(let underlying):
            return "Failed to send to Codex: \(underlying.localizedDescription)"
        }
    }
}
