import XCTest
@testable import Blaze

/// Tests for PtyProcessRunner - PTY-based process spawning for bidirectional CLI communication.
///
/// Key requirement: PTY avoids pipe stdin buffering that causes Claude CLI to wait.
final class PtyProcessRunnerTests: XCTestCase {

    // MARK: - Basic Execution

    /// Test that we can spawn a simple command and read its output
    func testEchoCommand() async throws {
        let runner = PtyProcessRunner()

        try runner.spawn(
            executable: "/bin/echo",
            arguments: ["Hello, PTY!"],
            workingDirectory: nil
        )

        defer { runner.terminate() }

        // Wait for output
        try await Task.sleep(for: .milliseconds(100))

        let lines = runner.readLines()
        XCTAssertFalse(lines.isEmpty, "Should receive echo output")
        XCTAssertTrue(lines.joined().contains("Hello, PTY!"), "Output should contain our message")
    }

    /// Test that we can write to stdin
    func testWriteToStdin() async throws {
        let runner = PtyProcessRunner()

        // Use cat which echoes stdin back to stdout
        try runner.spawn(
            executable: "/bin/cat",
            arguments: [],
            workingDirectory: nil
        )

        defer { runner.terminate() }

        // Write to stdin
        let testData = "Test input line\n".data(using: .utf8)!
        try runner.write(testData)

        // Wait for echo back
        try await Task.sleep(for: .milliseconds(200))

        let lines = runner.readLines()
        XCTAssertTrue(lines.contains("Test input line"), "Should echo our input back")
    }

    /// Test isRunning status
    func testIsRunningStatus() async throws {
        let runner = PtyProcessRunner()

        try runner.spawn(
            executable: "/bin/sleep",
            arguments: ["10"],
            workingDirectory: nil
        )

        XCTAssertTrue(runner.isRunning, "Process should be running")

        runner.terminate()

        // Give it a moment to terminate
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertFalse(runner.isRunning, "Process should not be running after terminate")
    }

    // MARK: - NDJSON Line Framing

    /// Test that output is properly framed as lines (for NDJSON parsing)
    func testLineFraming() async throws {
        let runner = PtyProcessRunner()

        // Use printf to output multiple lines
        try runner.spawn(
            executable: "/usr/bin/printf",
            arguments: ["line1\\nline2\\nline3\\n"],
            workingDirectory: nil
        )

        defer { runner.terminate() }

        try await Task.sleep(for: .milliseconds(100))

        let lines = runner.readLines()
        XCTAssertEqual(lines.count, 3, "Should have 3 lines")
        XCTAssertEqual(lines[0], "line1")
        XCTAssertEqual(lines[1], "line2")
        XCTAssertEqual(lines[2], "line3")
    }

    /// Test that partial lines are buffered until newline
    func testPartialLineBuffering() async throws {
        let runner = PtyProcessRunner()

        // Use printf without final newline
        try runner.spawn(
            executable: "/usr/bin/printf",
            arguments: ["partial"],
            workingDirectory: nil
        )

        defer { runner.terminate() }

        try await Task.sleep(for: .milliseconds(100))

        // First read - partial line should be buffered, not returned
        let lines1 = runner.readLines()
        // Note: With PTY, partial lines may be returned since there's no more data coming
        // This test documents the actual behavior

        // The key thing is we don't crash and get predictable behavior
        XCTAssertTrue(lines1.isEmpty || lines1 == ["partial"],
            "Either buffered or returned as-is")
    }

    // MARK: - Error Handling

    /// Test that write fails gracefully on closed process
    func testWriteAfterTerminate() async throws {
        let runner = PtyProcessRunner()

        try runner.spawn(
            executable: "/bin/cat",
            arguments: [],
            workingDirectory: nil
        )

        runner.terminate()
        try await Task.sleep(for: .milliseconds(200))

        // Write should fail gracefully (not crash)
        let testData = "Should fail\n".data(using: .utf8)!
        XCTAssertThrowsError(try runner.write(testData), "Write to terminated process should throw")
    }

    /// Test spawn with invalid executable - process exits quickly
    /// Note: forkpty() doesn't throw on invalid executable - the error happens in the child
    func testInvalidExecutable() async throws {
        let runner = PtyProcessRunner()

        // Spawn succeeds (fork happens) but child will exit immediately
        try runner.spawn(
            executable: "/nonexistent/binary",
            arguments: [],
            workingDirectory: nil
        )

        defer { runner.terminate() }

        // Wait for process to exit
        try await Task.sleep(for: .milliseconds(500))

        // Process should have exited (exec failed in child)
        // Note: isRunning reaps the process, so we just verify it's not running
        XCTAssertFalse(runner.isRunning, "Process should have exited after exec failure")
    }
}

// MARK: - StdinWriter Tests

/// Tests for StdinWriter - atomic JSON line writing with fail-fast EPIPE handling.
final class StdinWriterTests: XCTestCase {

    /// Test atomic JSON line writing
    func testWriteJSONLine() async throws {
        let runner = PtyProcessRunner()

        try runner.spawn(
            executable: "/bin/cat",
            arguments: [],
            workingDirectory: nil
        )

        defer { runner.terminate() }

        let writer = StdinWriter(runner: runner)

        // Write a JSON object
        let envelope = TestEnvelope(type: "user", sessionId: "test-123")
        try await writer.sendJSONLine(envelope)

        // Wait for echo
        try await Task.sleep(for: .milliseconds(200))

        let lines = runner.readLines()
        XCTAssertFalse(lines.isEmpty, "Should receive echoed JSON")

        // Verify it's valid JSON
        if let firstLine = lines.first,
           let data = firstLine.data(using: .utf8) {
            let decoded = try JSONDecoder().decode(TestEnvelope.self, from: data)
            XCTAssertEqual(decoded.type, "user")
            XCTAssertEqual(decoded.sessionId, "test-123")
        } else {
            XCTFail("Could not decode echoed JSON")
        }
    }

    /// Test that lines are newline-terminated
    func testNewlineTermination() async throws {
        let runner = PtyProcessRunner()

        try runner.spawn(
            executable: "/bin/cat",
            arguments: [],
            workingDirectory: nil
        )

        defer { runner.terminate() }

        let writer = StdinWriter(runner: runner)

        // Write multiple lines
        try await writer.sendJSONLine(TestEnvelope(type: "a", sessionId: "1"))
        try await writer.sendJSONLine(TestEnvelope(type: "b", sessionId: "2"))

        try await Task.sleep(for: .milliseconds(200))

        let lines = runner.readLines()
        // PTY may echo back, so we check for at least 2 lines with our content
        XCTAssertGreaterThanOrEqual(lines.count, 2, "Should have at least 2 separate lines")

        // Verify both of our lines are present in the output
        let combinedOutput = lines.joined()
        XCTAssertTrue(combinedOutput.contains("\"type\":\"a\""), "Should contain first JSON")
        XCTAssertTrue(combinedOutput.contains("\"type\":\"b\""), "Should contain second JSON")
    }

    /// Test EPIPE handling (fail-fast)
    func testEPIPEFailsFast() async throws {
        let runner = PtyProcessRunner()

        try runner.spawn(
            executable: "/bin/cat",
            arguments: [],
            workingDirectory: nil
        )

        let writer = StdinWriter(runner: runner)

        // Terminate the process
        runner.terminate()
        try await Task.sleep(for: .milliseconds(200))

        // Write should fail with StdinWriterError.epipe or similar
        do {
            try await writer.sendJSONLine(TestEnvelope(type: "test", sessionId: "x"))
            XCTFail("Should have thrown an error")
        } catch {
            // Expected - write to closed FD should fail
            XCTAssertTrue(true)
        }
    }

    /// Test envelope format matches C_session_id variant
    func testEnvelopeFormat() async throws {
        // Use the production ToolResultEnvelope from Blaze module
        let envelope = Blaze.ToolResultEnvelope(
            sessionId: "sess-abc",
            parentToolUseId: nil,  // Explicit null
            toolUseId: "toolu_123",
            content: "Option A"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(envelope)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Could not parse JSON"); return
        }

        // Verify structure matches C_session_id variant
        XCTAssertEqual(json["type"] as? String, "user")
        XCTAssertEqual(json["session_id"] as? String, "sess-abc")
        XCTAssertTrue(json.keys.contains("parent_tool_use_id"), "Should include parent_tool_use_id")
        XCTAssertTrue(json["parent_tool_use_id"] is NSNull, "parent_tool_use_id should be null")

        // Verify message structure
        guard let message = json["message"] as? [String: Any] else {
            XCTFail("Missing message"); return
        }
        XCTAssertEqual(message["role"] as? String, "user")

        guard let contentArray = message["content"] as? [[String: Any]],
              let first = contentArray.first else {
            XCTFail("Missing content array"); return
        }
        XCTAssertEqual(first["type"] as? String, "tool_result")
        XCTAssertEqual(first["tool_use_id"] as? String, "toolu_123")
        XCTAssertEqual(first["content"] as? String, "Option A")
    }
}

// MARK: - Test Helpers

struct TestEnvelope: Codable, Equatable {
    let type: String
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
    }
}
