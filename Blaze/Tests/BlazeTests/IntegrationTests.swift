import XCTest
import GRDB
@testable import Blaze

final class RealCLIIntegrationTests: XCTestCase {

    /// Test parsing the exact output captured from `claude -p "..." --output-format stream-json --verbose`
    func testParseRealCLIOutput() async {
        let parser = NDJSONParser()

        // Exact output from Claude CLI 2.0.76 - each line needs explicit newline
        let lines = [
            #"{"type":"system","subtype":"hook_response","session_id":"6873ad3f-7ff2-4c81-8b56-bc0c5c3f6f8a","uuid":"ac889f83-5e51-45e3-bab1-1fc1cccf41d3","hook_name":"SessionStart:startup","hook_event":"SessionStart","stdout":"","stderr":"","exit_code":0}"#,
            #"{"type":"system","subtype":"init","cwd":"/Users/test/project","session_id":"6873ad3f-7ff2-4c81-8b56-bc0c5c3f6f8a","uuid":"init-uuid","tools":["Task","Bash"],"model":"claude-opus-4-5-20251101"}"#,
            #"{"type":"assistant","message":{"model":"claude-opus-4-5-20251101","id":"msg_012jpfdpx7Y5SHTvJAjpX8bY","type":"message","role":"assistant","content":[{"type":"text","text":"hello"}],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":1}}}"#,
            #"{"type":"result","subtype":"success","is_error":false,"duration_ms":5653,"result":"hello","session_id":"6873ad3f-7ff2-4c81-8b56-bc0c5c3f6f8a","uuid":"result-uuid","total_cost_usd":0.118,"num_turns":1}"#
        ]
        let realOutput = lines.joined(separator: "\n") + "\n"

        let data = Data(realOutput.utf8)
        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 4, "Should parse all 4 real CLI events")

        // Event 1: Hook response
        if case .hookResponse(let hook) = events[0] {
            XCTAssertEqual(hook.hookEvent, "SessionStart")
            XCTAssertEqual(hook.exitCode, 0)
        } else {
            XCTFail("Expected hookResponse event, got \(events[0])")
        }

        // Event 2: System init
        if case .systemInit(let init_) = events[1] {
            XCTAssertEqual(init_.sessionId, "6873ad3f-7ff2-4c81-8b56-bc0c5c3f6f8a")
            XCTAssertEqual(init_.model, "claude-opus-4-5-20251101")
            XCTAssertEqual(init_.cwd, "/Users/test/project")
            XCTAssertEqual(init_.tools, ["Task", "Bash"])
        } else {
            XCTFail("Expected systemInit event, got \(events[1])")
        }

        // Event 3: Assistant message
        if case .assistant(let asst) = events[2] {
            XCTAssertEqual(asst.message.id, "msg_012jpfdpx7Y5SHTvJAjpX8bY")
            XCTAssertEqual(asst.message.model, "claude-opus-4-5-20251101")
            if case .text(let textBlock) = asst.message.content.first {
                XCTAssertEqual(textBlock.text, "hello")
            } else {
                XCTFail("Expected text content block")
            }
        } else {
            XCTFail("Expected assistant event, got \(events[2])")
        }

        // Event 4: Result
        if case .result(let result) = events[3] {
            XCTAssertEqual(result.subtype, "success")
            XCTAssertEqual(result.isError, false)
            XCTAssertTrue(result.success)
            XCTAssertEqual(result.result, "hello")
            XCTAssertEqual(result.durationMs, 5653)
            XCTAssertEqual(result.totalCostUsd, 0.118)
            XCTAssertEqual(result.numTurns, 1)
        } else {
            XCTFail("Expected result event, got \(events[3])")
        }
    }

    /// Test the mapper produces correct normalized events from real CLI output
    func testMapRealCLIOutput() async {
        let parser = NDJSONParser()
        let mapper = ClaudeEventMapper()

        // Parse system init - include all required fields
        let initJson = #"{"type":"system","subtype":"init","cwd":"/project","session_id":"test-session","uuid":"init-uuid","tools":["Bash"],"model":"claude-opus-4-5"}"#
        let initEvents = await parser.parse(chunk: Data((initJson + "\n").utf8))
        XCTAssertEqual(initEvents.count, 1)

        let normalizedInit = await mapper.map(initEvents[0])
        let hasSessionStarted = normalizedInit.contains {
            if case .sessionStarted(let started) = $0 {
                return started.sessionId == "test-session" && started.engineType == "claude"
            }
            return false
        }
        XCTAssertTrue(hasSessionStarted, "System init should produce sessionStarted event")

        // Parse hook response
        let hookJson = #"{"type":"system","subtype":"hook_response","session_id":"test","uuid":"uuid-1","hook_name":"Test","hook_event":"TestEvent","stdout":"","stderr":"","exit_code":0}"#
        let hookEvents = await parser.parse(chunk: Data((hookJson + "\n").utf8))
        XCTAssertEqual(hookEvents.count, 1)

        let normalizedHook = await mapper.map(hookEvents[0])
        let hasRawHook = normalizedHook.contains {
            if case .raw(let raw) = $0 {
                return raw.type.contains("hook_response")
            }
            return false
        }
        XCTAssertTrue(hasRawHook, "Hook response should produce raw event")

        // Parse result - include uuid
        let resultJson = #"{"type":"result","subtype":"success","is_error":false,"duration_ms":1000,"session_id":"test-session","uuid":"result-uuid","result":"done","total_cost_usd":0.01,"num_turns":1}"#
        let resultEvents = await parser.parse(chunk: Data((resultJson + "\n").utf8))
        XCTAssertEqual(resultEvents.count, 1)

        let normalizedResult = await mapper.map(resultEvents[0])
        let hasSessionEnded = normalizedResult.contains {
            if case .sessionEnded(let ended) = $0 {
                return ended.sessionId == "test-session" && ended.reason == "completed"
            }
            return false
        }
        XCTAssertTrue(hasSessionEnded, "Result should produce sessionEnded event")
    }

    /// Test end-to-end with model usage data from real CLI
    func testRealCLIWithModelUsage() async {
        let parser = NDJSONParser()
        let mapper = ClaudeEventMapper()

        // Result with modelUsage (real CLI format) - include uuid
        let json = #"{"type":"result","subtype":"success","is_error":false,"duration_ms":5653,"num_turns":1,"result":"hello","session_id":"test-session","uuid":"result-uuid","total_cost_usd":0.11891924999999999,"model_usage":{"claude-haiku-4-5-20251001":{"input_tokens":3,"output_tokens":233,"cache_read_input_tokens":6170,"cache_creation_input_tokens":0,"cost_usd":0.0017850000000000001},"claude-opus-4-5-20251101":{"input_tokens":4,"output_tokens":31,"cache_read_input_tokens":19816,"cache_creation_input_tokens":17029,"cost_usd":0.11713424999999998}}}"#

        let events = await parser.parse(chunk: Data((json + "\n").utf8))
        XCTAssertEqual(events.count, 1)

        let normalized = await mapper.map(events[0])

        // Should have token usage from modelUsage aggregation
        let hasUsage = normalized.contains { if case .tokenUsage = $0 { return true }; return false }
        XCTAssertTrue(hasUsage, "Should emit tokenUsage from modelUsage")

        // Should have session ended
        let hasEnded = normalized.contains { if case .sessionEnded = $0 { return true }; return false }
        XCTAssertTrue(hasEnded, "Should emit sessionEnded")
    }

    /// Test that partial streaming works with real CLI chunked output
    func testRealCLIChunkedParsing() async {
        let parser = NDJSONParser()

        // Simulate chunked network delivery
        let fullLine = """
        {"type":"assistant","message":{"model":"claude-opus-4-5","id":"msg-1","type":"message","role":"assistant","content":[{"type":"text","text":"Streaming response..."}],"stop_reason":null,"usage":{"input_tokens":100,"output_tokens":10}}}
        """

        // Split into chunks of 50 bytes
        var startIndex = fullLine.startIndex
        let chunkSize = 50
        var allEvents: [ClaudeStreamEvent] = []

        while startIndex < fullLine.endIndex {
            let endIndex = fullLine.index(startIndex, offsetBy: chunkSize, limitedBy: fullLine.endIndex) ?? fullLine.endIndex
            let chunk = String(fullLine[startIndex..<endIndex])
            allEvents.append(contentsOf: await parser.parse(chunk: Data(chunk.utf8)))
            startIndex = endIndex
        }

        // Add newline to complete the line
        allEvents.append(contentsOf: await parser.parse(chunk: Data("\n".utf8)))

        XCTAssertEqual(allEvents.count, 1, "Chunked input should reassemble into one event")
        if case .assistant = allEvents[0] {} else {
            XCTFail("Expected assistant event after reassembly")
        }
    }
}

// MARK: - DiffService Tests


final class SessionLifecycleIntegrationTests: XCTestCase {

    // MARK: - Session Creation Tests

    func testSessionCreationWithDefaultValues() {
        let session = Session(name: "Test Session")

        XCTAssertFalse(session.id.uuidString.isEmpty)
        XCTAssertEqual(session.name, "Test Session")
        XCTAssertEqual(session.status, .ready)
        XCTAssertEqual(session.trustMode, .prompt)
        XCTAssertNil(session.worktreePath)
        XCTAssertNil(session.branchName)
    }

    func testSessionCreationWithWorktreeInfo() {
        let session = Session(
            name: "Feature Branch",
            originalProjectPath: "/Users/test/project",
            worktreePath: "/Users/test/project/.blaze-worktrees/abc123",
            branchName: "blaze-session-abc123",
            status: .ready,
            trustMode: .prompt
        )

        XCTAssertEqual(session.originalProjectPath, "/Users/test/project")
        XCTAssertEqual(session.worktreePath, "/Users/test/project/.blaze-worktrees/abc123")
        XCTAssertEqual(session.branchName, "blaze-session-abc123")
        XCTAssertTrue(session.hasWorktree)
    }

    func testSessionStatusTransitions() {
        var session = Session(name: "Test", status: .creating)
        XCTAssertEqual(session.status, .creating)

        session.status = .ready
        XCTAssertEqual(session.status, .ready)

        session.status = .running
        XCTAssertEqual(session.status, .running)

        session.status = .errored
        XCTAssertEqual(session.status, .errored)

        session.status = .archived
        XCTAssertEqual(session.status, .archived)
    }

    // MARK: - Session Store Integration Tests

    func testSessionStoreCreateAndRetrieve() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("test.db").path
        let store = try SessionStore(path: dbPath)
        _ = try await store.runMigrations()

        // Create session
        let session = Session(
            name: "Integration Test Session",
            originalProjectPath: "/test/project"
        )
        try await store.create(session)

        // Retrieve session
        let retrieved = try await store.get(id: session.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Integration Test Session")
        XCTAssertEqual(retrieved?.originalProjectPath, "/test/project")
    }

    func testSessionStoreGroupByProject() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("test.db").path
        let store = try SessionStore(path: dbPath)
        _ = try await store.runMigrations()

        // Create sessions in different projects
        let session1 = Session(name: "Session 1", originalProjectPath: "/project/a")
        let session2 = Session(name: "Session 2", originalProjectPath: "/project/a")
        let session3 = Session(name: "Session 3", originalProjectPath: "/project/b")

        try await store.create(session1)
        try await store.create(session2)
        try await store.create(session3)

        // Group by project
        let grouped = try await store.getSessionsGroupedByProject()
        XCTAssertEqual(grouped["/project/a"]?.count, 2)
        XCTAssertEqual(grouped["/project/b"]?.count, 1)
    }

    func testSessionStoreUpdate() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("test.db").path
        let store = try SessionStore(path: dbPath)
        _ = try await store.runMigrations()

        // Create session
        var session = Session(name: "Original Name")
        try await store.create(session)

        // Update session
        session.name = "Updated Name"
        try await store.update(session)

        // Verify update
        let retrieved = try await store.get(id: session.id)
        XCTAssertEqual(retrieved?.name, "Updated Name")
    }

    func testSessionStoreDelete() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("test.db").path
        let store = try SessionStore(path: dbPath)
        _ = try await store.runMigrations()

        // Create session
        let session = Session(name: "To Delete")
        try await store.create(session)

        // Delete session
        try await store.delete(id: session.id)

        // Verify deletion
        let retrieved = try await store.get(id: session.id)
        XCTAssertNil(retrieved)
    }
}

/// Integration tests for tool approval workflow.

final class ToolApprovalIntegrationTests: XCTestCase {

    func testToolCallStatusTransitions() {
        var toolCall = ToolCall(name: "Bash", input: "{\"command\": \"ls\"}")

        // Initial state
        XCTAssertEqual(toolCall.status, .pending)
        XCTAssertNil(toolCall.output)

        // Transition to approved
        toolCall.status = .approved
        XCTAssertEqual(toolCall.status, .approved)

        // Transition to running
        toolCall.status = .running
        XCTAssertEqual(toolCall.status, .running)

        // Transition to succeeded
        toolCall.status = .succeeded
        toolCall.output = "file1.txt\nfile2.txt"
        XCTAssertEqual(toolCall.status, .succeeded)
        XCTAssertNotNil(toolCall.output)
    }

    func testToolCallRejection() {
        var toolCall = ToolCall(name: "Bash", input: "{\"command\": \"rm -rf /\"}")
        toolCall.status = .rejected

        XCTAssertEqual(toolCall.status, .rejected)
    }

    func testToolCallDuration() {
        var toolCall = ToolCall(name: "Read", input: "{\"path\": \"/file.txt\"}")
        let startTime = toolCall.startedAt

        // Simulate completion after 1.5 seconds
        toolCall.completedAt = startTime.addingTimeInterval(1.5)

        XCTAssertNotNil(toolCall.duration)
        XCTAssertEqual(toolCall.duration!, 1.5, accuracy: 0.001)
    }

    func testToolCallWithError() {
        var toolCall = ToolCall(name: "Read", input: "{\"path\": \"/nonexistent\"}")
        toolCall.status = .failed
        toolCall.output = "Error: File not found"

        XCTAssertEqual(toolCall.status, .failed)
        XCTAssertEqual(toolCall.output, "Error: File not found")
    }

    func testToolInputParsing() {
        let toolCall = ToolCall(name: "Write", input: "{\"file_path\": \"/test.txt\", \"content\": \"Hello\"}")

        // Test parsing of input JSON
        if let inputData = toolCall.input.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] {
            XCTAssertEqual(json["file_path"] as? String, "/test.txt")
            XCTAssertEqual(json["content"] as? String, "Hello")
        } else {
            XCTFail("Failed to parse tool input")
        }
    }
}

/// Integration tests for event persistence and retrieval.

final class EventPersistenceIntegrationTests: XCTestCase {

    func testEventEnvelopeCreation() {
        let now = Date()
        let event = NormalizedEvent.assistantDelta(AssistantDelta(text: "Hello", timestamp: now))
        let sessionId = UUID()
        let envelope = EventEnvelope(sessionId: sessionId, sequence: 1, event: event)

        XCTAssertEqual(envelope.sessionId, sessionId)
        XCTAssertEqual(envelope.sequence, 1)
    }

    func testNormalizedEventTypes() {
        // Test various event types
        let now = Date()
        let assistantDelta = NormalizedEvent.assistantDelta(
            AssistantDelta(text: "Hi", timestamp: now)
        )
        let thinkingDelta = NormalizedEvent.thinkingDelta(
            ThinkingDelta(text: "Thinking...", timestamp: now)
        )
        let assistantComplete = NormalizedEvent.assistantComplete(
            AssistantComplete(fullText: "Complete response", timestamp: now, stopReason: .endTurn)
        )
        let error = NormalizedEvent.error(
            ErrorEvent(code: "test_error", message: "Something went wrong", isRecoverable: true, timestamp: now)
        )

        // Verify events can be created
        if case .assistantDelta(let delta) = assistantDelta {
            XCTAssertEqual(delta.text, "Hi")
        } else {
            XCTFail("Expected assistantDelta")
        }

        if case .thinkingDelta(let delta) = thinkingDelta {
            XCTAssertEqual(delta.text, "Thinking...")
        } else {
            XCTFail("Expected thinkingDelta")
        }

        if case .assistantComplete(let complete) = assistantComplete {
            XCTAssertEqual(complete.fullText, "Complete response")
        } else {
            XCTFail("Expected assistantComplete")
        }

        if case .error(let err) = error {
            XCTAssertEqual(err.message, "Something went wrong")
        } else {
            XCTFail("Expected error")
        }
    }
}

// MARK: - Performance Tests (Phase 2.10)

/// Performance tests for file tree rendering and event handling.

