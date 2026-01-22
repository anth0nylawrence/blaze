import XCTest
@testable import Blaze

/// Conformance tests for tool_result envelope variants.
///
/// These tests empirically validate which tool_result envelope format
/// the Claude CLI accepts by spawning real processes and observing
/// whether a continuation is received.
///
/// Run with: swift test --filter ToolResultConformanceTests
///
/// Note: These tests require:
/// - Claude CLI installed and authenticated
/// - Fixture files in Tests/Fixtures/NDJSON/v*/
final class ToolResultConformanceTests: XCTestCase {

    // MARK: - Fixture Loading

    /// Load a fixture file by name from the latest version directory
    func loadFixture(_ name: String) throws -> Data {
        // Find fixtures directory relative to test bundle
        let testBundle = Bundle(for: type(of: self))
        let testsDir = testBundle.bundleURL
            .deletingLastPathComponent()  // Blaze.xctest
            .deletingLastPathComponent()  // Products
            .deletingLastPathComponent()  // Build
            .deletingLastPathComponent()  // .build
            .appendingPathComponent("Tests")
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("NDJSON")

        // Try to find fixtures in the repo structure
        let repoFixtures = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // BlazeTests
            .deletingLastPathComponent()  // Tests
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("NDJSON")

        let fixturesDir = FileManager.default.fileExists(atPath: testsDir.path)
            ? testsDir
            : repoFixtures

        // Read "latest" pointer
        let latestURL = fixturesDir.appendingPathComponent("latest")
        guard FileManager.default.fileExists(atPath: latestURL.path) else {
            throw FixtureError.noFixtures(
                "No fixtures found. Run: swift Blaze/Scripts/capture_tool_prompt_fixture.swift"
            )
        }

        let version = try String(contentsOf: latestURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let fixtureURL = fixturesDir
            .appendingPathComponent(version)
            .appendingPathComponent(name)

        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw FixtureError.missingFixture(name, version)
        }

        return try Data(contentsOf: fixtureURL)
    }

    // MARK: - parent_tool_use_id Variants

    /// The three variants to test for parent_tool_use_id encoding
    enum ParentToolUseIdVariant: String, CaseIterable {
        case omitted      // Don't include field at all
        case null         // Include as null: "parent_tool_use_id": null
        case setToToolId  // Set to the tool_use_id value
    }

    // MARK: - Tests

    /// Test that fixtures can be loaded (prerequisite for other tests)
    func testFixturesExist() throws {
        // Skip if fixtures don't exist yet
        do {
            let data = try loadFixture("ask_user_question_tool_use.json")
            XCTAssertGreaterThan(data.count, 0, "Fixture should not be empty")
        } catch FixtureError.noFixtures(let message) {
            throw XCTSkip(message)
        }
    }

    /// Test extraction of tool_use_id from fixture
    func testExtractToolUseId() throws {
        let data: Data
        do {
            data = try loadFixture("ask_user_question_tool_use.json")
        } catch FixtureError.noFixtures(let message) {
            throw XCTSkip(message)
        }

        let toolUseId = try extractToolUseId(from: data)
        XCTAssertNotNil(toolUseId, "Should extract tool_use_id from fixture")
        XCTAssertTrue(toolUseId?.hasPrefix("toolu_") ?? false, "tool_use_id should start with toolu_")
    }

    /// Test extraction of session_id from fixture
    func testExtractSessionId() throws {
        let data: Data
        do {
            data = try loadFixture("ask_user_question_tool_use.json")
        } catch FixtureError.noFixtures(let message) {
            throw XCTSkip(message)
        }

        let sessionId = try extractSessionId(from: data)
        // session_id may or may not be present
        if let sid = sessionId {
            XCTAssertGreaterThan(sid.count, 0, "session_id should not be empty if present")
        }
    }

    /// Test that all three envelope variants can be generated
    func testGenerateEnvelopeVariants() throws {
        let data: Data
        do {
            data = try loadFixture("ask_user_question_tool_use.json")
        } catch FixtureError.noFixtures(let message) {
            throw XCTSkip(message)
        }

        guard let toolUseId = try extractToolUseId(from: data) else {
            XCTFail("Could not extract tool_use_id")
            return
        }

        let sessionId = try extractSessionId(from: data)

        // Generate all variants
        for variant in ParentToolUseIdVariant.allCases {
            let envelope = makeEnvelope(
                sessionId: sessionId,
                toolUseId: toolUseId,
                content: "Option A",
                parentToolUseIdVariant: variant
            )

            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(envelope)
            let jsonString = String(data: jsonData, encoding: .utf8)!

            // Verify structure
            XCTAssertTrue(jsonString.contains("\"type\":\"user\""), "Envelope should have type user")
            XCTAssertTrue(jsonString.contains("\"tool_result\""), "Envelope should have tool_result block")
            XCTAssertTrue(jsonString.contains(toolUseId), "Envelope should contain tool_use_id")

            // Verify variant-specific behavior
            switch variant {
            case .omitted:
                XCTAssertFalse(jsonString.contains("parent_tool_use_id"),
                    "Omitted variant should not contain parent_tool_use_id")
            case .null:
                XCTAssertTrue(jsonString.contains("\"parent_tool_use_id\":null"),
                    "Null variant should contain parent_tool_use_id:null")
            case .setToToolId:
                XCTAssertTrue(jsonString.contains("\"parent_tool_use_id\":\"\(toolUseId)\""),
                    "SetToToolId variant should contain parent_tool_use_id with tool_use_id value")
            }

            print("✓ Variant \(variant.rawValue): \(jsonString.prefix(100))...")
        }
    }

    /// Live conformance test - requires Claude CLI
    ///
    /// This test spawns real Claude CLI processes to determine which
    /// parent_tool_use_id variant produces a continuation response.
    ///
    /// Run manually with: swift test --filter testToolResultConformanceLive
    func testToolResultConformanceLive() async throws {
        // Skip if fixtures don't exist
        let data: Data
        do {
            data = try loadFixture("ask_user_question_tool_use.json")
        } catch FixtureError.noFixtures(let message) {
            throw XCTSkip(message)
        }

        guard let toolUseId = try extractToolUseId(from: data) else {
            XCTFail("Could not extract tool_use_id")
            return
        }

        let sessionId = try extractSessionId(from: data)

        print("\n=== Tool Result Conformance Test ===")
        print("tool_use_id: \(toolUseId)")
        print("session_id: \(sessionId ?? "nil")")
        print()

        var workingVariant: ParentToolUseIdVariant?
        var workingEnvelopeJSON: String?

        for variant in ParentToolUseIdVariant.allCases {
            print("Testing variant: \(variant.rawValue)")

            let envelope = makeEnvelope(
                sessionId: sessionId,
                toolUseId: toolUseId,
                content: "Option A",
                parentToolUseIdVariant: variant
            )

            let result = await replayToolResult(envelope: envelope)

            if result.sawContinuation {
                print("  ✅ SUCCESS - saw continuation")
                workingVariant = variant
                workingEnvelopeJSON = result.envelopeJSON
                break
            } else {
                print("  ❌ FAILED - \(result.error ?? "no continuation")")
            }
        }

        if let winner = workingVariant, let json = workingEnvelopeJSON {
            print("\n=== WINNER: \(winner.rawValue) ===")
            print("Working envelope:")
            print(json)
        } else {
            XCTFail("No parent_tool_use_id variant produced continuation")
        }
    }

    // MARK: - Helpers

    /// Extract tool_use_id from fixture JSON
    private func extractToolUseId(from data: Data) throws -> String? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Navigate: message.content[].id where type=tool_use
        if let message = json["message"] as? [String: Any],
           let content = message["content"] as? [[String: Any]] {
            for block in content {
                if block["type"] as? String == "tool_use",
                   let id = block["id"] as? String {
                    return id
                }
            }
        }

        return nil
    }

    /// Extract session_id from fixture JSON
    private func extractSessionId(from data: Data) throws -> String? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["session_id"] as? String
    }

    /// Create tool_result envelope with specified variant
    private func makeEnvelope(
        sessionId: String?,
        toolUseId: String,
        content: String,
        parentToolUseIdVariant: ParentToolUseIdVariant
    ) -> ToolResultEnvelope {
        switch parentToolUseIdVariant {
        case .omitted:
            return ToolResultEnvelope(
                sessionId: sessionId,
                parentToolUseId: .omitted,
                toolUseId: toolUseId,
                content: content
            )
        case .null:
            return ToolResultEnvelope(
                sessionId: sessionId,
                parentToolUseId: .explicit(nil),
                toolUseId: toolUseId,
                content: content
            )
        case .setToToolId:
            return ToolResultEnvelope(
                sessionId: sessionId,
                parentToolUseId: .explicit(toolUseId),
                toolUseId: toolUseId,
                content: content
            )
        }
    }

    /// Replay tool_result against Claude CLI and observe continuation
    private func replayToolResult(envelope: ToolResultEnvelope) async -> ReplayResult {
        // Build prompt that should trigger AskUserQuestionTool
        let prompt = """
        You must use the AskUserQuestionTool to ask me which option I prefer:
        Option A: First choice
        Option B: Second choice
        Do not proceed without asking.
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "claude",
            "-p", prompt,
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--verbose"
        ]

        let stdoutPipe = Pipe()
        let stdinPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardInput = stdinPipe
        process.standardError = FileHandle.nullDevice

        // Encode envelope
        let encoder = JSONEncoder()
        guard let envelopeData = try? encoder.encode(envelope),
              let envelopeJSON = String(data: envelopeData, encoding: .utf8) else {
            return ReplayResult(sawContinuation: false, envelopeJSON: nil, error: "Failed to encode envelope")
        }

        do {
            try process.run()
        } catch {
            return ReplayResult(sawContinuation: false, envelopeJSON: envelopeJSON, error: "Failed to start process: \(error)")
        }

        var sawToolUse = false
        var sentToolResult = false
        var sawContinuation = false
        var lineBuffer = Data()
        let startTime = Date()
        let timeout: TimeInterval = 30

        let stdoutHandle = stdoutPipe.fileHandleForReading

        while process.isRunning || stdoutHandle.availableData.count > 0 {
            if Date().timeIntervalSince(startTime) > timeout {
                process.terminate()
                return ReplayResult(sawContinuation: false, envelopeJSON: envelopeJSON, error: "Timeout")
            }

            let chunk = stdoutHandle.availableData
            guard !chunk.isEmpty else {
                try? await Task.sleep(nanoseconds: 50_000_000)
                continue
            }

            lineBuffer.append(chunk)

            while let newlineIndex = lineBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = lineBuffer[..<newlineIndex]
                lineBuffer = Data(lineBuffer[(newlineIndex + 1)...])

                guard let line = String(data: lineData, encoding: .utf8) else { continue }

                // Detect tool_use with AskUserQuestionTool
                if !sawToolUse, line.contains("AskUserQuestionTool"), line.contains("tool_use") {
                    sawToolUse = true

                    // Send our tool_result envelope
                    var lineToSend = envelopeData
                    lineToSend.append(UInt8(ascii: "\n"))
                    stdinPipe.fileHandleForWriting.write(lineToSend)
                    sentToolResult = true
                }

                // Detect continuation after tool_result
                if sentToolResult, !sawContinuation {
                    if line.contains("\"type\":\"assistant\"") {
                        sawContinuation = true
                        process.terminate()
                        return ReplayResult(sawContinuation: true, envelopeJSON: envelopeJSON, error: nil)
                    }
                }
            }
        }

        return ReplayResult(
            sawContinuation: sawContinuation,
            envelopeJSON: envelopeJSON,
            error: sawToolUse ? "No continuation after tool_result" : "No tool_use observed"
        )
    }
}

// MARK: - Supporting Types

/// Result of replaying a tool_result against Claude CLI
private struct ReplayResult {
    let sawContinuation: Bool
    let envelopeJSON: String?
    let error: String?
}

/// Errors related to fixture loading
enum FixtureError: Error, LocalizedError {
    case noFixtures(String)
    case missingFixture(String, String)

    var errorDescription: String? {
        switch self {
        case .noFixtures(let message):
            return message
        case .missingFixture(let name, let version):
            return "Fixture '\(name)' not found in version \(version)"
        }
    }
}

// MARK: - ToolResultEnvelope (with explicit CodingKeys)

/// Optional field handling for parent_tool_use_id
enum OptionalField<T: Codable>: Codable {
    case omitted          // Don't include in JSON
    case explicit(T?)     // Include as null or value

    func encode(to encoder: Encoder) throws {
        switch self {
        case .omitted:
            // Skip encoding entirely - handled in parent
            break
        case .explicit(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .explicit(nil)
        } else {
            self = .explicit(try container.decode(T.self))
        }
    }
}

/// Tool result envelope with explicit CodingKeys (no convertToSnakeCase)
struct ToolResultEnvelope: Encodable {
    let type: String = "user"
    let sessionId: String?
    let parentToolUseId: OptionalField<String>
    let toolUseId: String
    let content: String

    // Explicit CodingKeys - no encoder magic
    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case parentToolUseId = "parent_tool_use_id"
        case message
    }

    enum MessageKeys: String, CodingKey {
        case role
        case content
    }

    enum ToolResultKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case content
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // type
        try container.encode(type, forKey: .type)

        // session_id (optional)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)

        // parent_tool_use_id (conditional encoding based on variant)
        switch parentToolUseId {
        case .omitted:
            // Don't encode the field at all
            break
        case .explicit(let value):
            // Encode as null or value
            try container.encode(value, forKey: .parentToolUseId)
        }

        // message
        var messageContainer = container.nestedContainer(keyedBy: MessageKeys.self, forKey: .message)
        try messageContainer.encode("user", forKey: .role)

        // content array with tool_result block
        var contentArray = messageContainer.nestedUnkeyedContainer(forKey: .content)
        var toolResultContainer = contentArray.nestedContainer(keyedBy: ToolResultKeys.self)
        try toolResultContainer.encode("tool_result", forKey: .type)
        try toolResultContainer.encode(toolUseId, forKey: .toolUseId)
        try toolResultContainer.encode(content, forKey: .content)
    }
}
