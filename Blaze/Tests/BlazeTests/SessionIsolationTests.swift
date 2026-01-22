import XCTest
@testable import Blaze

/// Tests for session isolation (Bug 1) and unread notifications (Bug 2)
///
/// Bug 1: Session Connection Bleeding
/// - Root cause: Singleton ClaudeCodeAdapter shares PTY runner across sessions
/// - Fix: Per-session adapter instances via EngineManager registry
///
/// Bug 2: Missing Unread Notification Badge
/// - Root cause: appendEvent() never updates session.unreadCount
/// - Fix: Increment unreadCount when event arrives for non-current session
final class SessionIsolationTests: XCTestCase {

    // MARK: - Bug 1: Session Isolation Tests

    @MainActor
    func testEngineManagerCreatesPerSessionAdapter() {
        let manager = EngineManager()
        manager.register(adapter: ClaudeCodeAdapter())

        let sessionId1 = UUID()
        let sessionId2 = UUID()

        // Should get different adapter instances per session
        let adapter1 = manager.adapter(for: .claude, sessionId: sessionId1)
        let adapter2 = manager.adapter(for: .claude, sessionId: sessionId2)

        XCTAssertNotNil(adapter1, "Should return adapter for session 1")
        XCTAssertNotNil(adapter2, "Should return adapter for session 2")

        // Key assertion: adapters should be different instances
        XCTAssertFalse(adapter1 === adapter2, "Each session should get its own adapter instance")
    }

    @MainActor
    func testEngineManagerReturnsExistingAdapterForSameSession() {
        let manager = EngineManager()
        manager.register(adapter: ClaudeCodeAdapter())

        let sessionId = UUID()

        // Same session should get same adapter
        let adapter1 = manager.adapter(for: .claude, sessionId: sessionId)
        let adapter2 = manager.adapter(for: .claude, sessionId: sessionId)

        XCTAssertTrue(adapter1 === adapter2, "Same session should get same adapter instance")
    }

    @MainActor
    func testEngineManagerCleansUpAdapterWhenSessionEnds() async {
        let manager = EngineManager()
        manager.register(adapter: ClaudeCodeAdapter())

        let sessionId = UUID()

        // Get adapter
        let adapter = manager.adapter(for: .claude, sessionId: sessionId)
        XCTAssertNotNil(adapter)

        // Cleanup session
        await manager.cleanupSession(sessionId)

        // Verify cleanup
        XCTAssertFalse(manager.hasAdapter(for: sessionId), "Adapter should be cleaned up after session ends")
    }

    @MainActor
    func testSessionOrchestratorUsesSessionSpecificAdapter() async throws {
        let engineManager = EngineManager()
        engineManager.register(adapter: ClaudeCodeAdapter())

        let orchestrator = SessionOrchestrator(engineManager: engineManager)

        let session1 = Session(name: "Session 1", projectPath: "/tmp")
        let session2 = Session(name: "Session 2", projectPath: "/tmp")

        // When orchestrator prepares for sessions, they should use different adapters
        // This test validates the adapter lookup path uses session-specific adapters

        let adapter1 = orchestrator.getAdapter(for: session1)
        let adapter2 = orchestrator.getAdapter(for: session2)

        XCTAssertFalse(adapter1 === adapter2, "Sessions should use different adapters")
    }

    // MARK: - Bug 2: Unread Notification Tests

    @MainActor
    func testAppendEventIncrementsUnreadCountForBackgroundSession() {
        let appState = createTestAppState()

        // Create two sessions
        let session1 = Session(name: "Session 1", projectPath: "/tmp")
        let session2 = Session(name: "Session 2", projectPath: "/tmp")

        appState.sessions = [session1, session2]
        appState.currentSessionId = session1.id  // Session 1 is current

        // Initial unread count should be 0
        XCTAssertEqual(appState.sessions[1].unreadCount, 0, "Session 2 should start with 0 unread")

        // Append event to session 2 (background session)
        let event = NormalizedEvent.assistantDelta(AssistantDelta(text: "Hello", timestamp: Date()))
        appState.appendEvent(event, to: session2.id)

        // Session 2's unread count should increment
        XCTAssertEqual(appState.sessions[1].unreadCount, 1, "Session 2 should have 1 unread after event")
    }

    @MainActor
    func testAppendEventDoesNotIncrementUnreadForCurrentSession() {
        let appState = createTestAppState()

        let session = Session(name: "Session 1", projectPath: "/tmp")
        appState.sessions = [session]
        appState.currentSessionId = session.id

        // Append event to current session
        let event = NormalizedEvent.assistantDelta(AssistantDelta(text: "Hello", timestamp: Date()))
        appState.appendEvent(event, to: session.id)

        // Unread count should remain 0 for current session
        XCTAssertEqual(appState.sessions[0].unreadCount, 0, "Current session should not increment unread")
    }

    @MainActor
    func testSwitchingToSessionClearsUnreadCount() {
        let appState = createTestAppState()

        // Create two sessions
        let session1 = Session(name: "Session 1", projectPath: "/tmp")
        var session2 = Session(name: "Session 2", projectPath: "/tmp")
        session2.unreadCount = 5  // Session 2 has unread messages

        appState.sessions = [session1, session2]
        appState.currentSessionId = session1.id

        // Verify session 2 has unread
        XCTAssertEqual(appState.sessions[1].unreadCount, 5, "Session 2 should have 5 unread")

        // Switch to session 2
        appState.currentSessionId = session2.id

        // Session 2's unread count should be cleared
        XCTAssertEqual(appState.sessions[1].unreadCount, 0, "Switching to session should clear unread")
    }

    @MainActor
    func testMultipleEventsIncrementUnreadCorrectly() {
        let appState = createTestAppState()

        let session1 = Session(name: "Session 1", projectPath: "/tmp")
        let session2 = Session(name: "Session 2", projectPath: "/tmp")

        appState.sessions = [session1, session2]
        appState.currentSessionId = session1.id

        // Append multiple events to background session
        for i in 0..<5 {
            let event = NormalizedEvent.assistantDelta(
                AssistantDelta(text: "Message \(i)", timestamp: Date())
            )
            appState.appendEvent(event, to: session2.id)
        }

        // Should have 5 unread
        XCTAssertEqual(appState.sessions[1].unreadCount, 5, "Should accumulate unread count")
    }

    @MainActor
    func testUnreadCountOnlyIncrementedForVisibleEvents() {
        let appState = createTestAppState()

        let session1 = Session(name: "Session 1", projectPath: "/tmp")
        let session2 = Session(name: "Session 2", projectPath: "/tmp")

        appState.sessions = [session1, session2]
        appState.currentSessionId = session1.id

        // Append assistant delta (should increment)
        let assistantEvent = NormalizedEvent.assistantDelta(
            AssistantDelta(text: "Hello", timestamp: Date())
        )
        appState.appendEvent(assistantEvent, to: session2.id)

        // Append tool call started (should also increment - it's UI-visible)
        let toolEvent = NormalizedEvent.toolCallStarted(
            ToolCallStarted(
                toolCallId: "123",
                toolName: "Bash",
                input: "ls",
                timestamp: Date()
            )
        )
        appState.appendEvent(toolEvent, to: session2.id)

        // Both should count
        XCTAssertEqual(appState.sessions[1].unreadCount, 2, "Visible events should increment unread")
    }

    // MARK: - Helper Methods

    @MainActor
    private func createTestAppState() -> AppState {
        return AppState(
            sessionStore: nil,
            eventStore: nil,
            tokenStore: nil,
            logStore: nil,
            hookExecutionStore: nil,
            engineManager: EngineManager(),
            orchestrator: nil,
            diffService: nil,
            terminalManager: nil
        )
    }
}
