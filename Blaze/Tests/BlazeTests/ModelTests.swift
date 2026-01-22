import XCTest
import GRDB
@testable import Blaze

final class BlazeTests: XCTestCase {

    // MARK: - Session Tests

    func testSessionCreation() {
        let session = Session(name: "Test Session")

        XCTAssertFalse(session.id.uuidString.isEmpty)
        XCTAssertEqual(session.name, "Test Session")
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(session.engineType, .claude)
        XCTAssertTrue(session.messages.isEmpty)
    }

    func testSessionStateTransitions() {
        var session = Session(name: "Test")

        // Idle -> Preparing
        session.state = .preparing
        XCTAssertEqual(session.state, .preparing)

        // Preparing -> Streaming
        session.state = .streaming
        XCTAssertEqual(session.state, .streaming)

        // Streaming -> ToolPending
        session.state = .toolPending
        XCTAssertEqual(session.state, .toolPending)

        // ToolPending -> ToolExecuting
        session.state = .toolExecuting
        XCTAssertEqual(session.state, .toolExecuting)

        // ToolExecuting -> Idle (complete)
        session.state = .idle
        XCTAssertEqual(session.state, .idle)
    }

    // MARK: - Message Tests

    func testMessageCreation() {
        let message = Message(role: .user, content: "Hello")

        XCTAssertFalse(message.id.uuidString.isEmpty)
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertTrue(message.toolCalls.isEmpty)
    }

    func testAssistantMessage() {
        let message = Message(role: .assistant, content: "I can help with that")

        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "I can help with that")
    }

    // MARK: - ToolCall Tests

    func testToolCallCreation() {
        let toolCall = ToolCall(name: "Read", input: "{\"path\": \"/file.txt\"}")

        XCTAssertEqual(toolCall.name, "Read")
        XCTAssertEqual(toolCall.status, .pending)
        XCTAssertNil(toolCall.output)
        XCTAssertNil(toolCall.duration)
    }

    func testToolCallDuration() {
        var toolCall = ToolCall(name: "Bash", input: "ls -la")
        toolCall.completedAt = toolCall.startedAt.addingTimeInterval(2.5)

        XCTAssertNotNil(toolCall.duration)
        XCTAssertEqual(toolCall.duration!, 2.5, accuracy: 0.001)
    }

    // MARK: - FileDiff Tests

    func testFileDiffStats() {
        let hunk = DiffHunk(
            oldStart: 1,
            oldCount: 3,
            newStart: 1,
            newCount: 5,
            lines: [
                DiffLine(type: .context, content: "line 1", oldLineNumber: 1, newLineNumber: 1),
                DiffLine(type: .deletion, content: "old line", oldLineNumber: 2, newLineNumber: nil),
                DiffLine(type: .addition, content: "new line 1", oldLineNumber: nil, newLineNumber: 2),
                DiffLine(type: .addition, content: "new line 2", oldLineNumber: nil, newLineNumber: 3),
                DiffLine(type: .context, content: "line 3", oldLineNumber: 3, newLineNumber: 4),
            ]
        )

        let diff = FileDiff(filePath: "/src/file.swift", hunks: [hunk])

        XCTAssertEqual(diff.stats.additions, 2)
        XCTAssertEqual(diff.stats.deletions, 1)
        XCTAssertEqual(diff.stats.total, 3)
        XCTAssertEqual(diff.decision, .pending)
    }

    // MARK: - TrustMode Tests

    func testTrustModeDisplayNames() {
        XCTAssertEqual(TrustMode.lockedDown.displayName, "Locked Down")
        XCTAssertEqual(TrustMode.prompt.displayName, "Prompt")
        XCTAssertEqual(TrustMode.allowlisted.displayName, "Allowlisted")
        XCTAssertEqual(TrustMode.unrestricted.displayName, "Unrestricted")

        // Legacy aliases still work
        XCTAssertEqual(TrustMode.sandbox.displayName, "Locked Down")
        XCTAssertEqual(TrustMode.review.displayName, "Prompt")
        XCTAssertEqual(TrustMode.trusted.displayName, "Unrestricted")
    }

    // MARK: - EngineType Tests

    func testEngineTypeCommands() {
        XCTAssertEqual(EngineType.claude.cliCommand, "claude")
        XCTAssertEqual(EngineType.gemini.cliCommand, "gemini")
        XCTAssertEqual(EngineType.codex.cliCommand, "codex")
    }

    // MARK: - Unread Count Tests (E005-F002-S001-T002-A001)

    func testSessionUnreadCountDefaultsToZero() {
        let session = Session(name: "Test Session")
        XCTAssertEqual(session.unreadCount, 0)
    }

    func testSessionUnreadCountCanBeSet() {
        var session = Session(name: "Test Session")
        session.unreadCount = 5
        XCTAssertEqual(session.unreadCount, 5)
    }

    func testSessionUnreadCountPersistsAfterModification() {
        var session = Session(name: "Test Session")
        session.unreadCount = 10
        session.unreadCount += 2
        XCTAssertEqual(session.unreadCount, 12)
    }
}
