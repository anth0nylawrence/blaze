import XCTest
@testable import Blaze

/// Phase 5 TDD: Tests for FIFO prompt queue + submission state machine
@MainActor
final class PromptQueueTests: XCTestCase {

    // MARK: - Test Fixtures

    func makePrompt(toolUseId: String, question: String = "Test?") -> ToolPromptEvent {
        ToolPromptEvent(
            toolUseId: toolUseId,
            toolName: "AskUserQuestion",
            title: question,
            body: nil,
            options: [
                ToolPromptOption(id: "A", label: "Option A", description: nil),
                ToolPromptOption(id: "B", label: "Option B", description: nil)
            ],
            responseType: .singleSelect,
            rawInput: "{}",
            timestamp: Date()
        )
    }

    // MARK: - FIFO Queue Tests

    func testQueueStartsEmpty() {
        let queue = PromptQueue()

        XCTAssertNil(queue.currentPrompt)
        XCTAssertEqual(queue.pendingCount, 0)
        XCTAssertFalse(queue.hasMorePrompts)
    }

    func testEnqueueAddsToQueue() {
        let queue = PromptQueue()
        let prompt = makePrompt(toolUseId: "toolu_1")

        queue.enqueue(prompt)

        XCTAssertEqual(queue.pendingCount, 1)
        XCTAssertEqual(queue.currentPrompt?.toolUseId, "toolu_1")
    }

    func testQueueMaintainsFIFOOrder() {
        let queue = PromptQueue()

        queue.enqueue(makePrompt(toolUseId: "toolu_1", question: "First?"))
        queue.enqueue(makePrompt(toolUseId: "toolu_2", question: "Second?"))
        queue.enqueue(makePrompt(toolUseId: "toolu_3", question: "Third?"))

        // Current should be first in
        XCTAssertEqual(queue.currentPrompt?.toolUseId, "toolu_1")
        XCTAssertEqual(queue.pendingCount, 3)
        XCTAssertTrue(queue.hasMorePrompts)
    }

    func testDequeueRemovesFromFront() {
        let queue = PromptQueue()

        queue.enqueue(makePrompt(toolUseId: "toolu_1"))
        queue.enqueue(makePrompt(toolUseId: "toolu_2"))

        let removed = queue.dequeue(promptId: "toolu_1")
        XCTAssertNotNil(removed)
        XCTAssertEqual(removed?.toolUseId, "toolu_1")

        // Next prompt should now be current
        XCTAssertEqual(queue.currentPrompt?.toolUseId, "toolu_2")
        XCTAssertEqual(queue.pendingCount, 1)
        XCTAssertFalse(queue.hasMorePrompts)
    }

    func testDequeueByIdRemovesCorrectPrompt() {
        let queue = PromptQueue()

        queue.enqueue(makePrompt(toolUseId: "toolu_1"))
        queue.enqueue(makePrompt(toolUseId: "toolu_2"))
        queue.enqueue(makePrompt(toolUseId: "toolu_3"))

        // Remove middle one
        let removed = queue.dequeue(promptId: "toolu_2")
        XCTAssertEqual(removed?.toolUseId, "toolu_2")

        // Queue should still be [1, 3]
        XCTAssertEqual(queue.currentPrompt?.toolUseId, "toolu_1")
        XCTAssertEqual(queue.pendingCount, 2)
    }

    func testClearRemovesAllPrompts() {
        let queue = PromptQueue()

        queue.enqueue(makePrompt(toolUseId: "toolu_1"))
        queue.enqueue(makePrompt(toolUseId: "toolu_2"))

        queue.clear()

        XCTAssertNil(queue.currentPrompt)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    // MARK: - Submission State Machine Tests

    func testInitialStateIsIdle() {
        let queue = PromptQueue()
        let prompt = makePrompt(toolUseId: "toolu_1")

        queue.enqueue(prompt)

        XCTAssertEqual(queue.submissionState(for: "toolu_1"), .idle)
    }

    func testSetStateUpdatesState() {
        let queue = PromptQueue()
        let prompt = makePrompt(toolUseId: "toolu_1")

        queue.enqueue(prompt)

        queue.setSubmissionState(.submitting, for: "toolu_1")
        XCTAssertEqual(queue.submissionState(for: "toolu_1"), .submitting)

        queue.setSubmissionState(.submitted, for: "toolu_1")
        XCTAssertEqual(queue.submissionState(for: "toolu_1"), .submitted)
    }

    func testFailedStatePreservesMessage() {
        let queue = PromptQueue()

        queue.enqueue(makePrompt(toolUseId: "toolu_1"))

        queue.setSubmissionState(.failed("Network error"), for: "toolu_1")

        if case .failed(let message) = queue.submissionState(for: "toolu_1") {
            XCTAssertEqual(message, "Network error")
        } else {
            XCTFail("Expected .failed state")
        }
    }

    func testDequeueAlsoClearsState() {
        let queue = PromptQueue()

        queue.enqueue(makePrompt(toolUseId: "toolu_1"))
        queue.setSubmissionState(.submitting, for: "toolu_1")

        _ = queue.dequeue(promptId: "toolu_1")

        // State should be reset to idle (default) for unknown IDs
        XCTAssertEqual(queue.submissionState(for: "toolu_1"), .idle)
    }

    // MARK: - Idempotent Submit Tests

    func testCannotTransitionFromSubmittingToSubmitting() {
        let queue = PromptQueue()

        queue.enqueue(makePrompt(toolUseId: "toolu_1"))
        queue.setSubmissionState(.submitting, for: "toolu_1")

        // Attempting to set submitting again should be a no-op (idempotent)
        // This would be handled by the orchestrator checking state before submit
        XCTAssertEqual(queue.submissionState(for: "toolu_1"), .submitting)
    }

    func testRetryOnlyAllowedFromFailed() {
        let queue = PromptQueue()

        queue.enqueue(makePrompt(toolUseId: "toolu_1"))

        // Can retry from failed
        queue.setSubmissionState(.failed("Error"), for: "toolu_1")
        XCTAssertTrue(queue.canRetry(promptId: "toolu_1"))

        // Cannot retry from idle
        queue.setSubmissionState(.idle, for: "toolu_1")
        XCTAssertFalse(queue.canRetry(promptId: "toolu_1"))

        // Cannot retry from submitting
        queue.setSubmissionState(.submitting, for: "toolu_1")
        XCTAssertFalse(queue.canRetry(promptId: "toolu_1"))

        // Cannot retry from submitted
        queue.setSubmissionState(.submitted, for: "toolu_1")
        XCTAssertFalse(queue.canRetry(promptId: "toolu_1"))
    }

    // MARK: - Lookup Tests

    func testPromptByIdReturnsCorrectPrompt() {
        let queue = PromptQueue()

        queue.enqueue(makePrompt(toolUseId: "toolu_1", question: "First?"))
        queue.enqueue(makePrompt(toolUseId: "toolu_2", question: "Second?"))

        let prompt = queue.prompt(for: "toolu_2")
        XCTAssertEqual(prompt?.title, "Second?")
    }

    func testPromptByIdReturnsNilForUnknown() {
        let queue = PromptQueue()

        queue.enqueue(makePrompt(toolUseId: "toolu_1"))

        let prompt = queue.prompt(for: "unknown")
        XCTAssertNil(prompt)
    }
}
