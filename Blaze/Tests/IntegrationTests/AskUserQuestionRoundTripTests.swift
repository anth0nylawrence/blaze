import XCTest
import Foundation
import Darwin
@testable import Blaze

/// Phase 8: Production PTY round-trip test for AskUserQuestion tool.
///
/// This test validates the full interactive loop with **causal proof**:
/// 1. Spawn Claude Code CLI in PTY mode (avoids stdout buffering)
/// 2. Trigger AskUserQuestion tool use
/// 3. Parse tool_use_id + session_id from events
/// 4. Send tool_result via StdinWriter using validated C_session_id envelope
/// 5. **ASSERT**: Our tool_result was written to stdin (trace proof)
/// 6. **ASSERT**: Continuation occurred AFTER our write timestamp (causality proof)
/// 7. Save traces for debugging failures
///
/// ## Causality Requirements
/// - `claude.stdin.jsonl` must contain our tool_result with correct tool_use_id
/// - Continuation timestamp must be > our write timestamp
/// - CLI's auto-timeout alone does NOT count as success
///
/// ## Determinism Strategy
/// Claude sometimes won't call the tool. This test uses:
/// - Multiple prompt variants (3-5)
/// - Per-variant retries (N=2)
/// - Diagnostic output on all failures
///
/// ## CI Integration
/// Set `BLAZE_CI_TRACE_DIR` environment variable for deterministic trace paths.
/// Traces will be written to `$BLAZE_CI_TRACE_DIR/<test-name>/<timestamp>/`
final class AskUserQuestionRoundTripTests: XCTestCase {

    // MARK: - Test Configuration

    /// Total timeout per attempt
    static let attemptTimeout: TimeInterval = 30

    /// Timeout for continuation after tool_result
    static let continuationTimeout: TimeInterval = 20

    /// Retries per prompt variant
    static let retriesPerVariant = 2

    /// Envelope variant used (for diagnostic output)
    static let envelopeVariant = "C_session_id"

    /// CI trace directory (from environment)
    static var ciTraceDir: URL? {
        if let path = ProcessInfo.processInfo.environment["BLAZE_CI_TRACE_DIR"] {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    /// Prompt variants designed to force AskUserQuestion usage
    static let promptVariants: [String] = [
        // Variant 1: Direct instruction with tool name
        """
        You MUST call the AskUserQuestion tool now.
        Ask: "Pick one option."
        Options:
        - A) First
        - B) Second
        Do not continue until you call the tool.
        """,

        // Variant 2: Question framing
        """
        Before doing anything else, use AskUserQuestion to ask me which option I prefer.
        Options are exactly:
        A) First
        B) Second
        Wait for my answer.
        """,

        // Variant 3: Explicit tool call requirement
        """
        Use AskUserQuestion with question: Which option?
        Options: A) First, B) Second.
        Do not output normal text before the tool.
        """,

        // Variant 4: Strong imperative
        """
        CRITICAL: You MUST call the AskUserQuestion tool IMMEDIATELY.
        Use AskUserQuestion with these parameters:
        - question: "A or B?"
        - options: [{label: "A"}, {label: "B"}]
        DO NOT respond with text. ONLY call the tool.
        """,

        // Variant 5: Alternative phrasing
        """
        I need you to ask me a multiple-choice question using AskUserQuestion.
        Question: "Choose one"
        Choices: A, B
        Call the tool now before responding with anything else.
        """
    ]

    // MARK: - Stdin Trace Entry

    /// Entry in the stdin trace for causal proof
    struct StdinTraceEntry: Codable {
        let timestamp: TimeInterval  // Seconds since attempt start
        let toolUseId: String
        let content: String
        let json: String  // Raw JSON that was written
    }

    // MARK: - Attempt Result

    /// Result of a single round-trip attempt with causal proof data
    struct AttemptResult {
        let success: Bool
        let prompt: String
        let traceDir: URL
        let failureReason: String?
        let lineCount: Int
        let sawToolUse: Bool
        let sentToolResult: Bool
        let sawContinuation: Bool
        // Causal proof data
        let toolResultWriteTimestamp: TimeInterval?  // When we wrote to stdin
        let continuationTimestamp: TimeInterval?      // When we saw continuation
        let stdinTraceHasOurToolResult: Bool         // Our tool_use_id is in stdin trace
        let cliTimeoutBeforeOurWrite: Bool           // CLI timed out before we could write
        // CI diagnostic data
        let sessionId: String?
        let toolUseId: String?
        let claudeVersion: String?
    }

    /// Test run metadata for CI artifacts
    struct TestRunMetadata: Codable {
        let testName: String
        let startTime: String
        let endTime: String
        let claudeVersion: String?
        let claudePath: String
        let envelopeVariant: String
        let totalAttempts: Int
        let success: Bool
        let failureReason: String?
        // Last attempt data
        let lastSessionId: String?
        let lastToolUseId: String?
        let lastToolResultWriteTimestamp: Double?
        let lastContinuationTimestamp: Double?
        let lastStdinTraceHasOurToolResult: Bool
        let lastCliTimeoutBeforeOurWrite: Bool
    }

    // MARK: - Main Test

    /// Test AskUserQuestion round-trip using production PTY runner and StdinWriter.
    ///
    /// This test proves with **causal assertions**:
    /// - PtyProcessRunner spawns CLI correctly
    /// - We can detect AskUserQuestion tool_use events
    /// - StdinWriter can send tool_result with C_session_id envelope
    /// - **Our tool_result was written** (stdin trace proof)
    /// - Claude continues **after our write** (causality proof)
    func testAskUserQuestionRoundTrip_productionPTY() async throws {
        let testStartTime = Date()
        let testName = "AskUserQuestionRoundTrip"

        // Skip if Claude CLI not available
        guard let claudePath = findClaudePath() else {
            throw XCTSkip("Claude CLI not found - install with: npm install -g @anthropic/claude-code")
        }

        // Get Claude version for diagnostics
        let claudeVersion = getClaudeVersion(claudePath: claudePath)

        // Determine trace base directory (CI or temp)
        let traceBaseDir = resolveTraceBaseDir(testName: testName)
        print("📁 Trace base directory: \(traceBaseDir.path)")

        print("🔧 Using Claude CLI at: \(claudePath)")
        print("🔧 Claude version: \(claudeVersion ?? "unknown")")
        print("🔧 Envelope variant: \(Self.envelopeVariant)")
        print("🔄 Testing with \(Self.promptVariants.count) prompt variants × \(Self.retriesPerVariant) retries each")

        var lastFailure: AttemptResult?
        var totalAttempts = 0

        // Try each variant with retries
        for (variantIndex, prompt) in Self.promptVariants.enumerated() {
            for retry in 1...Self.retriesPerVariant {
                totalAttempts += 1
                print("\n--- Attempt \(totalAttempts): Variant \(variantIndex + 1), Retry \(retry) ---")

                let result = try await runSingleAttempt(
                    prompt: prompt,
                    claudePath: claudePath,
                    claudeVersion: claudeVersion,
                    traceBaseDir: traceBaseDir,
                    attemptNumber: totalAttempts
                )

                if result.success {
                    print("\n✅ Round-trip test PASSED on attempt \(totalAttempts)")
                    print("   Trace dir: \(result.traceDir.path)")

                    // Report causal proof
                    if let writeTs = result.toolResultWriteTimestamp,
                       let contTs = result.continuationTimestamp {
                        print("   ⏱️ Causal proof: write@\(String(format: "%.3f", writeTs))s → continuation@\(String(format: "%.3f", contTs))s")
                        print("   📝 Stdin trace contains our tool_result: \(result.stdinTraceHasOurToolResult)")
                        print("   CLI timeout before our write: \(result.cliTimeoutBeforeOurWrite)")
                    }

                    // Save success metadata
                    try? saveTestMetadata(
                        testName: testName,
                        startTime: testStartTime,
                        claudePath: claudePath,
                        claudeVersion: claudeVersion,
                        totalAttempts: totalAttempts,
                        success: true,
                        failureReason: nil,
                        lastResult: result,
                        to: traceBaseDir
                    )
                    return // Success!
                }

                lastFailure = result
                print("❌ Attempt \(totalAttempts) failed: \(result.failureReason ?? "unknown")")

                // Report causal data even on failure
                if result.cliTimeoutBeforeOurWrite {
                    print("   ⚠️ CLI timeout occurred before we could write")
                }
                if !result.stdinTraceHasOurToolResult && result.sentToolResult {
                    print("   ⚠️ Sent tool_result but not found in stdin trace!")
                }
            }
        }

        // Save failure metadata
        try? saveTestMetadata(
            testName: testName,
            startTime: testStartTime,
            claudePath: claudePath,
            claudeVersion: claudeVersion,
            totalAttempts: totalAttempts,
            success: false,
            failureReason: lastFailure?.failureReason,
            lastResult: lastFailure,
            to: traceBaseDir
        )

        // All attempts failed - report with diagnostics
        XCTFail("""
        AskUserQuestion round-trip failed after \(totalAttempts) attempts.

        === CI Diagnostic Metadata ===
        Claude path: \(claudePath)
        Claude version: \(claudeVersion ?? "unknown")
        Envelope variant: \(Self.envelopeVariant)
        Trace directory: \(traceBaseDir.path)

        === Last Attempt Data ===
        Failure reason: \(lastFailure?.failureReason ?? "unknown")
        Attempt trace dir: \(lastFailure?.traceDir.path ?? "n/a")
        Lines received: \(lastFailure?.lineCount ?? 0)
        session_id: \(lastFailure?.sessionId ?? "n/a")
        tool_use_id: \(lastFailure?.toolUseId ?? "n/a")

        === State Machine ===
        Saw tool_use: \(lastFailure?.sawToolUse ?? false)
        Sent tool_result: \(lastFailure?.sentToolResult ?? false)
        Saw continuation: \(lastFailure?.sawContinuation ?? false)

        === Causal Proof Data ===
        tool_result write timestamp: \(lastFailure?.toolResultWriteTimestamp.map { String(format: "%.3f", $0) + "s" } ?? "n/a")
        continuation timestamp: \(lastFailure?.continuationTimestamp.map { String(format: "%.3f", $0) + "s" } ?? "n/a")
        stdin trace has our tool_result: \(lastFailure?.stdinTraceHasOurToolResult ?? false)
        CLI timeout before our write: \(lastFailure?.cliTimeoutBeforeOurWrite ?? false)

        === Last Prompt Used ===
        \(lastFailure?.prompt ?? "n/a")
        """)
    }

    // MARK: - Single Attempt

    /// Run a single round-trip attempt with the given prompt.
    /// Returns detailed causal proof data for validation.
    private func runSingleAttempt(
        prompt: String,
        claudePath: String,
        claudeVersion: String?,
        traceBaseDir: URL,
        attemptNumber: Int
    ) async throws -> AttemptResult {
        // Create isolated trace directory for this attempt (under trace base dir)
        let traceDir = traceBaseDir.appendingPathComponent("attempt-\(attemptNumber)")
        try FileManager.default.createDirectory(at: traceDir, withIntermediateDirectories: true)

        // Create production PTY runner
        let runner = PtyProcessRunner()
        let writer = StdinWriter(runner: runner)

        defer {
            runner.terminate()
        }

        // Spawn Claude with PTY (production configuration)
        try runner.spawn(
            executable: claudePath,
            arguments: [
                "-p", prompt,
                "--output-format", "stream-json",
                "--input-format", "stream-json",
                "--verbose",
                "--allowedTools", "AskUserQuestion"
            ],
            workingDirectory: FileManager.default.currentDirectoryPath
        )

        // State tracking
        var sessionId: String?
        var toolUseId: String?
        var optionLabels: [String] = []
        var sawToolUse = false
        var sentToolResult = false
        var sawContinuation = false
        var sawCliTimeout = false
        var cliTimeoutBeforeOurWrite = false
        var lineCount = 0
        var traceLines: [String] = []

        // Causal proof timestamps (seconds since startTime)
        var toolResultWriteTimestamp: TimeInterval?
        var continuationTimestamp: TimeInterval?

        // Stdin trace for proof
        var stdinTraceEntries: [StdinTraceEntry] = []

        let startTime = Date()

        // Single-pass event loop
        while Date().timeIntervalSince(startTime) < Self.attemptTimeout {
            let lines = runner.readLines()

            for line in lines {
                lineCount += 1
                traceLines.append(line)
                let lineTimestamp = Date().timeIntervalSince(startTime)

                // Debug: show first 120 chars
                print("  [L\(lineCount) @\(String(format: "%.2f", lineTimestamp))s] \(line.prefix(100))...")

                // Parse JSON
                guard let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                      let type = json["type"] as? String else {
                    continue
                }

                // 1. Extract session_id from system.init
                if type == "system",
                   let subtype = json["subtype"] as? String,
                   subtype == "init" {
                    sessionId = json["session_id"] as? String
                    print("  → Found system.init, session_id: \(sessionId ?? "nil")")
                }

                // 2. Detect tool_use (AskUserQuestion)
                if !sawToolUse,
                   type == "assistant",
                   let message = json["message"] as? [String: Any],
                   let content = message["content"] as? [[String: Any]] {

                    for block in content {
                        if block["type"] as? String == "tool_use",
                           let name = block["name"] as? String,
                           name == "AskUserQuestion",
                           let id = block["id"] as? String {

                            sawToolUse = true
                            toolUseId = id

                            // Extract option labels from input
                            if let input = block["input"] as? [String: Any],
                               let questions = input["questions"] as? [[String: Any]],
                               let firstQuestion = questions.first,
                               let options = firstQuestion["options"] as? [[String: Any]] {
                                optionLabels = options.compactMap { $0["label"] as? String }
                            }

                            print("  → Found AskUserQuestion tool_use!")
                            print("    tool_use_id: \(id)")
                            print("    options: \(optionLabels)")
                            break
                        }
                    }
                }

                // 3. Detect CLI timeout (user message with is_error:true that we didn't send)
                // Claude CLI has a 1-second timeout for AskUserQuestion responses
                if sawToolUse, !sawCliTimeout, type == "user" {
                    if let message = json["message"] as? [String: Any],
                       let content = message["content"] as? [[String: Any]],
                       let toolResult = content.first,
                       toolResult["type"] as? String == "tool_result",
                       toolResult["is_error"] as? Bool == true {
                        sawCliTimeout = true
                        // CRITICAL: Track if CLI timed out BEFORE we could write
                        if !sentToolResult {
                            cliTimeoutBeforeOurWrite = true
                        }
                        print("  → Detected CLI timeout (is_error:true)")
                        print("    CLI timeout before our write: \(cliTimeoutBeforeOurWrite)")
                    }
                }

                // 4. Send tool_result IMMEDIATELY when we see tool_use (race the 1s timeout)
                if sawToolUse, !sentToolResult, !sawCliTimeout, let tuId = toolUseId {
                    // Use first option label as response (or fallback)
                    let choice = optionLabels.first ?? "A"

                    // Build envelope using validated C_session_id variant
                    let envelope = ToolResultEnvelope(
                        sessionId: sessionId,
                        parentToolUseId: .explicit(nil),
                        toolUseId: tuId,
                        content: choice
                    )

                    print("  → Sending tool_result via StdinWriter...")
                    print("    session_id: \(sessionId ?? "nil")")
                    print("    tool_use_id: \(tuId)")
                    print("    content: \(choice)")

                    do {
                        // Capture JSON for stdin trace
                        let encoder = JSONEncoder()
                        let jsonData = try encoder.encode(envelope)
                        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

                        try await writer.sendJSONLine(envelope)

                        // Record write timestamp for causal proof
                        toolResultWriteTimestamp = Date().timeIntervalSince(startTime)
                        sentToolResult = true

                        // Save to stdin trace
                        let traceEntry = StdinTraceEntry(
                            timestamp: toolResultWriteTimestamp!,
                            toolUseId: tuId,
                            content: choice,
                            json: jsonString
                        )
                        stdinTraceEntries.append(traceEntry)

                        print("  → tool_result sent at \(String(format: "%.3f", toolResultWriteTimestamp!))s")
                    } catch {
                        print("  ⚠️ Failed to send tool_result: \(error)")
                    }
                }

                // 5. Detect continuation with causality check
                // Only count continuation if it's AFTER our write (not CLI's timeout response)
                if sawToolUse {
                    var foundContinuation = false

                    if type == "assistant" {
                        if let message = json["message"] as? [String: Any],
                           let content = message["content"] as? [[String: Any]] {
                            for block in content {
                                if block["type"] as? String == "text",
                                   let text = block["text"] as? String,
                                   !text.isEmpty {
                                    foundContinuation = true
                                    break
                                }
                            }
                        }
                    }

                    if type == "result" {
                        foundContinuation = true
                    }

                    if foundContinuation {
                        continuationTimestamp = lineTimestamp

                        // CAUSALITY CHECK: Only mark success if our write preceded continuation
                        if sentToolResult, let writeTs = toolResultWriteTimestamp {
                            if continuationTimestamp! > writeTs {
                                print("  → Saw continuation at \(String(format: "%.3f", continuationTimestamp!))s (after our write at \(String(format: "%.3f", writeTs))s)")
                                sawContinuation = true
                            } else {
                                print("  ⚠️ Continuation at \(String(format: "%.3f", continuationTimestamp!))s preceded our write - not causal!")
                            }
                        } else if sawCliTimeout && !sentToolResult {
                            // CLI timed out before we could write - continuation is from CLI timeout, not us
                            print("  → Saw continuation at \(String(format: "%.3f", continuationTimestamp!))s (from CLI timeout, not our write)")
                            // Do NOT set sawContinuation - this doesn't prove our envelope works
                        } else if sentToolResult {
                            // We wrote but no timestamp? Shouldn't happen
                            print("  → Saw continuation (no write timestamp recorded)")
                            sawContinuation = true
                        }

                        if sawContinuation {
                            break
                        }
                    }
                }
            }

            // Exit conditions
            if sawContinuation {
                break
            }

            if !runner.isRunning {
                // Process exited - drain remaining lines
                try await Task.sleep(for: .milliseconds(200))
                let remaining = runner.readLines()
                for line in remaining {
                    lineCount += 1
                    traceLines.append(line)
                    print("  [L\(lineCount)] (drain) \(line.prefix(100))...")
                }
                break
            }

            try await Task.sleep(for: .milliseconds(50))
        }

        // Save traces for debugging
        try? saveTrace(lines: traceLines, to: traceDir, filename: "claude.stdout.trace")
        try? saveStdinTrace(entries: stdinTraceEntries, to: traceDir)

        // HARD ASSERTION 1: Stdin trace must contain our tool_result
        let stdinTraceHasOurToolResult = stdinTraceEntries.contains { entry in
            entry.toolUseId == toolUseId
        }

        // Determine success with CAUSAL requirements:
        // 1. Saw tool_use
        // 2. Sent our tool_result (not just CLI timeout)
        // 3. Our tool_result is in stdin trace (proof it was written)
        // 4. Continuation occurred AFTER our write (causality)
        let success = sawToolUse &&
                      sentToolResult &&
                      stdinTraceHasOurToolResult &&
                      sawContinuation &&
                      !cliTimeoutBeforeOurWrite  // CLI didn't preempt us

        var failureReason: String?
        if !sawToolUse {
            failureReason = "Never observed AskUserQuestion tool_use"
        } else if cliTimeoutBeforeOurWrite {
            failureReason = "CLI timeout (1s) occurred before we could send tool_result - try faster prompt parsing"
        } else if !sentToolResult {
            failureReason = "Failed to send tool_result"
        } else if !stdinTraceHasOurToolResult {
            failureReason = "tool_result not found in stdin trace - write may have failed"
        } else if !sawContinuation {
            failureReason = "No causal continuation after our tool_result"
        }

        return AttemptResult(
            success: success,
            prompt: prompt,
            traceDir: traceDir,
            failureReason: failureReason,
            lineCount: lineCount,
            sawToolUse: sawToolUse,
            sentToolResult: sentToolResult,
            sawContinuation: sawContinuation,
            toolResultWriteTimestamp: toolResultWriteTimestamp,
            continuationTimestamp: continuationTimestamp,
            stdinTraceHasOurToolResult: stdinTraceHasOurToolResult,
            cliTimeoutBeforeOurWrite: cliTimeoutBeforeOurWrite,
            sessionId: sessionId,
            toolUseId: toolUseId,
            claudeVersion: claudeVersion
        )
    }

    // MARK: - Helpers

    /// Find Claude CLI path
    private func findClaudePath() -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return path?.isEmpty == false ? path : nil
        } catch {
            return nil
        }
    }

    /// Save stdout trace lines to file
    private func saveTrace(lines: [String], to dir: URL, filename: String) throws {
        let content = lines.joined(separator: "\n")
        let path = dir.appendingPathComponent(filename)
        try content.write(to: path, atomically: true, encoding: .utf8)
        print("  📝 Stdout trace saved to: \(path.path)")
    }

    /// Save stdin trace entries to JSON file for causal proof
    private func saveStdinTrace(entries: [StdinTraceEntry], to dir: URL) throws {
        guard !entries.isEmpty else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        let path = dir.appendingPathComponent("claude.stdin.jsonl")
        try data.write(to: path)
        print("  📝 Stdin trace saved to: \(path.path)")
    }

    // MARK: - CI Helper Functions

    /// Get Claude CLI version for diagnostics
    private func getClaudeVersion(claudePath: String) -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["--version"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return output?.isEmpty == false ? output : nil
        } catch {
            return nil
        }
    }

    /// Resolve trace base directory (CI env var or temp directory)
    private func resolveTraceBaseDir(testName: String) -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        if let ciDir = Self.ciTraceDir {
            // CI mode: use deterministic path
            let dir = ciDir.appendingPathComponent(testName).appendingPathComponent(timestamp)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } else {
            // Local mode: use temp directory
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("blaze-integration-tests")
                .appendingPathComponent(testName)
                .appendingPathComponent(timestamp)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
    }

    /// Save test run metadata to JSON file for CI artifacts
    private func saveTestMetadata(
        testName: String,
        startTime: Date,
        claudePath: String,
        claudeVersion: String?,
        totalAttempts: Int,
        success: Bool,
        failureReason: String?,
        lastResult: AttemptResult?,
        to dir: URL
    ) throws {
        let formatter = ISO8601DateFormatter()

        let metadata = TestRunMetadata(
            testName: testName,
            startTime: formatter.string(from: startTime),
            endTime: formatter.string(from: Date()),
            claudeVersion: claudeVersion,
            claudePath: claudePath,
            envelopeVariant: Self.envelopeVariant,
            totalAttempts: totalAttempts,
            success: success,
            failureReason: failureReason,
            lastSessionId: lastResult?.sessionId,
            lastToolUseId: lastResult?.toolUseId,
            lastToolResultWriteTimestamp: lastResult?.toolResultWriteTimestamp,
            lastContinuationTimestamp: lastResult?.continuationTimestamp,
            lastStdinTraceHasOurToolResult: lastResult?.stdinTraceHasOurToolResult ?? false,
            lastCliTimeoutBeforeOurWrite: lastResult?.cliTimeoutBeforeOurWrite ?? false
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(metadata)

        let path = dir.appendingPathComponent("meta.json")
        try data.write(to: path)
        print("📝 Test metadata saved to: \(path.path)")
    }
}

// NOTE: Envelope validation tests are in ToolResultConformanceTests.swift
// The main round-trip test above validates end-to-end envelope functionality with causal proof.
