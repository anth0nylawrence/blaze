//
//  CodexEventMapper.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation
import os.log

// MARK: - Codex JSON-RPC Notification

/// Represents a Codex CLI JSON-RPC notification.
/// Codex uses JSON-RPC 2.0 notifications for streaming output.
public struct CodexNotification: Codable, Sendable {
    /// JSON-RPC version (always "2.0")
    public let jsonrpc: String

    /// Notification method name (e.g., "item/agentMessage/delta", "turn/started")
    public let method: String

    /// Notification parameters (structure varies by method)
    public let params: CodexNotificationParams

    public init(jsonrpc: String = "2.0", method: String, params: CodexNotificationParams) {
        self.jsonrpc = jsonrpc
        self.method = method
        self.params = params
    }
}

/// Parameters for Codex notifications.
/// Uses dynamic JSON decoding to handle varying structures.
public struct CodexNotificationParams: Codable, Sendable {
    /// Turn ID for turn-scoped events
    public let turnId: String?

    /// Item ID for item-scoped events
    public let itemId: String?

    /// Item type (e.g., "agentMessage", "tool")
    public let type: String?

    /// Text delta for streaming content
    public let delta: String?

    /// Summary delta for reasoning events
    public let summaryDelta: String?

    /// Content delta for reasoning events
    public let contentDelta: String?

    /// Full text content (for completed items)
    public let text: String?

    /// File path for file-related events
    public let filePath: String?

    /// Tool name for tool events
    public let toolName: String?

    /// Tool input for tool events
    public let input: String?

    /// Tool output for completed tool events
    public let output: String?

    /// Error message if tool failed
    public let error: String?

    /// Duration in milliseconds
    public let durationMs: Int?

    /// Explanation for plan updates
    public let explanation: String?

    /// Plan steps for turn/plan/updated
    public let steps: [CodexPlanStep]?

    /// Token usage information
    public let usage: CodexTokenUsage?

    /// Rate limit information
    public let rateLimits: CodexRateLimits?

    /// Session/thread ID
    public let sessionId: String?

    /// Reason for session end
    public let reason: String?

    public init(
        turnId: String? = nil,
        itemId: String? = nil,
        type: String? = nil,
        delta: String? = nil,
        summaryDelta: String? = nil,
        contentDelta: String? = nil,
        text: String? = nil,
        filePath: String? = nil,
        toolName: String? = nil,
        input: String? = nil,
        output: String? = nil,
        error: String? = nil,
        durationMs: Int? = nil,
        explanation: String? = nil,
        steps: [CodexPlanStep]? = nil,
        usage: CodexTokenUsage? = nil,
        rateLimits: CodexRateLimits? = nil,
        sessionId: String? = nil,
        reason: String? = nil
    ) {
        self.turnId = turnId
        self.itemId = itemId
        self.type = type
        self.delta = delta
        self.summaryDelta = summaryDelta
        self.contentDelta = contentDelta
        self.text = text
        self.filePath = filePath
        self.toolName = toolName
        self.input = input
        self.output = output
        self.error = error
        self.durationMs = durationMs
        self.explanation = explanation
        self.steps = steps
        self.usage = usage
        self.rateLimits = rateLimits
        self.sessionId = sessionId
        self.reason = reason
    }
}

/// Plan step from Codex turn/plan/updated
public struct CodexPlanStep: Codable, Sendable {
    public let id: String
    public let description: String
    public let status: String  // "pending", "in_progress", "done"

    public init(id: String, description: String, status: String) {
        self.id = id
        self.description = description
        self.status = status
    }
}

/// Token usage from Codex thread/tokenUsage/updated
public struct CodexTokenUsage: Codable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    public let cacheReadTokens: Int?
    public let cacheWriteTokens: Int?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        cacheReadTokens: Int? = nil,
        cacheWriteTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
    }
}

/// Rate limits from Codex account/rateLimits/updated
public struct CodexRateLimits: Codable, Sendable {
    public let primary: CodexRateLimitEntry?
    public let secondary: CodexRateLimitEntry?

    public init(primary: CodexRateLimitEntry? = nil, secondary: CodexRateLimitEntry? = nil) {
        self.primary = primary
        self.secondary = secondary
    }
}

public struct CodexRateLimitEntry: Codable, Sendable {
    public let model: String
    public let remaining: Int
    public let resetAt: Date

    public init(model: String, remaining: Int, resetAt: Date) {
        self.model = model
        self.remaining = remaining
        self.resetAt = resetAt
    }
}

// MARK: - Codex Event Mapper

/// Maps Codex CLI JSON-RPC notifications to NormalizedEvent.
///
/// ## Mapping Table
/// | Codex Method                      | NormalizedEvent          |
/// |-----------------------------------|--------------------------|
/// | item/agentMessage/delta           | assistantDelta           |
/// | item/completed (type=agentMessage)| assistantComplete        |
/// | item/started                      | toolCallStarted          |
/// | item/completed (type=tool)        | toolCallComplete         |
/// | turn/started                      | sessionStarted           |
/// | turn/completed                    | sessionEnded             |
/// | turn/plan/updated                 | turnPlanUpdated          |
/// | thread/tokenUsage/updated         | tokenUsage               |
/// | account/rateLimits/updated        | rateLimitsUpdated        |
/// | item/reasoning                    | reasoningDelta           |
/// | item/commandExecution/outputDelta | toolOutputDelta          |
/// | item/fileChange/outputDelta       | fileDiffDelta            |
public actor CodexEventMapper {
    private let logger = Logger(subsystem: "com.cogit0.Blaze", category: "CodexEventMapper")

    /// Track active tool calls for duration calculation
    private var activeToolCalls: [String: ToolCallState] = [:]

    /// Track accumulated text for assistant messages
    private var accumulatedText: [String: String] = [:]

    /// Default session ID when not provided
    private var currentSessionId: String = UUID().uuidString

    private struct ToolCallState {
        let name: String
        let input: String
        let startTime: Date
    }

    public init() {}

    /// Reset mapper state for a new session
    public func reset() {
        activeToolCalls.removeAll()
        accumulatedText.removeAll()
        currentSessionId = UUID().uuidString
    }

    /// Set the current session ID
    public func setSessionId(_ sessionId: String) {
        currentSessionId = sessionId
    }

    // MARK: - Main Mapping Entry Point

    /// Map a Codex JSON-RPC notification to NormalizedEvent.
    ///
    /// - Parameter notification: The Codex notification to map
    /// - Returns: The mapped NormalizedEvent, or nil if the notification is unknown/ignored
    public func map(notification: CodexNotification) -> NormalizedEvent? {
        let method = notification.method
        let params = notification.params
        let now = Date()

        switch method {
        // MARK: Assistant Message Events
        case "item/agentMessage/delta":
            return mapAgentMessageDelta(params: params, timestamp: now)

        // MARK: Item Lifecycle Events
        case "item/started":
            return mapItemStarted(params: params, timestamp: now)

        case "item/completed":
            return mapItemCompleted(params: params, timestamp: now)

        // MARK: Turn Lifecycle Events
        case "turn/started":
            return mapTurnStarted(params: params, timestamp: now)

        case "turn/completed":
            return mapTurnCompleted(params: params, timestamp: now)

        case "turn/plan/updated":
            return mapTurnPlanUpdated(params: params, timestamp: now)

        // MARK: Usage & Limits
        case "thread/tokenUsage/updated":
            return mapTokenUsageUpdated(params: params, timestamp: now)

        case "account/rateLimits/updated":
            return mapRateLimitsUpdated(params: params, timestamp: now)

        // MARK: Streaming Deltas
        case "item/reasoning":
            return mapReasoningDelta(params: params, timestamp: now)

        case "item/commandExecution/outputDelta":
            return mapCommandExecutionDelta(params: params, timestamp: now)

        case "item/fileChange/outputDelta":
            return mapFileChangeDelta(params: params, timestamp: now)

        default:
            // Unknown method - log and return nil
            logger.debug("Unknown Codex notification method: \(method)")
            return nil
        }
    }

    // MARK: - Event Mappers

    private func mapAgentMessageDelta(params: CodexNotificationParams, timestamp: Date) -> NormalizedEvent? {
        guard let delta = params.delta, !delta.isEmpty else {
            return nil
        }

        // Track accumulated text for this item
        let itemId = params.itemId ?? "default"
        let previousText = accumulatedText[itemId] ?? ""
        accumulatedText[itemId] = previousText + delta

        return .assistantDelta(AssistantDelta(
            text: delta,
            timestamp: timestamp
        ))
    }

    private func mapItemStarted(params: CodexNotificationParams, timestamp: Date) -> NormalizedEvent? {
        guard let itemId = params.itemId else {
            logger.warning("item/started missing itemId")
            return nil
        }

        // Tool calls have toolName in params
        let toolName = params.toolName ?? "unknown"
        let input = params.input ?? "{}"

        // Track this tool call for duration calculation
        activeToolCalls[itemId] = ToolCallState(
            name: toolName,
            input: input,
            startTime: timestamp
        )

        return .toolCallStarted(ToolCallStarted(
            toolCallId: itemId,
            toolName: toolName,
            input: input,
            timestamp: timestamp
        ))
    }

    private func mapItemCompleted(params: CodexNotificationParams, timestamp: Date) -> NormalizedEvent? {
        guard let itemId = params.itemId else {
            logger.warning("item/completed missing itemId")
            return nil
        }

        let itemType = params.type ?? "unknown"

        switch itemType {
        case "agentMessage":
            // Assistant message completed
            let fullText = accumulatedText[itemId] ?? params.text ?? ""
            accumulatedText.removeValue(forKey: itemId)

            return .assistantComplete(AssistantComplete(
                fullText: fullText,
                timestamp: timestamp,
                stopReason: .endTurn
            ))

        case "tool", "functionCall":
            // Tool call completed
            guard let toolState = activeToolCalls.removeValue(forKey: itemId) else {
                // No tracked start - create completion with minimal info
                return .toolCallComplete(ToolCallComplete(
                    toolCallId: itemId,
                    toolName: params.toolName ?? "unknown",
                    output: params.output,
                    error: params.error,
                    duration: 0,
                    timestamp: timestamp
                ))
            }

            let duration = timestamp.timeIntervalSince(toolState.startTime)

            return .toolCallComplete(ToolCallComplete(
                toolCallId: itemId,
                toolName: toolState.name,
                output: params.output,
                error: params.error,
                duration: duration,
                timestamp: timestamp
            ))

        default:
            logger.debug("Unknown item type in item/completed: \(itemType)")
            return nil
        }
    }

    private func mapTurnStarted(params: CodexNotificationParams, timestamp: Date) -> NormalizedEvent? {
        let sessionId = params.sessionId ?? params.turnId ?? currentSessionId

        return .sessionStarted(SessionStartedEvent(
            sessionId: sessionId,
            engineType: "codex",
            timestamp: timestamp
        ))
    }

    private func mapTurnCompleted(params: CodexNotificationParams, timestamp: Date) -> NormalizedEvent? {
        let sessionId = params.sessionId ?? params.turnId ?? currentSessionId
        let reason = params.reason ?? "completed"

        return .sessionEnded(SessionEndedEvent(
            sessionId: sessionId,
            reason: reason,
            timestamp: timestamp
        ))
    }

    private func mapTurnPlanUpdated(params: CodexNotificationParams, timestamp: Date) -> NormalizedEvent? {
        let turnId = params.turnId ?? currentSessionId
        let explanation = params.explanation ?? ""

        let steps: [PlanStep] = (params.steps ?? []).map { codexStep in
            let status: PlanStepStatus = switch codexStep.status {
            case "in_progress": .inProgress
            case "done": .done
            default: .pending
            }

            return PlanStep(
                id: codexStep.id,
                description: codexStep.description,
                status: status
            )
        }

        return .turnPlanUpdated(TurnPlanUpdatedEvent(
            turnId: turnId,
            explanation: explanation,
            steps: steps,
            timestamp: timestamp
        ))
    }

    private func mapTokenUsageUpdated(params: CodexNotificationParams, timestamp: Date) -> NormalizedEvent? {
        guard let usage = params.usage else {
            logger.warning("thread/tokenUsage/updated missing usage data")
            return nil
        }

        return .tokenUsage(TokenUsage(
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            cacheReadTokens: usage.cacheReadTokens,
            cacheWriteTokens: usage.cacheWriteTokens,
            totalTokens: usage.totalTokens,
            timestamp: timestamp
        ))
    }

    private func mapRateLimitsUpdated(params: CodexNotificationParams, timestamp: Date) -> NormalizedEvent? {
        guard let limits = params.rateLimits else {
            logger.warning("account/rateLimits/updated missing rateLimits data")
            return nil
        }

        let primaryLimit: RateLimit? = limits.primary.map { entry in
            RateLimit(
                model: entry.model,
                remaining: entry.remaining,
                resetAt: entry.resetAt
            )
        }

        let secondaryLimit: RateLimit? = limits.secondary.map { entry in
            RateLimit(
                model: entry.model,
                remaining: entry.remaining,
                resetAt: entry.resetAt
            )
        }

        return .rateLimitsUpdated(RateLimitsUpdatedEvent(
            primary: primaryLimit,
            secondary: secondaryLimit,
            timestamp: timestamp
        ))
    }

    private func mapReasoningDelta(params: CodexNotificationParams, timestamp: Date) -> NormalizedEvent? {
        let itemId = params.itemId ?? "default"

        // Reasoning can have summaryDelta and/or contentDelta
        guard params.summaryDelta != nil || params.contentDelta != nil else {
            return nil
        }

        return .reasoningDelta(ReasoningDeltaEvent(
            itemId: itemId,
            summaryDelta: params.summaryDelta,
            contentDelta: params.contentDelta,
            timestamp: timestamp
        ))
    }

    private func mapCommandExecutionDelta(params: CodexNotificationParams, timestamp: Date) -> NormalizedEvent? {
        guard let delta = params.delta, !delta.isEmpty else {
            return nil
        }

        let itemId = params.itemId ?? "default"

        return .toolOutputDelta(ToolOutputDeltaEvent(
            itemId: itemId,
            delta: delta,
            timestamp: timestamp
        ))
    }

    private func mapFileChangeDelta(params: CodexNotificationParams, timestamp: Date) -> NormalizedEvent? {
        guard let delta = params.delta, !delta.isEmpty else {
            return nil
        }

        let itemId = params.itemId ?? "default"

        return .fileDiffDelta(FileDiffDeltaEvent(
            itemId: itemId,
            delta: delta,
            timestamp: timestamp
        ))
    }
}

// MARK: - Convenience Extensions

extension CodexEventMapper {
    /// Parse raw JSON data into a CodexNotification.
    ///
    /// - Parameter data: Raw JSON data
    /// - Returns: Parsed notification, or nil if parsing fails
    public static func parse(data: Data) -> CodexNotification? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(CodexNotification.self, from: data)
        } catch {
            Logger(subsystem: "com.cogit0.Blaze", category: "CodexEventMapper")
                .error("Failed to parse Codex notification: \(error.localizedDescription)")
            return nil
        }
    }

    /// Map raw JSON data directly to NormalizedEvent.
    ///
    /// - Parameter data: Raw JSON data
    /// - Returns: Mapped event, or nil if parsing/mapping fails
    public func map(data: Data) async -> NormalizedEvent? {
        guard let notification = Self.parse(data: data) else {
            return nil
        }
        return map(notification: notification)
    }
}

// MARK: - Legacy Compatibility

extension CodexEventMapper {
    /// Map Claude stream events to normalized events.
    ///
    /// This is a compatibility shim for the CodexCliAdapter which currently
    /// parses Claude-style NDJSON. When the adapter is updated to parse
    /// native Codex JSON-RPC notifications, this method can be removed.
    ///
    /// - Parameter event: A Claude stream event
    /// - Returns: Array of normalized events
    func map(_ event: ClaudeStreamEvent) -> [NormalizedEvent] {
        let now = Date()

        switch event {
        case .`init`(let initEvent):
            let sessionId = initEvent.sessionId ?? initEvent.message.sessionId
            return [.sessionStarted(SessionStartedEvent(
                sessionId: sessionId,
                engineType: "codex",
                timestamp: now
            ))]

        case .assistant(let assistantEvent):
            var events: [NormalizedEvent] = []

            for block in assistantEvent.message.content {
                if case .text(let textBlock) = block {
                    let messageId = assistantEvent.message.id
                    let previousText = accumulatedText[messageId] ?? ""
                    let newText = textBlock.text

                    if newText.count > previousText.count {
                        let deltaText = String(newText.dropFirst(previousText.count))
                        events.append(.assistantDelta(AssistantDelta(
                            text: deltaText,
                            timestamp: now
                        )))
                    }

                    accumulatedText[messageId] = newText

                    if assistantEvent.message.stopReason != nil {
                        let stopReason: StopReason? = switch assistantEvent.message.stopReason {
                        case "end_turn": .endTurn
                        case "tool_use": .toolUse
                        case "max_tokens": .maxTokens
                        default: nil
                        }

                        events.append(.assistantComplete(AssistantComplete(
                            fullText: newText,
                            timestamp: now,
                            stopReason: stopReason
                        )))
                    }
                }

                // Handle tool use blocks
                if case .toolUse(let toolBlock) = block {
                    events.append(.toolCallStarted(ToolCallStarted(
                        toolCallId: toolBlock.id,
                        toolName: toolBlock.name,
                        input: toolBlock.input.asJSON(),
                        timestamp: now
                    )))
                }
            }

            return events

        case .result(let resultEvent):
            let sessionId = resultEvent.sessionId
            let reason = resultEvent.success ? "completed" : "error"

            return [.sessionEnded(SessionEndedEvent(
                sessionId: sessionId,
                reason: reason,
                timestamp: now
            ))]

        case .system(let systemEvent):
            if systemEvent.message.level == "error" {
                let code = systemEvent.message.code ?? "unknown"
                return [.error(ErrorEvent(
                    code: code,
                    message: systemEvent.message.text,
                    isRecoverable: false,
                    timestamp: now
                ))]
            }
            return []

        case .user, .unknown, .systemInit, .hookResponse, .summary:
            return []
        }
    }
}
