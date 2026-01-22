import XCTest
import GRDB
@testable import Blaze

final class ClaudeEventMapperTests: XCTestCase {

    // MARK: - Init Event Mapping

    func testMapInitEvent() async {
        let mapper = ClaudeEventMapper()
        let initEvent = InitStreamEvent(
            type: "init",
            version: "1.0.58",
            message: .init(
                sessionId: "session-123",
                version: "1.0.58",
                model: "claude-opus-4",
                cwd: "/project",
                capabilities: ["streaming", "tools"],
                allowedTools: ["Bash", "Read"]
            ),
            uuid: "test-uuid",
            sessionId: "session-123",
            parentUuid: nil,
            isSidechain: nil
        )

        let events = await mapper.map(.`init`(initEvent))

        XCTAssertEqual(events.count, 1)
        if case .sessionStarted(let started) = events.first {
            XCTAssertEqual(started.sessionId, "session-123")
            XCTAssertEqual(started.engineType, "claude")
        } else {
            XCTFail("Expected sessionStarted event")
        }
    }

    // MARK: - Assistant Event Mapping

    func testMapAssistantTextDelta() async {
        let mapper = ClaudeEventMapper()

        // First assistant event with partial text
        let event1 = createAssistantEvent(
            messageId: "msg-1",
            content: [.text(TextBlock(type: "text", text: "Hello "))],
            stopReason: nil
        )
        var events = await mapper.map(.assistant(event1))

        // Should emit delta
        XCTAssertTrue(events.contains { if case .assistantDelta = $0 { return true }; return false })

        // Second event with more text
        let event2 = createAssistantEvent(
            messageId: "msg-1",
            content: [.text(TextBlock(type: "text", text: "Hello world!"))],
            stopReason: nil
        )
        events = await mapper.map(.assistant(event2))

        // Should emit delta for new text
        let hasDelta = events.contains {
            if case .assistantDelta(let delta) = $0 {
                return delta.text == "world!"
            }
            return false
        }
        XCTAssertTrue(hasDelta, "Should emit delta for new text")
    }

    func testMapAssistantComplete() async {
        let mapper = ClaudeEventMapper()

        let event = createAssistantEvent(
            messageId: "msg-1",
            content: [.text(TextBlock(type: "text", text: "Complete response"))],
            stopReason: "end_turn"
        )
        let events = await mapper.map(.assistant(event))

        let hasComplete = events.contains {
            if case .assistantComplete(let complete) = $0 {
                return complete.fullText == "Complete response" && complete.stopReason == .endTurn
            }
            return false
        }
        XCTAssertTrue(hasComplete, "Should emit assistantComplete with end_turn")
    }

    // MARK: - Tool Call Mapping

    func testMapToolCallStarted() async {
        let mapper = ClaudeEventMapper()

        let toolInput = ToolInput.from(dict: ["file_path": "/test.txt", "content": "Hello"])
        let event = createAssistantEvent(
            messageId: "msg-1",
            content: [
                .text(TextBlock(type: "text", text: "Creating file")),
                .toolUse(ToolUseBlock(type: "tool_use", id: "toolu_123", name: "Write", input: toolInput))
            ],
            stopReason: "tool_use"
        )
        let events = await mapper.map(.assistant(event))

        let hasToolStarted = events.contains {
            if case .toolCallStarted(let started) = $0 {
                return started.toolCallId == "toolu_123" && started.toolName == "Write"
            }
            return false
        }
        XCTAssertTrue(hasToolStarted, "Should emit toolCallStarted")
    }

    func testMapWriteProducesFileDiff() async {
        let mapper = ClaudeEventMapper()

        let toolInput = ToolInput.from(dict: ["file_path": "/src/hello.swift", "content": "import Foundation\nprint(\"Hello\")"])
        let event = createAssistantEvent(
            messageId: "msg-1",
            content: [.toolUse(ToolUseBlock(type: "tool_use", id: "toolu_123", name: "Write", input: toolInput))],
            stopReason: "tool_use"
        )
        let events = await mapper.map(.assistant(event))

        let hasFileDiff = events.contains {
            if case .fileDiffProduced(let diff) = $0 {
                return diff.filePath == "/src/hello.swift" && diff.hunks.count > 0
            }
            return false
        }
        XCTAssertTrue(hasFileDiff, "Write tool should produce fileDiffProduced event")
    }

    func testMapEditProducesFileDiff() async {
        let mapper = ClaudeEventMapper()

        let toolInput = ToolInput.from(dict: [
            "file_path": "/src/main.swift",
            "old_string": "let x = 1",
            "new_string": "let x = 42"
        ])
        let event = createAssistantEvent(
            messageId: "msg-1",
            content: [.toolUse(ToolUseBlock(type: "tool_use", id: "toolu_456", name: "Edit", input: toolInput))],
            stopReason: "tool_use"
        )
        let events = await mapper.map(.assistant(event))

        let hasFileDiff = events.contains {
            if case .fileDiffProduced(let diff) = $0 {
                return diff.filePath == "/src/main.swift"
            }
            return false
        }
        XCTAssertTrue(hasFileDiff, "Edit tool should produce fileDiffProduced event")
    }

    // MARK: - Result Event Mapping

    func testMapResultEvent() async {
        let mapper = ClaudeEventMapper()

        // Use new real CLI format
        let resultEvent = ResultStreamEvent(
            type: "result",
            subtype: "success",
            uuid: "result-1",
            sessionId: "session-123",
            result: "Task completed",
            isError: false,
            durationMs: 5000,
            durationApiMs: 6000,
            numTurns: 3,
            totalCostUsd: 0.02,
            usage: UsageStats(inputTokens: 1000, outputTokens: 500, cacheCreationInputTokens: 0, cacheReadInputTokens: 0, totalTokens: 1500, serviceTier: nil),
            modelUsage: nil,
            permissionDenials: nil
        )

        let events = await mapper.map(.result(resultEvent))

        // Should have tokenUsage and sessionEnded
        let hasUsage = events.contains { if case .tokenUsage = $0 { return true }; return false }
        let hasEnded = events.contains {
            if case .sessionEnded(let ended) = $0 {
                return ended.sessionId == "session-123" && ended.reason == "completed"
            }
            return false
        }
        XCTAssertTrue(hasUsage, "Should emit tokenUsage")
        XCTAssertTrue(hasEnded, "Should emit sessionEnded")
    }

    // MARK: - System Event Mapping

    func testMapSystemErrorEvent() async {
        let mapper = ClaudeEventMapper()

        let systemEvent = SystemStreamEvent(
            type: "system",
            message: .init(level: "error", text: "Rate limit exceeded", code: "rate_limit_error", details: nil),
            uuid: "sys-1",
            sessionId: "session-123",
            parentUuid: nil,
            isSidechain: nil
        )

        let events = await mapper.map(.system(systemEvent))

        let hasError = events.contains {
            if case .error(let err) = $0 {
                return err.code == "rate_limit_error" && err.message == "Rate limit exceeded"
            }
            return false
        }
        XCTAssertTrue(hasError, "Should emit error event")
    }

    // MARK: - Helpers

    private func createAssistantEvent(
        messageId: String,
        content: [AssistantContentBlock],
        stopReason: String?
    ) -> AssistantStreamEvent {
        AssistantStreamEvent(
            type: "assistant",
            message: .init(
                id: messageId,
                type: "message",
                role: "assistant",
                model: "claude-opus-4",
                content: content,
                stopReason: stopReason,
                stopSequence: nil,
                usage: UsageStats(inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, totalTokens: 150, serviceTier: nil)
            ),
            uuid: UUID().uuidString,
            sessionId: "session-123",
            parentUuid: nil,
            isSidechain: nil,
            requestId: "req-1"
        )
    }
}

// MARK: - ToolInput Test Helper

private extension ToolInput {
    static func from(dict: [String: String]) -> ToolInput {
        var anyCodable: [String: AnyCodable] = [:]
        for (key, value) in dict {
            anyCodable[key] = AnyCodable(value)
        }
        return ToolInput(rawValue: anyCodable)
    }
}
