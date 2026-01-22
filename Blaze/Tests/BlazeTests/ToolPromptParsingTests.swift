import XCTest
@testable import Blaze

/// Parsing tests for tool prompt fixtures.
///
/// These tests verify:
/// 1. Tool_use fixtures can be decoded without crashing
/// 2. Unknown event types decode to `.unknown` bucket
/// 3. Forward compatibility is maintained
///
/// IMPORTANT: These tests do NOT implement extraction logic.
/// Extraction will be added in Phase 4 after schema is confirmed from fixtures.
final class ToolPromptParsingTests: XCTestCase {

    // MARK: - Fixture Loading

    /// Load a fixture file by name from the latest version directory
    func loadFixture(_ name: String) throws -> Data {
        // Find fixtures directory relative to test file location
        let repoFixtures = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // BlazeTests
            .deletingLastPathComponent()  // Tests
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("NDJSON")

        // Read "latest" pointer
        let latestURL = repoFixtures.appendingPathComponent("latest")
        guard FileManager.default.fileExists(atPath: latestURL.path) else {
            throw FixtureError.noFixtures(
                "No fixtures found. Run: swift Blaze/Scripts/capture_tool_prompt_fixture.swift"
            )
        }

        let version = try String(contentsOf: latestURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let fixtureURL = repoFixtures
            .appendingPathComponent(version)
            .appendingPathComponent(name)

        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw FixtureError.missingFixture(name, version)
        }

        return try Data(contentsOf: fixtureURL)
    }

    // MARK: - Unknown Event Tests (Critical for Forward Compatibility)

    /// Test that unknown event types decode to `.unknown` bucket and don't crash
    func testUnknownEventDoesNotCrash() throws {
        let unknownJSON = """
        {"type":"future_event","timestamp":"2026-01-02T12:00:00Z","data":"whatever","nested":{"foo":"bar"}}
        """
        let data = unknownJSON.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        // Should NOT throw
        let event = try decoder.decode(ClaudeStreamEvent.self, from: data)

        // Should decode as .unknown
        guard case .unknown(let rawEvent) = event else {
            XCTFail("Unknown event type should decode as .unknown, got: \(event)")
            return
        }

        XCTAssertEqual(rawEvent.type, "future_event")
        print("✓ Unknown event decoded successfully: type=\(rawEvent.type)")
    }

    /// Test that multiple unknown event types all decode without crashing
    func testVariousUnknownEventTypes() throws {
        let unknownTypes = [
            ("new_feature", #"{"type":"new_feature","timestamp":"2026-01-02T12:00:00Z"}"#),
            ("streaming_v2", #"{"type":"streaming_v2","timestamp":"2026-01-02T12:00:00Z","delta":"text"}"#),
            ("tool_streaming", #"{"type":"tool_streaming","timestamp":"2026-01-02T12:00:00Z","partial":true}"#),
            ("metric", #"{"type":"metric","timestamp":"2026-01-02T12:00:00Z","name":"tokens","value":100}"#),
        ]

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        for (typeName, json) in unknownTypes {
            let data = json.data(using: .utf8)!

            // Should NOT throw
            let event = try decoder.decode(ClaudeStreamEvent.self, from: data)

            guard case .unknown(let rawEvent) = event else {
                XCTFail("Unknown event '\(typeName)' should decode as .unknown")
                continue
            }

            XCTAssertEqual(rawEvent.type, typeName)
            print("✓ Unknown event '\(typeName)' decoded successfully")
        }
    }

    /// Test that malformed JSON (missing required fields) is handled gracefully
    func testMalformedJSONDoesNotCrash() {
        let malformedCases = [
            // Missing type field
            #"{"timestamp":"2026-01-02T12:00:00Z"}"#,
            // Empty object
            #"{}"#,
            // Invalid JSON
            #"{"type":"incomplete"#,
        ]

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        for json in malformedCases {
            let data = json.data(using: .utf8)!

            // Should throw, but should not crash the process
            XCTAssertThrowsError(try decoder.decode(ClaudeStreamEvent.self, from: data)) { error in
                print("✓ Malformed JSON handled gracefully: \(error.localizedDescription.prefix(50))")
            }
        }
    }

    // MARK: - Tool Use Fixture Tests

    /// Test that tool_use fixture exists and can be read
    func testToolUseFixtureExists() throws {
        do {
            let data = try loadFixture("ask_user_question_tool_use.json")
            XCTAssertGreaterThan(data.count, 0, "Fixture should not be empty")
            print("✓ Fixture exists: \(data.count) bytes")
        } catch FixtureError.noFixtures(let message) {
            throw XCTSkip(message)
        }
    }

    /// Test that tool_use fixture decodes as assistant event
    func testDecodeToolUseFixture() throws {
        let data: Data
        do {
            data = try loadFixture("ask_user_question_tool_use.json")
        } catch FixtureError.noFixtures(let message) {
            throw XCTSkip(message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(ClaudeStreamEvent.self, from: data)

        // Tool use comes in assistant events
        guard case .assistant(let assistantEvent) = event else {
            XCTFail("Tool use fixture should decode as assistant event, got: \(event)")
            return
        }

        print("✓ Decoded assistant event with message id: \(assistantEvent.message.id)")

        // Verify content contains tool_use block
        let hasToolUse = assistantEvent.message.content.contains { block in
            if case .toolUse(_) = block {
                return true
            }
            return false
        }

        XCTAssertTrue(hasToolUse, "Assistant event should contain tool_use block")
    }

    /// Test that tool_use block can be identified in fixture
    func testIdentifyToolUseBlock() throws {
        let data: Data
        do {
            data = try loadFixture("ask_user_question_tool_use.json")
        } catch FixtureError.noFixtures(let message) {
            throw XCTSkip(message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(ClaudeStreamEvent.self, from: data)

        guard case .assistant(let assistantEvent) = event else {
            XCTFail("Expected assistant event")
            return
        }

        // Find tool_use block
        var toolUseBlock: ToolUseBlock?
        for block in assistantEvent.message.content {
            if case .toolUse(let tu) = block {
                toolUseBlock = tu
                break
            }
        }

        guard let toolUse = toolUseBlock else {
            XCTFail("No tool_use block found in fixture")
            return
        }

        XCTAssertEqual(toolUse.name, "AskUserQuestion", "Tool name should be AskUserQuestion")
        XCTAssertTrue(toolUse.id.hasPrefix("toolu_"), "Tool use ID should start with toolu_")

        print("✓ Found tool_use: name=\(toolUse.name), id=\(toolUse.id)")

        // NOTE: We do NOT extract or validate the input schema here.
        // That will be done in Phase 4 with typed Decodable structs.
        // For now, just verify the tool_use block exists and has the expected name.
    }

    // MARK: - Continuation Fixture Tests

    /// Test that continuation fixture decodes as assistant event
    func testDecodeContinuationFixture() throws {
        let data: Data
        do {
            data = try loadFixture("ask_user_question_continuation.json")
        } catch FixtureError.noFixtures(let message) {
            throw XCTSkip(message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(ClaudeStreamEvent.self, from: data)

        guard case .assistant(let assistantEvent) = event else {
            XCTFail("Continuation fixture should decode as assistant event")
            return
        }

        print("✓ Decoded continuation: message id=\(assistantEvent.message.id)")

        // Continuation should have text content (assistant's response after tool_result)
        let hasText = assistantEvent.message.content.contains { block in
            if case .text(_) = block {
                return true
            }
            return false
        }

        XCTAssertTrue(hasText, "Continuation should contain text content")
    }

    // MARK: - Content Block Unknown Type Tests

    /// Test that unknown content block types within assistant messages are handled
    func testUnknownContentBlockType() throws {
        // Simulate assistant message with unknown content block type
        let json = """
        {
            "type": "assistant",
            "timestamp": "2026-01-02T12:00:00Z",
            "uuid": "test-uuid",
            "sessionId": "test-session",
            "requestId": "test-request",
            "message": {
                "id": "msg-test",
                "type": "message",
                "role": "assistant",
                "model": "claude-opus-4",
                "content": [
                    {"type": "future_block", "data": "something new"},
                    {"type": "text", "text": "Hello"}
                ],
                "stopReason": null,
                "stopSequence": null,
                "usage": {"inputTokens": 10, "outputTokens": 5}
            }
        }
        """
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        // Should NOT crash - unknown content blocks should be handled
        let event = try decoder.decode(ClaudeStreamEvent.self, from: data)

        guard case .assistant(let assistantEvent) = event else {
            XCTFail("Should decode as assistant event")
            return
        }

        // Should have 2 content blocks (one unknown, one text)
        XCTAssertEqual(assistantEvent.message.content.count, 2)

        // First block should be unknown
        if case .unknown(let type) = assistantEvent.message.content[0] {
            XCTAssertEqual(type, "future_block")
            print("✓ Unknown content block type handled: \(type)")
        } else {
            XCTFail("First content block should be .unknown")
        }

        // Second block should be text
        if case .text(let textBlock) = assistantEvent.message.content[1] {
            XCTAssertEqual(textBlock.text, "Hello")
            print("✓ Text content block preserved")
        } else {
            XCTFail("Second content block should be .text")
        }
    }
}

// MARK: - ToolUseBlock Reference (from NDJSONParser)

/// Reference to existing ToolUseBlock - this test file just uses it, doesn't redefine it.
/// The actual struct is defined in NDJSONParser.swift.
///
/// For reference:
/// ```swift
/// struct ToolUseBlock: Decodable, Sendable {
///     let id: String
///     let name: String
///     let input: [String: AnyCodable]
/// }
/// ```
