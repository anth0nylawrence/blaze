//
// capture_tool_prompt_fixture.swift
// Standalone script to capture AskUserQuestionTool fixtures from Claude CLI.
//
// Usage:
//   swiftc -parse-as-library Blaze/Scripts/capture_tool_prompt_fixture.swift -o /tmp/capture_fixture
//   /tmp/capture_fixture [--include-partial-messages] [--output-dir <path>]
//
// Or run directly with:
//   swift -parse-as-library Blaze/Scripts/capture_tool_prompt_fixture.swift [options]
//
// This script:
//   1. Runs `claude --version` to get CLI version
//   2. Spawns claude with stream-json I/O
//   3. Tries multiple prompt variants to trigger AskUserQuestionTool
//   4. Records all stdout/stderr/stdin to trace files
//   5. Sends a tool_result and waits for continuation
//   6. Saves versioned fixtures to Tests/Fixtures/NDJSON/v<version>/
//

import Foundation

// MARK: - Configuration

struct Config {
    let includePartialMessages: Bool
    let outputDir: URL
    let maxRetriesPerVariant: Int
    let continuationTimeoutSeconds: TimeInterval

    static func parse(args: [String]) -> Config {
        var includePartial = false
        var outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Blaze/Tests/Fixtures/NDJSON")

        var i = 1  // Skip script name
        while i < args.count {
            switch args[i] {
            case "--include-partial-messages":
                includePartial = true
            case "--output-dir":
                i += 1
                if i < args.count {
                    outputDir = URL(fileURLWithPath: args[i])
                }
            default:
                break
            }
            i += 1
        }

        return Config(
            includePartialMessages: includePartial,
            outputDir: outputDir,
            maxRetriesPerVariant: 3,
            continuationTimeoutSeconds: 30
        )
    }
}

// MARK: - Prompt Variants

let promptVariants = [
    // Variant 1: Direct instruction
    """
    You must use the AskUserQuestionTool to ask me which option I prefer:
    Option A: First choice
    Option B: Second choice
    Do not proceed without asking.
    """,

    // Variant 2: Question framing
    """
    Before doing anything, use AskUserQuestionTool to ask me:
    "Which approach do you prefer?"
    Options: A) Quick, B) Thorough
    Wait for my response.
    """,

    // Variant 3: Explicit tool call
    """
    Call the AskUserQuestionTool with these options:
    - Option 1: Yes
    - Option 2: No
    I need to choose before you continue.
    """,
]

// MARK: - Models

struct CaptureResult {
    let success: Bool
    let claudeVersion: String
    let toolUseLine: String?
    let toolResultLine: String?
    let continuationLine: String?
    let toolUseId: String?
    let sessionId: String?
    let promptVariantIndex: Int
    let attemptNumber: Int
    let error: String?
}

// MARK: - ToolResult Envelope (Explicit CodingKeys)

struct ToolResultEnvelope: Encodable {
    let type: String = "user"
    let sessionId: String?
    let message: APIUserMessage

    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case message
    }

    struct APIUserMessage: Encodable {
        let role: String = "user"
        let content: [ToolResultBlock]
    }

    struct ToolResultBlock: Encodable {
        let type: String = "tool_result"
        let toolUseId: String
        let content: String

        enum CodingKeys: String, CodingKey {
            case type
            case toolUseId = "tool_use_id"
            case content
        }
    }
}

// MARK: - Main Entry Point

@main
enum Main {
    static func main() async {
        // Make stdout unbuffered so output appears immediately
        setbuf(stdout, nil)

        let config = Config.parse(args: CommandLine.arguments)

        print("=== Claude Code Fixture Capture ===")
        print("Output directory: \(config.outputDir.path)")
        print("Include partial messages: \(config.includePartialMessages)")
        print()

        // 1. Get Claude version
        let version: String
        do {
            version = try await getClaudeVersion()
            print("✓ Claude CLI version: \(version)")
        } catch {
            print("✗ Failed to get claude version: \(error)")
            exit(1)
        }

        // 2. Create trace directory
        let traceDir: URL
        do {
            traceDir = try createTraceDir()
            print("✓ Trace directory: \(traceDir.path)")
        } catch {
            print("✗ Failed to create trace directory: \(error)")
            exit(1)
        }

        // 3. Try prompt variants until success
        var result: CaptureResult?

        for (variantIndex, prompt) in promptVariants.enumerated() {
            print("\n--- Trying variant \(variantIndex + 1)/\(promptVariants.count) ---")

            for attempt in 1...config.maxRetriesPerVariant {
                print("  Attempt \(attempt)/\(config.maxRetriesPerVariant)...")

                do {
                    result = try await captureWithPrompt(
                        prompt: prompt,
                        config: config,
                        traceDir: traceDir,
                        variantIndex: variantIndex,
                        attemptNumber: attempt
                    )

                    if result?.success == true {
                        print("  ✓ Success!")
                        break
                    } else {
                        print("  ✗ No tool_use or continuation: \(result?.error ?? "unknown")")
                    }
                } catch {
                    print("  ✗ Error: \(error)")
                }

                // Small delay between retries
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            if result?.success == true {
                break
            }
        }

        guard let finalResult = result, finalResult.success else {
            print("\n✗ All variants exhausted. No fixture captured.")
            exit(1)
        }

        // 4. Save fixtures
        do {
            try await saveFixtures(result: finalResult, version: version, config: config, traceDir: traceDir)
            print("\n=== Fixtures saved successfully ===")
            print("Location: \(config.outputDir.path)/v\(version)/")
        } catch {
            print("\n✗ Failed to save fixtures: \(error)")
            exit(1)
        }
    }
}

// MARK: - Claude Version

func getClaudeVersion() async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["claude", "--version"]

    let stdout = Pipe()
    process.standardOutput = stdout
    process.standardError = FileHandle.nullDevice

    try process.run()
    process.waitUntilExit()

    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        throw CaptureError.versionParseFailed
    }

    // Parse version from output like "2.0.76 (Claude Code)" or "claude 1.0.24"
    let parts = output.split(separator: " ")
    guard let firstPart = parts.first else {
        // Return full output if format unexpected
        return output.replacingOccurrences(of: " ", with: "_")
    }
    // First part is the version number (e.g., "2.0.76")
    return String(firstPart)
}

// MARK: - Trace Directory

func createTraceDir() throws -> URL {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate, .withFullTime, .withDashSeparatorInDate]
    let timestamp = formatter.string(from: Date())
        .replacingOccurrences(of: ":", with: "-")

    let baseDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".blaze-traces")
    let traceDir = baseDir.appendingPathComponent(timestamp)

    try FileManager.default.createDirectory(at: traceDir, withIntermediateDirectories: true)
    return traceDir
}

// MARK: - Capture Logic

func captureWithPrompt(
    prompt: String,
    config: Config,
    traceDir: URL,
    variantIndex: Int,
    attemptNumber: Int
) async throws -> CaptureResult {

    // Build args
    var args = [
        "claude",
        "-p", prompt,
        "--output-format", "stream-json",
        "--input-format", "stream-json",
        "--verbose"
    ]
    if config.includePartialMessages {
        args.append("--include-partial-messages")
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = args

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let stdinPipe = Pipe()

    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.standardInput = stdinPipe

    // Trace file handles
    let stdoutTraceURL = traceDir.appendingPathComponent("claude.stdout.jsonl")
    let stdinTraceURL = traceDir.appendingPathComponent("claude.stdin.jsonl")
    let stderrTraceURL = traceDir.appendingPathComponent("claude.stderr.jsonl")

    FileManager.default.createFile(atPath: stdoutTraceURL.path, contents: nil)
    FileManager.default.createFile(atPath: stdinTraceURL.path, contents: nil)
    FileManager.default.createFile(atPath: stderrTraceURL.path, contents: nil)

    let stdoutTrace = try FileHandle(forWritingTo: stdoutTraceURL)
    let stdinTrace = try FileHandle(forWritingTo: stdinTraceURL)
    let stderrTrace = try FileHandle(forWritingTo: stderrTraceURL)

    defer {
        try? stdoutTrace.close()
        try? stdinTrace.close()
        try? stderrTrace.close()
    }

    // State tracking
    var toolUseLine: String?
    var toolUseId: String?
    var sessionId: String?
    var toolResultLine: String?
    var continuationLine: String?
    var sawToolUse = false
    var sentToolResult = false

    // Start process
    try process.run()

    // Read stderr in background (just log to trace)
    Task {
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        try? stderrTrace.write(contentsOf: stderrData)
    }

    // Read stdout line by line
    let stdoutHandle = stdoutPipe.fileHandleForReading
    var lineBuffer = Data()
    let startTime = Date()

    while process.isRunning || stdoutHandle.availableData.count > 0 {
        // Timeout check
        if Date().timeIntervalSince(startTime) > config.continuationTimeoutSeconds {
            process.terminate()
            return CaptureResult(
                success: false,
                claudeVersion: "",
                toolUseLine: toolUseLine,
                toolResultLine: toolResultLine,
                continuationLine: continuationLine,
                toolUseId: toolUseId,
                sessionId: sessionId,
                promptVariantIndex: variantIndex,
                attemptNumber: attemptNumber,
                error: "Timeout waiting for continuation"
            )
        }

        // Read available data
        let chunk = stdoutHandle.availableData
        guard !chunk.isEmpty else {
            try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
            continue
        }

        lineBuffer.append(chunk)

        // Process complete lines
        while let newlineIndex = lineBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = lineBuffer[..<newlineIndex]
            lineBuffer = Data(lineBuffer[(newlineIndex + 1)...])

            // Write to trace
            var traceLineData = Data(lineData)
            traceLineData.append(UInt8(ascii: "\n"))
            try? stdoutTrace.write(contentsOf: traceLineData)

            guard let line = String(data: lineData, encoding: .utf8) else { continue }

            // Parse session_id from system.init
            if sessionId == nil, line.contains("\"subtype\":\"init\"") || line.contains("\"type\":\"system\"") {
                sessionId = extractSessionId(from: line)
            }

            // Look for tool_use with AskUserQuestionTool
            if !sawToolUse, line.contains("AskUserQuestionTool"), line.contains("tool_use") {
                sawToolUse = true
                toolUseLine = line
                toolUseId = extractToolUseId(from: line)

                // Send tool_result
                if let tid = toolUseId {
                    let envelope = ToolResultEnvelope(
                        sessionId: sessionId,
                        message: .init(content: [.init(toolUseId: tid, content: "Option A")])
                    )

                    let encoder = JSONEncoder()
                    if let jsonData = try? encoder.encode(envelope) {
                        var lineData = jsonData
                        lineData.append(UInt8(ascii: "\n"))

                        // Write to stdin
                        stdinPipe.fileHandleForWriting.write(lineData)

                        // Record to trace
                        try? stdinTrace.write(contentsOf: lineData)

                        toolResultLine = String(data: jsonData, encoding: .utf8)
                        sentToolResult = true
                    }
                }
            }

            // Look for continuation after tool_result
            if sentToolResult, continuationLine == nil {
                if line.contains("\"type\":\"assistant\"") {
                    continuationLine = line

                    // Success - terminate process
                    process.terminate()

                    return CaptureResult(
                        success: true,
                        claudeVersion: "",
                        toolUseLine: toolUseLine,
                        toolResultLine: toolResultLine,
                        continuationLine: continuationLine,
                        toolUseId: toolUseId,
                        sessionId: sessionId,
                        promptVariantIndex: variantIndex,
                        attemptNumber: attemptNumber,
                        error: nil
                    )
                }
            }
        }
    }

    return CaptureResult(
        success: false,
        claudeVersion: "",
        toolUseLine: toolUseLine,
        toolResultLine: toolResultLine,
        continuationLine: continuationLine,
        toolUseId: toolUseId,
        sessionId: sessionId,
        promptVariantIndex: variantIndex,
        attemptNumber: attemptNumber,
        error: sawToolUse ? "No continuation after tool_result" : "No AskUserQuestionTool use"
    )
}

// MARK: - JSON Extraction Helpers

func extractToolUseId(from line: String) -> String? {
    // Look for "id":"toolu_..." pattern
    guard let data = line.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
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

func extractSessionId(from line: String) -> String? {
    // Look for "session_id":"..." pattern
    guard let data = line.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }

    return json["session_id"] as? String
}

// MARK: - Save Fixtures

func saveFixtures(result: CaptureResult, version: String, config: Config, traceDir: URL) async throws {
    // Create version directory
    let versionDir = config.outputDir.appendingPathComponent("v\(version)")
    try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true)

    // Save tool_use fixture
    if let toolUseLine = result.toolUseLine {
        let url = versionDir.appendingPathComponent("ask_user_question_tool_use.json")
        try toolUseLine.write(to: url, atomically: true, encoding: .utf8)
        print("  - ask_user_question_tool_use.json")
    }

    // Save tool_result fixture
    if let toolResultLine = result.toolResultLine {
        let url = versionDir.appendingPathComponent("ask_user_question_tool_result.json")
        try toolResultLine.write(to: url, atomically: true, encoding: .utf8)
        print("  - ask_user_question_tool_result.json")
    }

    // Save continuation fixture
    if let continuationLine = result.continuationLine {
        let url = versionDir.appendingPathComponent("ask_user_question_continuation.json")
        try continuationLine.write(to: url, atomically: true, encoding: .utf8)
        print("  - ask_user_question_continuation.json")
    }

    // Save meta.json
    let promptHash = Data(promptVariants[result.promptVariantIndex].utf8).base64EncodedString()
    let meta: [String: Any] = [
        "claude_version": version,
        "capture_date": ISO8601DateFormatter().string(from: Date()),
        "flags": config.includePartialMessages
            ? ["--output-format", "stream-json", "--input-format", "stream-json", "--verbose", "--include-partial-messages"]
            : ["--output-format", "stream-json", "--input-format", "stream-json", "--verbose"],
        "round_trip_success": result.success,
        "prompt_variant_index": result.promptVariantIndex,
        "attempt_number": result.attemptNumber,
        "prompt_hash": "base64:\(promptHash)",
        "tool_use_id": result.toolUseId ?? NSNull(),
        "session_id": result.sessionId ?? NSNull(),
        "trace_dir": traceDir.path
    ]

    let metaURL = versionDir.appendingPathComponent("meta.json")
    let metaData = try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys])
    try metaData.write(to: metaURL)
    print("  - meta.json")

    // Create/update "latest" pointer file
    let latestURL = config.outputDir.appendingPathComponent("latest")
    try "v\(version)".write(to: latestURL, atomically: true, encoding: .utf8)
    print("  - latest (pointer to v\(version))")
}

// MARK: - Errors

enum CaptureError: Error, LocalizedError {
    case versionParseFailed
    case noToolUse
    case noContinuation
    case timeout

    var errorDescription: String? {
        switch self {
        case .versionParseFailed: return "Failed to parse claude --version output"
        case .noToolUse: return "No AskUserQuestionTool use observed"
        case .noContinuation: return "No continuation after tool_result"
        case .timeout: return "Timeout waiting for events"
        }
    }
}
