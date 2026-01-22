import Foundation

// MARK: - Claude Event Mapper

/// Maps Claude CLI stream events to normalized events.
/// Handles streaming text assembly and tool call tracking.
actor ClaudeEventMapper {
    // Track active tool calls for duration calculation
    private var activeToolCalls: [String: ToolCallState] = [:]

    // Track current assistant message for text assembly
    private var currentMessageId: String?
    private var accumulatedText: String = ""

    private struct ToolCallState {
        let name: String
        let input: String
        let startTime: Date
    }

    /// Map a Claude stream event to normalized events.
    /// May return multiple events (e.g., text delta + tool call started).
    func map(_ event: ClaudeStreamEvent) -> [NormalizedEvent] {
        switch event {
        case .`init`(let initEvent):
            return mapInit(initEvent)

        case .systemInit(let systemInitEvent):
            return mapSystemInit(systemInitEvent)

        case .hookResponse(let hookEvent):
            return mapHookResponse(hookEvent)

        case .user(let userEvent):
            return mapUser(userEvent)

        case .assistant(let assistantEvent):
            return mapAssistant(assistantEvent)

        case .result(let resultEvent):
            return mapResult(resultEvent)

        case .summary(let summaryEvent):
            return mapSummary(summaryEvent)

        case .system(let systemEvent):
            return mapSystem(systemEvent)

        case .unknown(let rawEvent):
            return [.raw(RawEvent(
                type: rawEvent.type,
                payload: rawEvent.payload ?? Data(),
                timestamp: rawEvent.timestamp
            ))]
        }
    }

    /// Reset mapper state for a new session
    func reset() {
        activeToolCalls.removeAll()
        currentMessageId = nil
        accumulatedText = ""
    }

    // MARK: - Event Mapping

    private func mapInit(_ event: InitStreamEvent) -> [NormalizedEvent] {
        // Use top-level sessionId if available, otherwise use message.sessionId
        let sessionId = event.sessionId ?? event.message.sessionId
        return [.sessionStarted(SessionStartedEvent(
            sessionId: sessionId,
            engineType: "claude",
            timestamp: event.timestamp
        ))]
    }

    private func mapSystemInit(_ event: SystemInitStreamEvent) -> [NormalizedEvent] {
        // Real CLI sends type="system", subtype="init" for session initialization
        [.sessionStarted(SessionStartedEvent(
            sessionId: event.sessionId,
            engineType: "claude",
            timestamp: event.timestamp
        ))]
    }

    private func mapHookResponse(_ event: HookResponseEvent) -> [NormalizedEvent] {
        // Hook responses are informational - store as raw events
        // Could be used for debugging or hook status tracking
        [.raw(RawEvent(
            type: "hook_response:\(event.hookEvent)",
            payload: Data(),
            timestamp: Date()
        ))]
    }

    private func mapUser(_ event: UserStreamEvent) -> [NormalizedEvent] {
        var events: [NormalizedEvent] = []

        // Always check content blocks for tool results
        // Note: The CLI sends tool_use_result as a string (summary), not an object,
        // so we can't rely on toolUseResult being non-nil. Instead, we scan content blocks.
        events.append(contentsOf: mapToolResultFromContent(event))

        return events
    }

    private func mapAssistant(_ event: AssistantStreamEvent) -> [NormalizedEvent] {
        var events: [NormalizedEvent] = []
        let message = event.message

        // Track message ID for streaming assembly
        if currentMessageId != message.id {
            currentMessageId = message.id
            accumulatedText = ""
        }

        // Process content blocks
        for block in message.content {
            switch block {
            case .text(let textBlock):
                // Accumulate text for delta tracking
                let newText = textBlock.text
                if newText != accumulatedText {
                    // Emit delta for new text
                    let delta = String(newText.dropFirst(accumulatedText.count))
                    if !delta.isEmpty {
                        events.append(.assistantDelta(AssistantDelta(
                            text: delta,
                            timestamp: event.timestamp
                        )))
                    }
                    accumulatedText = newText
                }

            case .toolUse(let toolBlock):
                // Start tracking this tool call
                let inputJson = toolBlock.input.asJSON()
                activeToolCalls[toolBlock.id] = ToolCallState(
                    name: toolBlock.name,
                    input: inputJson,
                    startTime: event.timestamp
                )

                events.append(.toolCallStarted(ToolCallStarted(
                    toolCallId: toolBlock.id,
                    toolName: toolBlock.name,
                    input: inputJson,
                    timestamp: event.timestamp
                )))

                // Check for subagent spawns (Task tool)
                if toolBlock.name == "Task" {
                    let subagentType = toolBlock.input.getString("subagent_type") ?? "general-purpose"
                    let description = toolBlock.input.getString("description") ?? ""
                    let prompt = toolBlock.input.getString("prompt") ?? ""

                    events.append(.subagentSpawned(SubagentSpawnedEvent(
                        toolUseId: toolBlock.id,
                        subagentType: subagentType,
                        description: description,
                        prompt: prompt,
                        timestamp: event.timestamp
                    )))
                }

                // Check for file operations to produce diff events
                if let fileEvent = extractFileEvent(from: toolBlock) {
                    events.append(fileEvent)
                }

            case .thinking(let thinkBlock):
                // Extended thinking - emit as ThinkingDelta
                events.append(.thinkingDelta(ThinkingDelta(
                    text: thinkBlock.thinking,
                    timestamp: event.timestamp
                )))

            case .unknown(type: let type):
                events.append(.raw(RawEvent(
                    type: "assistant_block_\(type)",
                    payload: Data(),
                    timestamp: event.timestamp
                )))
            }
        }

        // Check if message is complete
        if let stopReason = message.stopReason {
            events.append(.assistantComplete(AssistantComplete(
                fullText: accumulatedText,
                timestamp: event.timestamp,
                stopReason: StopReason(rawValue: stopReason)
            )))
        }

        // Add token usage if available
        if let usage = message.usage {
            events.append(.tokenUsage(TokenUsage(
                inputTokens: usage.inputTokens,
                outputTokens: usage.outputTokens,
                cacheReadTokens: usage.cacheReadInputTokens,
                cacheWriteTokens: usage.cacheCreationInputTokens,
                totalTokens: usage.total,
                timestamp: event.timestamp
            )))
        }

        return events
    }

    private func mapToolResultFromContent(_ event: UserStreamEvent) -> [NormalizedEvent] {
        var events: [NormalizedEvent] = []

        // Extract tool results from content blocks
        switch event.message.content {
        case .text:
            break // Simple text, not a tool result

        case .blocks(let blocks):
            for block in blocks {
                if case .toolResult(let result) = block {
                    // Find the corresponding tool call
                    if let toolState = activeToolCalls.removeValue(forKey: result.toolUseId) {
                        let duration = event.timestamp.timeIntervalSince(toolState.startTime)
                        let output = result.content?.map { $0.text }.joined(separator: "\n")

                        events.append(.toolCallComplete(ToolCallComplete(
                            toolCallId: result.toolUseId,
                            toolName: toolState.name,
                            output: output,
                            error: result.isError == true ? output : nil,
                            duration: duration,
                            timestamp: event.timestamp
                        )))
                    }
                }
            }
        }

        return events
    }

    private func mapResult(_ event: ResultStreamEvent) -> [NormalizedEvent] {
        var events: [NormalizedEvent] = []

        // Final token usage from usage field
        if let usage = event.usage {
            events.append(.tokenUsage(TokenUsage(
                inputTokens: usage.inputTokens,
                outputTokens: usage.outputTokens,
                cacheReadTokens: usage.cacheReadInputTokens,
                cacheWriteTokens: usage.cacheCreationInputTokens,
                totalTokens: usage.total,
                timestamp: event.timestamp
            )))
        }

        // Aggregate token usage from modelUsage if available
        if let modelUsage = event.modelUsage {
            var totalInput = 0
            var totalOutput = 0
            var totalCacheRead = 0
            var totalCacheWrite = 0

            for (_, model) in modelUsage {
                totalInput += model.inputTokens ?? 0
                totalOutput += model.outputTokens ?? 0
                totalCacheRead += model.cacheReadInputTokens ?? 0
                totalCacheWrite += model.cacheCreationInputTokens ?? 0
            }

            if event.usage == nil && (totalInput > 0 || totalOutput > 0) {
                events.append(.tokenUsage(TokenUsage(
                    inputTokens: totalInput,
                    outputTokens: totalOutput,
                    cacheReadTokens: totalCacheRead > 0 ? totalCacheRead : nil,
                    cacheWriteTokens: totalCacheWrite > 0 ? totalCacheWrite : nil,
                    totalTokens: totalInput + totalOutput,
                    timestamp: event.timestamp
                )))
            }
        }

        // Session ended - use top-level fields (real CLI format)
        let reason: String
        if event.success {
            reason = "completed"
        } else if let subtype = event.subtype {
            reason = subtype
        } else {
            reason = "error"
        }

        events.append(.sessionEnded(SessionEndedEvent(
            sessionId: event.sessionId,
            reason: reason,
            timestamp: event.timestamp
        )))

        return events
    }

    private func mapSummary(_ event: SummaryStreamEvent) -> [NormalizedEvent] {
        // Summary could be added to session metadata
        // For now, emit as raw
        [.raw(RawEvent(
            type: "summary",
            payload: event.summary.data(using: .utf8) ?? Data(),
            timestamp: event.timestamp
        ))]
    }

    private func mapSystem(_ event: SystemStreamEvent) -> [NormalizedEvent] {
        let msg = event.message
        let isRecoverable = msg.level != "error"

        return [.error(ErrorEvent(
            code: msg.code ?? msg.level,
            message: msg.text,
            isRecoverable: isRecoverable,
            timestamp: event.timestamp
        ))]
    }

    // MARK: - File Event Extraction

    /// Extract file events from Write/Edit tool calls
    private func extractFileEvent(from tool: ToolUseBlock) -> NormalizedEvent? {
        switch tool.name {
        case "Write":
            guard let filePath = tool.input.getString("file_path"),
                  let content = tool.input.getString("content") else {
                return nil
            }

            // For Write, we can create a simple "add all" diff
            let rawLines = content.split(separator: "\n", omittingEmptySubsequences: false)
            let diffText = rawLines.enumerated().map { "+\($1)" }.joined(separator: "\n")
            let diffLines = rawLines.enumerated().map { (index, line) in
                DiffLine(
                    type: .addition,
                    content: String(line),
                    oldLineNumber: nil,
                    newLineNumber: index + 1
                )
            }
            let hunks = [DiffHunk(
                oldStart: 0,
                oldCount: 0,
                newStart: 1,
                newCount: rawLines.count,
                lines: diffLines
            )]

            return .fileDiffProduced(FileDiffProduced(
                filePath: filePath,
                diff: "@@ -0,0 +1,\(rawLines.count) @@\n\(diffText)",
                hunks: hunks,
                timestamp: Date()
            ))

        case "Edit":
            guard let filePath = tool.input.getString("file_path"),
                  let oldString = tool.input.getString("old_string"),
                  let newString = tool.input.getString("new_string") else {
                return nil
            }

            // Create a simple edit diff
            let oldRawLines = oldString.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
            let newRawLines = newString.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }

            let removedDiff = oldRawLines.map { "-\($0)" }.joined(separator: "\n")
            let addedDiff = newRawLines.map { "+\($0)" }.joined(separator: "\n")
            let diffText = "\(removedDiff)\n\(addedDiff)"

            // Create DiffLine objects
            var diffLines: [DiffLine] = []
            for (index, line) in oldRawLines.enumerated() {
                diffLines.append(DiffLine(
                    type: .deletion,
                    content: line,
                    oldLineNumber: index + 1,
                    newLineNumber: nil
                ))
            }
            for (index, line) in newRawLines.enumerated() {
                diffLines.append(DiffLine(
                    type: .addition,
                    content: line,
                    oldLineNumber: nil,
                    newLineNumber: index + 1
                ))
            }

            let hunks = [DiffHunk(
                oldStart: 1,
                oldCount: oldRawLines.count,
                newStart: 1,
                newCount: newRawLines.count,
                lines: diffLines
            )]

            return .fileDiffProduced(FileDiffProduced(
                filePath: filePath,
                diff: "@@ -1,\(oldRawLines.count) +1,\(newRawLines.count) @@\n\(diffText)",
                hunks: hunks,
                timestamp: Date()
            ))

        case "Read":
            guard let filePath = tool.input.getString("file_path") else {
                return nil
            }

            return .fileRead(FileRead(
                filePath: filePath,
                bytesRead: 0, // Unknown until tool completes
                timestamp: Date()
            ))

        default:
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension ClaudeEventMapper {
    /// Create a stream that maps parsed events to normalized events
    static func mapStream(
        _ stream: AsyncThrowingStream<ClaudeStreamEvent, Error>
    ) -> AsyncThrowingStream<NormalizedEvent, Error> {
        let mapper = ClaudeEventMapper()

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await event in stream {
                        let normalized = await mapper.map(event)
                        for normalizedEvent in normalized {
                            continuation.yield(normalizedEvent)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
