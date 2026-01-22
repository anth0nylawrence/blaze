import XCTest
import GRDB
@testable import Blaze

final class ProcessRunnerTests: XCTestCase {

    func testEchoCommand() async throws {
        let runner = ProcessRunner()
        let config = ProcessRunner.Configuration(
            executable: "/bin/echo",
            arguments: ["Hello, World!"]
        )

        let outputs = await collectOutputs(runner: runner, config: config)

        // Should have stdout and exit
        let stdoutOutputs = outputs.compactMap { output -> Data? in
            if case .stdout(let data) = output { return data }
            return nil
        }
        let exitOutputs = outputs.compactMap { output -> Int32? in
            if case .exit(let code) = output { return code }
            return nil
        }

        XCTAssertFalse(stdoutOutputs.isEmpty, "Should have stdout output")
        XCTAssertEqual(exitOutputs.first, 0, "Should exit with code 0")

        // Check stdout contains our message
        let combinedStdout = stdoutOutputs.reduce(Data()) { $0 + $1 }
        let outputString = String(data: combinedStdout, encoding: .utf8)
        XCTAssertTrue(outputString?.contains("Hello, World!") ?? false)
    }

    func testCommandWithArguments() async throws {
        let runner = ProcessRunner()
        let config = ProcessRunner.Configuration(
            executable: "/bin/ls",
            arguments: ["-la", "/tmp"]
        )

        let outputs = await collectOutputs(runner: runner, config: config)

        let hasOutput = outputs.contains { output in
            if case .stdout(let data) = output { return !data.isEmpty }
            return false
        }
        let exitCode = outputs.compactMap { output -> Int32? in
            if case .exit(let code) = output { return code }
            return nil
        }.first

        XCTAssertTrue(hasOutput, "Should have output from ls")
        XCTAssertEqual(exitCode, 0, "Should exit successfully")
    }

    func testFailingCommand() async throws {
        let runner = ProcessRunner()
        let config = ProcessRunner.Configuration(
            executable: "/bin/ls",
            arguments: ["/nonexistent/path/that/does/not/exist"]
        )

        let outputs = await collectOutputs(runner: runner, config: config)

        let exitCode = outputs.compactMap { output -> Int32? in
            if case .exit(let code) = output { return code }
            return nil
        }.first

        XCTAssertNotNil(exitCode, "Should have exit code")
        XCTAssertNotEqual(exitCode, 0, "Should exit with non-zero code for missing path")
    }

    // Helper to collect outputs from ProcessRunner
    private func collectOutputs(runner: ProcessRunner, config: ProcessRunner.Configuration) async -> [ProcessRunner.ProcessOutput] {
        var outputs: [ProcessRunner.ProcessOutput] = []
        let stream = await runner.run(config)
        do {
            for try await output in stream {
                outputs.append(output)
            }
        } catch {
            // Ignore errors for test collection
        }
        return outputs
    }
}

// MARK: - NDJSON Parser Edge Cases

extension NDJSONParserTests {

    func testParseUnicodeContent() async {
        let parser = NDJSONParser()
        let json = """
        {"type":"assistant","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test","sessionId":"sess","requestId":"req","message":{"id":"msg","type":"message","role":"assistant","model":"claude","content":[{"type":"text","text":"Hello 世界! 🎉 Привет мир! مرحبا"}],"stopReason":null,"stopSequence":null,"usage":{"inputTokens":10,"outputTokens":5}}}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .assistant(let event) = events.first,
           case .text(let textBlock) = event.message.content.first {
            XCTAssertTrue(textBlock.text.contains("世界"))
            XCTAssertTrue(textBlock.text.contains("🎉"))
            XCTAssertTrue(textBlock.text.contains("Привет"))
            XCTAssertTrue(textBlock.text.contains("مرحبا"))
        } else {
            XCTFail("Expected assistant event with unicode text")
        }
    }

    func testParseLargePayload() async {
        let parser = NDJSONParser()

        // Create a large text content (100KB)
        let largeText = String(repeating: "A", count: 100_000)
        let json = """
        {"type":"assistant","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test","sessionId":"sess","requestId":"req","message":{"id":"msg","type":"message","role":"assistant","model":"claude","content":[{"type":"text","text":"\(largeText)"}],"stopReason":"end_turn","stopSequence":null,"usage":{"inputTokens":10,"outputTokens":50000}}}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .assistant(let event) = events.first,
           case .text(let textBlock) = event.message.content.first {
            XCTAssertEqual(textBlock.text.count, 100_000)
        } else {
            XCTFail("Expected assistant event with large text")
        }
    }

    func testParseEscapedCharacters() async {
        let parser = NDJSONParser()
        let json = """
        {"type":"assistant","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test","sessionId":"sess","requestId":"req","message":{"id":"msg","type":"message","role":"assistant","model":"claude","content":[{"type":"text","text":"Line 1\\nLine 2\\tTabbed\\\"Quoted\\\""}],"stopReason":null,"stopSequence":null,"usage":{"inputTokens":10,"outputTokens":5}}}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .assistant(let event) = events.first,
           case .text(let textBlock) = event.message.content.first {
            XCTAssertTrue(textBlock.text.contains("\n"))
            XCTAssertTrue(textBlock.text.contains("\t"))
            XCTAssertTrue(textBlock.text.contains("\""))
        } else {
            XCTFail("Expected assistant event with escaped characters")
        }
    }

    func testParseThinkingBlock() async {
        let parser = NDJSONParser()
        let json = """
        {"type":"assistant","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test","sessionId":"sess","requestId":"req","message":{"id":"msg","type":"message","role":"assistant","model":"claude","content":[{"type":"thinking","thinking":"Let me think about this..."},{"type":"text","text":"Here's my answer"}],"stopReason":"end_turn","stopSequence":null,"usage":{"inputTokens":10,"outputTokens":5}}}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .assistant(let event) = events.first {
            XCTAssertEqual(event.message.content.count, 2)
            if case .thinking(let thinkBlock) = event.message.content[0] {
                XCTAssertEqual(thinkBlock.thinking, "Let me think about this...")
            } else {
                XCTFail("Expected thinking block")
            }
        } else {
            XCTFail("Expected assistant event")
        }
    }

    func testParseSummaryEvent() async {
        let parser = NDJSONParser()
        let json = """
        {"type":"summary","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test","sessionId":"sess","summary":"Created login page with form validation","leafUuid":"leaf-123"}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .summary(let event) = events.first {
            XCTAssertEqual(event.summary, "Created login page with form validation")
            XCTAssertEqual(event.leafUuid, "leaf-123")
        } else {
            XCTFail("Expected summary event")
        }
    }

    func testParseSystemWarning() async {
        let parser = NDJSONParser()
        let json = """
        {"type":"system","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test","sessionId":"sess","message":{"level":"warn","text":"Context is getting large","code":"context_warning"}}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .system(let event) = events.first {
            XCTAssertEqual(event.message.level, "warn")
            XCTAssertEqual(event.message.text, "Context is getting large")
            XCTAssertEqual(event.message.code, "context_warning")
        } else {
            XCTFail("Expected system event")
        }
    }

    func testParseUserWithToolResult() async {
        let parser = NDJSONParser()
        // Note: Parser uses .convertFromSnakeCase, so both snake_case and camelCase work
        // Real CLI sends snake_case (tool_use_id, is_error) which gets auto-converted
        let json = """
        {"type":"user","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test","sessionId":"sess","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_123","content":[{"type":"text","text":"File created"}],"is_error":false}]},"toolUseResult":{"content":[],"totalDurationMs":150,"totalTokens":5,"totalToolUseCount":1,"wasInterrupted":false}}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .user(let event) = events.first {
            XCTAssertNotNil(event.toolUseResult)
            XCTAssertEqual(event.toolUseResult?.totalDurationMs, 150)
        } else {
            XCTFail("Expected user event")
        }
    }

    func testManyChunksReassembly() async {
        let parser = NDJSONParser()
        let fullJson = """
        {"type":"init","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test","sessionId":"sess","version":"1.0","message":{"sessionId":"sess","version":"1.0","model":"claude","cwd":"/","capabilities":[],"allowedTools":[]}}
        """

        // Split into many small chunks
        let chunkSize = 10
        var startIndex = fullJson.startIndex
        var events: [ClaudeStreamEvent] = []

        while startIndex < fullJson.endIndex {
            let endIndex = fullJson.index(startIndex, offsetBy: chunkSize, limitedBy: fullJson.endIndex) ?? fullJson.endIndex
            let chunk = String(fullJson[startIndex..<endIndex])
            let data = Data(chunk.utf8)
            events.append(contentsOf: await parser.parse(chunk: data))
            startIndex = endIndex
        }

        // Add final newline
        events.append(contentsOf: await parser.parse(chunk: Data("\n".utf8)))

        XCTAssertEqual(events.count, 1, "Should reassemble into one event")
    }
}

// MARK: - Event Mapper Edge Cases

extension ClaudeEventMapperTests {

    func testResetClearsState() async {
        let mapper = ClaudeEventMapper()

        // Send an assistant event to build up state
        let event = createAssistantEvent(
            messageId: "msg-1",
            content: [.text(TextBlock(type: "text", text: "Hello"))],
            stopReason: nil
        )
        _ = await mapper.map(.assistant(event))

        // Reset
        await mapper.reset()

        // Send same message ID - should treat as new
        let event2 = createAssistantEvent(
            messageId: "msg-1",
            content: [.text(TextBlock(type: "text", text: "World"))],
            stopReason: nil
        )
        let events = await mapper.map(.assistant(event2))

        // Should emit delta for full "World" text, not just difference
        let hasDelta = events.contains {
            if case .assistantDelta(let delta) = $0 {
                return delta.text == "World"
            }
            return false
        }
        XCTAssertTrue(hasDelta, "Reset should clear message tracking")
    }

    func testUnknownEventPassthrough() async {
        let mapper = ClaudeEventMapper()

        let rawEvent = RawStreamEvent(type: "future_type", timestamp: Date(), payload: nil)
        let events = await mapper.map(.unknown(rawEvent))

        XCTAssertEqual(events.count, 1)
        if case .raw(let raw) = events.first {
            XCTAssertEqual(raw.type, "future_type")
        } else {
            XCTFail("Expected raw event passthrough")
        }
    }

    func testReadToolProducesFileRead() async {
        let mapper = ClaudeEventMapper()

        let toolInput = ToolInput.from(dict: ["file_path": "/src/main.swift"])
        let event = createAssistantEvent(
            messageId: "msg-1",
            content: [.toolUse(ToolUseBlock(type: "tool_use", id: "toolu_789", name: "Read", input: toolInput))],
            stopReason: "tool_use"
        )
        let events = await mapper.map(.assistant(event))

        let hasFileRead = events.contains {
            if case .fileRead(let read) = $0 {
                return read.filePath == "/src/main.swift"
            }
            return false
        }
        XCTAssertTrue(hasFileRead, "Read tool should produce fileRead event")
    }

    func testTokenUsageFromAssistant() async {
        let mapper = ClaudeEventMapper()

        let event = createAssistantEvent(
            messageId: "msg-1",
            content: [.text(TextBlock(type: "text", text: "Response"))],
            stopReason: "end_turn"
        )
        let events = await mapper.map(.assistant(event))

        let hasUsage = events.contains {
            if case .tokenUsage(let usage) = $0 {
                return usage.inputTokens == 100 && usage.outputTokens == 50
            }
            return false
        }
        XCTAssertTrue(hasUsage, "Should emit tokenUsage from assistant message")
    }

    func testFailedResultEvent() async {
        let mapper = ClaudeEventMapper()

        // Use new real CLI format for failed result
        let resultEvent = ResultStreamEvent(
            type: "result",
            subtype: "error_max_turns",
            uuid: "result-1",
            sessionId: "session-123",
            result: nil,
            isError: true,
            durationMs: 5000,
            durationApiMs: nil,
            numTurns: 3,
            totalCostUsd: nil,
            usage: nil,
            modelUsage: nil,
            permissionDenials: nil
        )

        let events = await mapper.map(.result(resultEvent))

        let hasEnded = events.contains {
            if case .sessionEnded(let ended) = $0 {
                return ended.reason == "error_max_turns"
            }
            return false
        }
        XCTAssertTrue(hasEnded, "Should emit sessionEnded with error reason")
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

    private func collectOutputs(runner: ProcessRunner, config: ProcessRunner.Configuration) async -> [ProcessRunner.ProcessOutput] {
        var outputs: [ProcessRunner.ProcessOutput] = []
        let stream = await runner.run(config)
        do {
            for try await output in stream {
                outputs.append(output)
            }
        } catch {
            // Ignore errors for test collection
        }
        return outputs
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

