import XCTest
import GRDB
@testable import Blaze

final class EventNormalizationTests: XCTestCase {

    // MARK: - Required Fields Tests

    /// Test: Normalize event with missing session_id and verify injection
    func testNormalizeEventInjectsSessionId() async {
        let defaultSessionId = UUID().uuidString
        let normalizer = EventNormalizer(defaultSessionId: defaultSessionId)

        let event = NormalizedEvent.assistantDelta(AssistantDelta(
            text: "Hello",
            timestamp: Date()
        ))

        // Normalize without providing explicit session ID
        let envelope = await normalizer.normalize(event)

        // Should have injected the default session ID
        XCTAssertEqual(envelope.sessionId.uuidString, defaultSessionId)
        XCTAssertNotNil(envelope.id)
        XCTAssertEqual(envelope.sequence, 0)
    }

    /// Test: Normalize event with explicit session_id preserves it
    func testNormalizeEventPreservesExplicitSessionId() async {
        let defaultSessionId = UUID().uuidString
        let normalizer = EventNormalizer(defaultSessionId: defaultSessionId)

        let explicitSessionId = UUID()
        let event = NormalizedEvent.assistantComplete(AssistantComplete(
            fullText: "Response",
            timestamp: Date(),
            stopReason: .endTurn
        ))

        let envelope = await normalizer.normalize(event, sessionId: explicitSessionId)

        // Should use explicit session ID, not default
        XCTAssertEqual(envelope.sessionId, explicitSessionId)
        XCTAssertNotEqual(envelope.sessionId.uuidString, defaultSessionId)
    }

    /// Test: Verify payload preserved after normalization
    func testNormalizeEventPreservesPayload() async {
        let normalizer = EventNormalizer(defaultSessionId: UUID().uuidString)

        let originalText = "This is the original message content"
        let event = NormalizedEvent.assistantDelta(AssistantDelta(
            text: originalText,
            timestamp: Date()
        ))

        let envelope = await normalizer.normalize(event)

        // Verify payload is preserved
        if case .assistantDelta(let delta) = envelope.event {
            XCTAssertEqual(delta.text, originalText)
        } else {
            XCTFail("Event type should be preserved")
        }
    }

    // MARK: - Event Type Tests

    func testEventTypeDiscriminator() {
        // Test all event types have correct type discriminator
        let events: [(NormalizedEvent, NormalizedEventType)] = [
            (.assistantDelta(AssistantDelta(text: "", timestamp: Date())), .assistantDelta),
            (.assistantComplete(AssistantComplete(fullText: "", timestamp: Date(), stopReason: nil)), .assistantComplete),
            (.thinkingDelta(ThinkingDelta(text: "", timestamp: Date())), .thinkingDelta),
            (.toolCallStarted(ToolCallStarted(toolCallId: "", toolName: "", input: "", timestamp: Date())), .toolCallStarted),
            (.toolCallComplete(ToolCallComplete(toolCallId: "", toolName: "", output: nil, error: nil, duration: 0, timestamp: Date())), .toolCallComplete),
            (.toolRequest(ToolRequestEvent(toolCallId: "", toolName: "", input: "", riskLevel: .low)), .toolRequest),
            (.toolDecision(ToolDecisionEvent(toolRequestId: UUID(), decision: .approved, decidedBy: "user")), .toolDecision),
            (.toolResult(ToolResultEvent(toolRequestId: UUID(), toolCallId: "", toolName: "", durationMs: 0)), .toolResult),
            (.sessionStarted(SessionStartedEvent(sessionId: "", engineType: "", timestamp: Date())), .sessionStarted),
            (.sessionEnded(SessionEndedEvent(sessionId: "", reason: "", timestamp: Date())), .sessionEnded),
            (.error(ErrorEvent(code: "", message: "", isRecoverable: true, timestamp: Date())), .error),
            (.tokenUsage(TokenUsage(inputTokens: 0, outputTokens: 0, cacheReadTokens: nil, cacheWriteTokens: nil, totalTokens: 0, timestamp: Date())), .tokenUsage),
            (.raw(RawEvent(type: "test", payload: Data())), .raw),
        ]

        for (event, expectedType) in events {
            XCTAssertEqual(event.eventType, expectedType, "Event type mismatch for \(expectedType)")
        }
    }

    func testEventTimestampExtraction() {
        let timestamp = Date()

        let events: [NormalizedEvent] = [
            .assistantDelta(AssistantDelta(text: "", timestamp: timestamp)),
            .assistantComplete(AssistantComplete(fullText: "", timestamp: timestamp, stopReason: nil)),
            .thinkingDelta(ThinkingDelta(text: "", timestamp: timestamp)),
            .toolCallStarted(ToolCallStarted(toolCallId: "", toolName: "", input: "", timestamp: timestamp)),
            .toolCallComplete(ToolCallComplete(toolCallId: "", toolName: "", output: nil, error: nil, duration: 0, timestamp: timestamp)),
            .toolRequest(ToolRequestEvent(toolCallId: "", toolName: "", input: "", riskLevel: .low, timestamp: timestamp)),
            .toolDecision(ToolDecisionEvent(toolRequestId: UUID(), decision: .approved, decidedBy: "user", timestamp: timestamp)),
            .toolResult(ToolResultEvent(toolRequestId: UUID(), toolCallId: "", toolName: "", durationMs: 0, timestamp: timestamp)),
        ]

        for event in events {
            XCTAssertEqual(event.eventTimestamp, timestamp, "Timestamp should be extractable from \(event.eventType)")
        }
    }

    // MARK: - Sequence Tests

    func testNormalizerMaintainsSequence() async {
        let normalizer = EventNormalizer(defaultSessionId: UUID().uuidString)

        let event = NormalizedEvent.assistantDelta(AssistantDelta(text: "", timestamp: Date()))

        let envelope1 = await normalizer.normalize(event)
        let envelope2 = await normalizer.normalize(event)
        let envelope3 = await normalizer.normalize(event)

        XCTAssertEqual(envelope1.sequence, 0)
        XCTAssertEqual(envelope2.sequence, 1)
        XCTAssertEqual(envelope3.sequence, 2)
    }

    func testNormalizerResetClearsSequence() async {
        let normalizer = EventNormalizer(defaultSessionId: UUID().uuidString)

        let event = NormalizedEvent.assistantDelta(AssistantDelta(text: "", timestamp: Date()))

        _ = await normalizer.normalize(event)
        _ = await normalizer.normalize(event)

        let seqBefore = await normalizer.currentSequence
        XCTAssertEqual(seqBefore, 2)

        await normalizer.reset()

        let seqAfter = await normalizer.currentSequence
        XCTAssertEqual(seqAfter, 0)

        let envelope = await normalizer.normalize(event)
        XCTAssertEqual(envelope.sequence, 0)
    }

    // MARK: - Tool Approval Event Tests

    func testToolRequestEventCreation() {
        let request = ToolRequestEvent(
            toolCallId: "toolu_123",
            toolName: "Bash",
            input: "ls -la",
            riskLevel: .high,
            scope: ToolScope(commands: ["ls"])
        )

        XCTAssertEqual(request.toolName, "Bash")
        XCTAssertEqual(request.riskLevel, .high)
        XCTAssertEqual(request.scope?.commands, ["ls"])
    }

    func testToolDecisionEventCreation() {
        let requestId = UUID()
        let decision = ToolDecisionEvent(
            toolRequestId: requestId,
            decision: .rejected,
            decidedBy: "user",
            rationale: "Too risky"
        )

        XCTAssertEqual(decision.toolRequestId, requestId)
        XCTAssertEqual(decision.decision, .rejected)
        XCTAssertEqual(decision.rationale, "Too risky")
    }

    func testToolResultEventCreation() {
        let requestId = UUID()
        let result = ToolResultEvent(
            toolRequestId: requestId,
            toolCallId: "toolu_123",
            toolName: "Read",
            output: "File contents",
            durationMs: 150
        )

        XCTAssertEqual(result.toolRequestId, requestId)
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.durationMs, 150)
    }

    func testToolResultEventWithError() {
        let result = ToolResultEvent(
            toolRequestId: UUID(),
            toolCallId: "toolu_456",
            toolName: "Write",
            error: "Permission denied",
            durationMs: 50
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.error, "Permission denied")
    }

    // MARK: - Envelope Tests

    func testEnvelopeHasEventType() {
        let envelope = EventEnvelope(
            sessionId: UUID(),
            sequence: 0,
            event: .assistantDelta(AssistantDelta(text: "", timestamp: Date()))
        )

        XCTAssertEqual(envelope.eventType, .assistantDelta)
    }
}

// MARK: - Tool Approval Pipeline Tests (Atom A003)

/// Tests for tool approval pipeline per Phase 2 System Contract

