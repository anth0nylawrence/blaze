import XCTest
import GRDB
@testable import Blaze

final class NDJSONParserTests: XCTestCase {

    // MARK: - Basic Parsing

    func testParseSingleLine() async {
        let parser = NDJSONParser()
        let json = """
        {"type":"init","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test-uuid","sessionId":"session-123","version":"1.0.58","message":{"sessionId":"session-123","version":"1.0.58","model":"claude-opus-4","cwd":"/project","capabilities":[],"allowedTools":[]}}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .`init`(let initEvent) = events.first {
            XCTAssertEqual(initEvent.sessionId, "session-123")
            XCTAssertEqual(initEvent.version, "1.0.58")
            XCTAssertEqual(initEvent.message.model, "claude-opus-4")
        } else {
            XCTFail("Expected init event")
        }
    }

    func testParseMultipleLines() async {
        let parser = NDJSONParser()
        let lines = [
            """
            {"type":"init","timestamp":"2025-12-25T10:00:00.000Z","uuid":"uuid-1","sessionId":"sess-1","version":"1.0","message":{"sessionId":"sess-1","version":"1.0","model":"claude","cwd":"/","capabilities":[],"allowedTools":[]}}
            """,
            """
            {"type":"user","timestamp":"2025-12-25T10:00:01.000Z","uuid":"uuid-2","sessionId":"sess-1","message":{"role":"user","content":"Hello"}}
            """
        ]
        let data = Data((lines.joined(separator: "\n") + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 2)
        if case .`init` = events[0] {} else { XCTFail("Expected init event") }
        if case .user = events[1] {} else { XCTFail("Expected user event") }
    }

    func testParsePartialLines() async {
        let parser = NDJSONParser()
        let fullJson = """
        {"type":"init","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test","sessionId":"sess","version":"1.0","message":{"sessionId":"sess","version":"1.0","model":"claude","cwd":"/","capabilities":[],"allowedTools":[]}}
        """

        // Send first half
        let part1 = Data(fullJson.prefix(50).utf8)
        var events = await parser.parse(chunk: part1)
        XCTAssertEqual(events.count, 0, "Should not parse incomplete line")

        // Send second half with newline
        let part2 = Data((fullJson.dropFirst(50) + "\n").utf8)
        events = await parser.parse(chunk: part2)
        XCTAssertEqual(events.count, 1, "Should parse complete line")
    }

    func testFlushRemainingBuffer() async {
        let parser = NDJSONParser()
        let json = """
        {"type":"init","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test","sessionId":"sess","version":"1.0","message":{"sessionId":"sess","version":"1.0","model":"claude","cwd":"/","capabilities":[],"allowedTools":[]}}
        """
        // Send without trailing newline
        let data = Data(json.utf8)
        _ = await parser.parse(chunk: data)

        let flushed = await parser.flush()
        XCTAssertNotNil(flushed, "Flush should return remaining buffered event")
    }

    // MARK: - Event Type Discrimination

    func testParseAssistantEvent() async {
        let parser = NDJSONParser()
        let json = """
        {"type":"assistant","timestamp":"2025-12-25T10:00:02.000Z","uuid":"asst-1","sessionId":"sess","requestId":"req-1","message":{"id":"msg-1","type":"message","role":"assistant","model":"claude-opus-4","content":[{"type":"text","text":"Hello there!"}],"stopReason":null,"stopSequence":null,"usage":{"inputTokens":100,"outputTokens":10}}}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .assistant(let event) = events.first {
            XCTAssertEqual(event.message.id, "msg-1")
            XCTAssertEqual(event.message.content.count, 1)
            if case .text(let textBlock) = event.message.content.first {
                XCTAssertEqual(textBlock.text, "Hello there!")
            } else {
                XCTFail("Expected text content block")
            }
        } else {
            XCTFail("Expected assistant event")
        }
    }

    func testParseResultEvent() async {
        let parser = NDJSONParser()
        // Real CLI format: result is a string, fields at top level
        let json = """
        {"type":"result","subtype":"success","is_error":false,"duration_ms":60000,"num_turns":5,"uuid":"result-1","session_id":"sess","result":"Task completed","total_cost_usd":0.05,"usage":{"input_tokens":5000,"output_tokens":2500,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"total_tokens":7500}}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .result(let event) = events.first {
            XCTAssertTrue(event.success)
            XCTAssertEqual(event.isError, false)
            XCTAssertEqual(event.numTurns, 5)
            XCTAssertEqual(event.totalCostUsd, 0.05)
            XCTAssertEqual(event.result, "Task completed")
        } else {
            XCTFail("Expected result event")
        }
    }

    func testParseToolUseInAssistant() async {
        let parser = NDJSONParser()
        let json = """
        {"type":"assistant","timestamp":"2025-12-25T10:00:03.000Z","uuid":"asst-2","sessionId":"sess","requestId":"req-1","message":{"id":"msg-2","type":"message","role":"assistant","model":"claude","content":[{"type":"text","text":"Creating file..."},{"type":"tool_use","id":"toolu_123","name":"Write","input":{"file_path":"/test.txt","content":"Hello"}}],"stopReason":"tool_use","stopSequence":null,"usage":{"inputTokens":100,"outputTokens":50}}}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .assistant(let event) = events.first {
            XCTAssertEqual(event.message.stopReason, "tool_use")
            XCTAssertEqual(event.message.content.count, 2)

            if case .toolUse(let toolBlock) = event.message.content[1] {
                XCTAssertEqual(toolBlock.name, "Write")
                XCTAssertEqual(toolBlock.id, "toolu_123")
                XCTAssertEqual(toolBlock.input.getString("file_path"), "/test.txt")
            } else {
                XCTFail("Expected tool_use content block")
            }
        } else {
            XCTFail("Expected assistant event")
        }
    }

    // MARK: - Error Handling

    func testParseMalformedJSON() async {
        let parser = NDJSONParser()
        let badJson = "this is not valid json\n"
        let data = Data(badJson.utf8)

        let events = await parser.parse(chunk: data)

        // Should return unknown event, not crash
        XCTAssertEqual(events.count, 1)
        if case .unknown = events.first {} else {
            XCTFail("Expected unknown event for malformed JSON")
        }
    }

    func testParseUnknownEventType() async {
        let parser = NDJSONParser()
        let json = """
        {"type":"future_event_type","timestamp":"2025-12-25T10:00:00.000Z","uuid":"test","sessionId":"sess","data":"some data"}
        """
        let data = Data((json + "\n").utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 1)
        if case .unknown(let raw) = events.first {
            XCTAssertEqual(raw.type, "future_event_type")
        } else {
            XCTFail("Expected unknown event for unknown type")
        }
    }

    func testParseEmptyLines() async {
        let parser = NDJSONParser()
        let data = Data("\n\n\n".utf8)

        let events = await parser.parse(chunk: data)

        XCTAssertEqual(events.count, 0, "Empty lines should be skipped")
    }

    func testReset() async {
        let parser = NDJSONParser()

        // Send partial data
        let partial = Data("partial json data".utf8)
        _ = await parser.parse(chunk: partial)

        // Reset
        await parser.reset()

        // Flush should return nil after reset
        let flushed = await parser.flush()
        XCTAssertNil(flushed, "Buffer should be empty after reset")
    }
}

final class NDJSONParserContractTests: XCTestCase {

    // MARK: - Atom A001: Buffering Tests

    /// Test: Emit partial NDJSON chunks and verify buffered completion
    func testPartialChunkBuffering() async {
        let parser = NDJSONParser()
        let fullJson = """
        {"type":"assistant","message":{"id":"msg-1","type":"message","role":"assistant","model":"claude","content":[{"type":"text","text":"Hello world"}],"stopReason":"end_turn","usage":{"inputTokens":10,"outputTokens":5}}}
        """

        // Send in 3 chunks to simulate network chunking
        let chunk1 = String(fullJson.prefix(50))
        let chunk2 = String(fullJson.dropFirst(50).prefix(100))
        let chunk3 = String(fullJson.dropFirst(150))

        var allEvents: [ClaudeStreamEvent] = []

        // First chunk - should buffer, no events
        allEvents.append(contentsOf: await parser.parse(chunk: Data(chunk1.utf8)))
        XCTAssertEqual(allEvents.count, 0, "Partial line should be buffered")
        let hasPending = await parser.hasPendingData
        XCTAssertTrue(hasPending, "Should have pending data in buffer")

        // Second chunk - still incomplete
        allEvents.append(contentsOf: await parser.parse(chunk: Data(chunk2.utf8)))
        XCTAssertEqual(allEvents.count, 0, "Still incomplete, should remain buffered")

        // Third chunk with newline - should complete
        allEvents.append(contentsOf: await parser.parse(chunk: Data((chunk3 + "\n").utf8)))
        XCTAssertEqual(allEvents.count, 1, "Complete line should produce event")

        // Verify event parsed correctly
        if case .assistant(let event) = allEvents[0] {
            XCTAssertEqual(event.message.id, "msg-1")
        } else {
            XCTFail("Expected assistant event")
        }
    }

    /// Test: Verify event ordering is preserved under streaming
    func testEventOrderingPreserved() async {
        let parser = NDJSONParser()

        // Send 5 events in a single chunk
        let events = (1...5).map { i in
            """
            {"type":"assistant","message":{"id":"msg-\(i)","type":"message","role":"assistant","model":"claude","content":[{"type":"text","text":"Event \(i)"}],"usage":{"inputTokens":10,"outputTokens":5}}}
            """
        }
        let combined = events.joined(separator: "\n") + "\n"

        let parsed = await parser.parse(chunk: Data(combined.utf8))

        // Verify count
        XCTAssertEqual(parsed.count, 5, "Should parse all 5 events")

        // Verify order matches emission order
        for (index, event) in parsed.enumerated() {
            if case .assistant(let asst) = event {
                XCTAssertEqual(asst.message.id, "msg-\(index + 1)", "Events should be in emission order")
            } else {
                XCTFail("Expected assistant event at index \(index)")
            }
        }
    }

    // MARK: - Atom A001: Error Handling Tests

    /// Test: Inject malformed line and verify skip without crash
    func testMalformedLineSkippedWithoutCrash() async {
        let parser = NDJSONParser()

        // Mix of valid and invalid JSON
        let input = """
        {"type":"assistant","message":{"id":"msg-1","type":"message","role":"assistant","model":"claude","content":[{"type":"text","text":"Valid 1"}],"usage":{"inputTokens":10,"outputTokens":5}}}
        this is completely invalid JSON
        {"broken json missing closing
        {"type":"assistant","message":{"id":"msg-2","type":"message","role":"assistant","model":"claude","content":[{"type":"text","text":"Valid 2"}],"usage":{"inputTokens":10,"outputTokens":5}}}

        """

        let events = await parser.parse(chunk: Data(input.utf8))

        // Should have 4 events: 2 valid + 2 malformed (as unknown)
        XCTAssertEqual(events.count, 4, "Should parse all lines including malformed ones as unknown")

        // First should be valid assistant
        if case .assistant(let asst) = events[0] {
            XCTAssertEqual(asst.message.id, "msg-1")
        } else {
            XCTFail("First event should be valid assistant")
        }

        // Second should be unknown (parse error)
        if case .unknown(let raw) = events[1] {
            XCTAssertEqual(raw.type, "parse_error")
        } else {
            XCTFail("Second event should be unknown parse_error")
        }

        // Third should also be unknown (broken JSON)
        if case .unknown(let raw) = events[2] {
            XCTAssertEqual(raw.type, "parse_error")
        } else {
            XCTFail("Third event should be unknown parse_error")
        }

        // Fourth should be valid assistant
        if case .assistant(let asst) = events[3] {
            XCTAssertEqual(asst.message.id, "msg-2")
        } else {
            XCTFail("Fourth event should be valid assistant")
        }

        // Verify parse errors were recorded
        let errors = await parser.parseErrors
        XCTAssertEqual(errors.count, 2, "Should record 2 parse errors")
    }

    /// Test: Parse error includes raw bytes for debugging
    func testParseErrorIncludesRawBytes() async {
        let parser = NDJSONParser()
        let badJson = "invalid json content\n"

        _ = await parser.parse(chunk: Data(badJson.utf8))

        let errors = await parser.parseErrors
        XCTAssertEqual(errors.count, 1)

        let error = errors[0]
        XCTAssertEqual(error.rawString, "invalid json content")
        XCTAssertGreaterThan(error.rawBytes.count, 0)
        XCTAssertFalse(error.hexDump.isEmpty, "Should have hex dump for debugging")
        XCTAssertEqual(error.lineNumber, 1)
    }

    /// Test: Buffer does not grow unbounded with parse errors
    func testParseErrorsAreBounded() async {
        let parser = NDJSONParser()

        // Send 200 malformed lines (more than maxErrorsRetained = 100)
        let badLines = (1...200).map { "invalid line \($0)\n" }.joined()
        _ = await parser.parse(chunk: Data(badLines.utf8))

        let errors = await parser.parseErrors
        XCTAssertLessThanOrEqual(errors.count, 100, "Parse errors should be bounded")
    }

    // MARK: - Atom A001: Reset Tests

    func testResetClearsBufferAndErrors() async {
        let parser = NDJSONParser()

        // Add error first
        _ = await parser.parse(chunk: Data("bad json\n".utf8))

        let errorCount = await parser.parseErrors.count
        XCTAssertGreaterThan(errorCount, 0)

        // Then add partial data (no newline)
        _ = await parser.parse(chunk: Data("partial data without newline".utf8))

        let hasPending = await parser.hasPendingData
        XCTAssertTrue(hasPending)

        // Reset
        await parser.reset()

        let hasPendingAfter = await parser.hasPendingData
        XCTAssertFalse(hasPendingAfter)

        let errorCountAfter = await parser.parseErrors.count
        XCTAssertEqual(errorCountAfter, 0)

        let bufferSize = await parser.bufferSize
        XCTAssertEqual(bufferSize, 0)
    }

    // MARK: - Delegate Tests

    func testDelegateCalledOnParseError() async {
        let delegate = MockParserDelegate()
        let parser = NDJSONParser(delegate: delegate)

        _ = await parser.parse(chunk: Data("malformed\n".utf8))

        // Give delegate time to be called
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let count = await delegate.getErrorCount()
        XCTAssertEqual(count, 1, "Delegate should be notified of parse error")
    }
}

// MARK: - Mock Parser Delegate

actor MockParserDelegate: NDJSONParserDelegate {
    private var _errorCount = 0

    func getErrorCount() -> Int {
        _errorCount
    }

    func parserDidSkipMalformedLine(_ error: NDJSONParseError) async {
        _errorCount += 1
    }
}
