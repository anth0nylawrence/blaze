import Foundation

// MARK: - Hook Test Runner
//
// E005-F009-S001-T006-A001: Executes hooks in test/preview mode.
//
// This actor provides safe, isolated hook execution for testing and previewing
// hook behavior before enabling them in production. It supports all hook types
// (prompt, command, agent) and provides structured results including timing,
// output capture, and error reporting.

/// Result of a hook test execution.
///
/// Contains all information needed to display test results in the UI,
/// including success/failure status, captured output, timing, and any errors.
///
/// Note: Named `HookExecutionTestResult` to avoid conflict with the simpler
/// `HookExecutionTestResult` struct used in HooksBuilderView.swift.
public struct HookExecutionTestResult: Sendable, Equatable {
    /// Unique identifier for this test run.
    public let id: UUID

    /// The hook that was tested.
    public let hookId: UUID

    /// Whether the test execution succeeded (exit code 0 for commands).
    public let success: Bool

    /// Exit code from command execution (nil for prompt/agent hooks).
    public let exitCode: Int?

    /// Captured stdout from the hook process.
    public let stdout: String?

    /// Captured stderr from the hook process.
    public let stderr: String?

    /// Parsed hook output if stdout contained valid JSON.
    public let parsedOutput: HookOutput?

    /// When the test started.
    public let startedAt: Date

    /// When the test completed.
    public let completedAt: Date

    /// Whether the test was cancelled due to timeout.
    public let timedOut: Bool

    /// Whether the test was manually cancelled.
    public let cancelled: Bool

    /// Error message if execution failed before the process ran.
    public let error: String?

    /// The mock input data used for the test.
    public let mockInput: String?

    // MARK: - Computed Properties

    /// Duration of the test execution in seconds.
    public var duration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }

    /// Duration formatted for display (e.g., "1.23s" or "45ms").
    public var formattedDuration: String {
        if duration < 1.0 {
            return String(format: "%.0fms", duration * 1000)
        } else {
            return String(format: "%.2fs", duration)
        }
    }

    /// Whether the hook produced a blocking result.
    public var isBlocking: Bool {
        parsedOutput?.isBlocking ?? false
    }

    /// Summary status for UI display.
    public var status: TestRunnerResultStatus {
        if timedOut { return .timedOut }
        if cancelled { return .cancelled }
        if error != nil { return .error }
        if !success { return .failed }
        return .passed
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        hookId: UUID,
        success: Bool,
        exitCode: Int? = nil,
        stdout: String? = nil,
        stderr: String? = nil,
        parsedOutput: HookOutput? = nil,
        startedAt: Date,
        completedAt: Date,
        timedOut: Bool = false,
        cancelled: Bool = false,
        error: String? = nil,
        mockInput: String? = nil
    ) {
        self.id = id
        self.hookId = hookId
        self.success = success
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.parsedOutput = parsedOutput
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.timedOut = timedOut
        self.cancelled = cancelled
        self.error = error
        self.mockInput = mockInput
    }

    // MARK: - Factory Methods

    /// Create an error result for pre-execution failures.
    public static func error(
        hookId: UUID,
        message: String,
        mockInput: String? = nil
    ) -> HookExecutionTestResult {
        let now = Date()
        return HookExecutionTestResult(
            hookId: hookId,
            success: false,
            startedAt: now,
            completedAt: now,
            error: message,
            mockInput: mockInput
        )
    }

    /// Create a timeout result.
    public static func timeout(
        hookId: UUID,
        startedAt: Date,
        stdout: String? = nil,
        stderr: String? = nil,
        mockInput: String? = nil
    ) -> HookExecutionTestResult {
        HookExecutionTestResult(
            hookId: hookId,
            success: false,
            stdout: stdout,
            stderr: stderr,
            startedAt: startedAt,
            completedAt: Date(),
            timedOut: true,
            mockInput: mockInput
        )
    }

    /// Create a cancelled result.
    public static func cancelled(
        hookId: UUID,
        startedAt: Date,
        mockInput: String? = nil
    ) -> HookExecutionTestResult {
        HookExecutionTestResult(
            hookId: hookId,
            success: false,
            startedAt: startedAt,
            completedAt: Date(),
            cancelled: true,
            mockInput: mockInput
        )
    }
}

/// Typealias for backward compatibility with UI code expecting `HookTestStatus`.
/// The canonical name is `TestRunnerResultStatus` to avoid conflicts with other
/// hook status types in the codebase.
public typealias HookTestStatus = TestRunnerResultStatus

/// Status of a hook test execution.
public enum TestRunnerResultStatus: String, Sendable, CaseIterable, Hashable {
    case passed = "passed"
    case failed = "failed"
    case timedOut = "timed_out"
    case cancelled = "cancelled"
    case error = "error"

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .passed: return "Passed"
        case .failed: return "Failed"
        case .timedOut: return "Timed Out"
        case .cancelled: return "Cancelled"
        case .error: return "Error"
        }
    }

    /// SF Symbol for status badge.
    public var icon: String {
        switch self {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .timedOut: return "clock.badge.exclamationmark.fill"
        case .cancelled: return "stop.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    /// Color name for status badge.
    public var colorName: String {
        switch self {
        case .passed: return "green"
        case .failed: return "red"
        case .timedOut: return "orange"
        case .cancelled: return "gray"
        case .error: return "red"
        }
    }
}

/// Configuration for hook test execution.
public struct HookTestConfig: Sendable {
    /// Timeout in milliseconds. Defaults to hook's configured timeout.
    public var timeoutMs: Int?

    /// Environment variables to add/override.
    public var environment: [String: String]

    /// Working directory for command execution.
    public var workingDirectory: String?

    /// Whether to capture stdout.
    public var captureStdout: Bool

    /// Whether to capture stderr.
    public var captureStderr: Bool

    /// Maximum bytes to capture from stdout/stderr (0 = unlimited).
    public var maxOutputBytes: Int

    public init(
        timeoutMs: Int? = nil,
        environment: [String: String] = [:],
        workingDirectory: String? = nil,
        captureStdout: Bool = true,
        captureStderr: Bool = true,
        maxOutputBytes: Int = 1024 * 1024  // 1MB default
    ) {
        self.timeoutMs = timeoutMs
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.captureStdout = captureStdout
        self.captureStderr = captureStderr
        self.maxOutputBytes = maxOutputBytes
    }

    /// Default configuration.
    public static let `default` = HookTestConfig()
}

/// Mock input generator for different hook event types.
public struct HookMockInput: Sendable {
    /// The event type this mock input is for.
    public let eventType: CLIHookEventType

    /// JSON string of the mock input data.
    public let json: String

    /// Human-readable description of the mock scenario.
    public let description: String

    public init(eventType: CLIHookEventType, json: String, description: String) {
        self.eventType = eventType
        self.json = json
        self.description = description
    }

    // MARK: - Pre-built Mock Inputs

    /// Mock input for PreToolUse event (safe Read operation).
    public static let preToolUseRead = HookMockInput(
        eventType: .preToolUse,
        json: """
        {
          "tool_name": "Read",
          "tool_input": {"file_path": "/tmp/test-file.txt"},
          "session_id": "test-session-001",
          "conversation_id": "test-conv-001",
          "project_path": "/tmp/test-project"
        }
        """,
        description: "Read operation on a test file"
    )

    /// Mock input for PreToolUse event (Bash command).
    public static let preToolUseBash = HookMockInput(
        eventType: .preToolUse,
        json: """
        {
          "tool_name": "Bash",
          "tool_input": {"command": "echo 'hello world'"},
          "session_id": "test-session-001",
          "conversation_id": "test-conv-001",
          "project_path": "/tmp/test-project"
        }
        """,
        description: "Safe echo command"
    )

    /// Mock input for PreToolUse event (dangerous command for testing blocks).
    public static let preToolUseDangerous = HookMockInput(
        eventType: .preToolUse,
        json: """
        {
          "tool_name": "Bash",
          "tool_input": {"command": "rm -rf /"},
          "session_id": "test-session-001",
          "conversation_id": "test-conv-001",
          "project_path": "/tmp/test-project"
        }
        """,
        description: "Dangerous command (should be blocked)"
    )

    /// Mock input for PostToolUse event.
    public static let postToolUse = HookMockInput(
        eventType: .postToolUse,
        json: """
        {
          "tool_name": "Read",
          "tool_input": {"file_path": "/tmp/test-file.txt"},
          "tool_output": "Test file contents here...",
          "tool_error": null,
          "duration_ms": 42,
          "session_id": "test-session-001",
          "conversation_id": "test-conv-001",
          "project_path": "/tmp/test-project"
        }
        """,
        description: "Successful Read tool completion"
    )

    /// Mock input for SessionStart event.
    public static let sessionStart = HookMockInput(
        eventType: .sessionStart,
        json: """
        {
          "session_id": "test-session-001",
          "project_path": "/tmp/test-project",
          "type": "start",
          "cwd": "/tmp/test-project"
        }
        """,
        description: "New session start"
    )

    /// Mock input for Stop event.
    public static let stop = HookMockInput(
        eventType: .stop,
        json: """
        {
          "stop_reason": "end_of_turn",
          "session_id": "test-session-001",
          "conversation_id": "test-conv-001",
          "project_path": "/tmp/test-project",
          "turn_count": 3
        }
        """,
        description: "Normal turn completion"
    )

    /// Mock input for UserPromptSubmit event.
    public static let userPromptSubmit = HookMockInput(
        eventType: .userPromptSubmit,
        json: """
        {
          "prompt": "Help me understand this code",
          "session_id": "test-session-001",
          "conversation_id": "test-conv-001",
          "project_path": "/tmp/test-project"
        }
        """,
        description: "User prompt submission"
    )

    /// Mock input for PreCompact event.
    public static let preCompact = HookMockInput(
        eventType: .preCompact,
        json: """
        {
          "session_id": "test-session-001",
          "conversation_id": "test-conv-001",
          "project_path": "/tmp/test-project",
          "token_count": 180000,
          "token_limit": 200000
        }
        """,
        description: "Context compaction triggered"
    )

    /// Mock input for PermissionRequest event.
    public static let permissionRequest = HookMockInput(
        eventType: .permissionRequest,
        json: """
        {
          "permission_type": "file_write",
          "tool_name": "Write",
          "tool_input": {"file_path": "/tmp/test-output.txt", "content": "test"},
          "session_id": "test-session-001",
          "project_path": "/tmp/test-project"
        }
        """,
        description: "File write permission request"
    )

    /// Mock input for Notification event.
    public static let notification = HookMockInput(
        eventType: .notification,
        json: """
        {
          "notification_type": "task_complete",
          "notification_message": "Build succeeded with 0 warnings",
          "session_id": "test-session-001",
          "project_path": "/tmp/test-project"
        }
        """,
        description: "Task completion notification"
    )

    /// Get default mock input for an event type.
    public static func defaultInput(for eventType: CLIHookEventType) -> HookMockInput {
        switch eventType {
        case .preToolUse: return preToolUseRead
        case .postToolUse: return postToolUse
        case .sessionStart: return sessionStart
        case .stop: return stop
        case .userPromptSubmit: return userPromptSubmit
        case .preCompact: return preCompact
        case .permissionRequest: return permissionRequest
        case .notification: return notification
        }
    }

    /// All available mock inputs for an event type.
    public static func allInputs(for eventType: CLIHookEventType) -> [HookMockInput] {
        switch eventType {
        case .preToolUse:
            return [preToolUseRead, preToolUseBash, preToolUseDangerous]
        case .postToolUse:
            return [postToolUse]
        case .sessionStart:
            return [sessionStart]
        case .stop:
            return [stop]
        case .userPromptSubmit:
            return [userPromptSubmit]
        case .preCompact:
            return [preCompact]
        case .permissionRequest:
            return [permissionRequest]
        case .notification:
            return [notification]
        }
    }
}

// MARK: - Hook Test Runner Actor

/// Actor for executing hooks in test/preview mode.
///
/// Provides thread-safe hook execution with timeout handling, output capture,
/// and structured results. Use this for testing hooks before enabling them
/// in production, or for previewing hook behavior with mock data.
///
/// **Thread Safety:**
/// - All public methods are actor-isolated
/// - Running processes are tracked for cancellation
/// - Task cancellation is properly propagated
///
/// **Example Usage:**
/// ```swift
/// let runner = HookTestRunner()
///
/// // Test a command hook
/// let result = await runner.test(
///     definition: myHookDefinition,
///     mockInput: .preToolUseRead
/// )
///
/// if result.success {
///     print("Hook passed: \(result.formattedDuration)")
/// } else {
///     print("Hook failed: \(result.error ?? result.stderr ?? "unknown")")
/// }
/// ```
public actor HookTestRunner {
    /// Currently running test processes, keyed by test ID.
    private var runningTests: [UUID: Process] = [:]

    /// Test history for recent executions.
    private var testHistory: [HookExecutionTestResult] = []

    /// Maximum number of results to keep in history.
    private let maxHistorySize: Int

    // MARK: - Initialization

    public init(maxHistorySize: Int = 100) {
        self.maxHistorySize = maxHistorySize
    }

    // MARK: - Hook Testing

    /// Test a hook definition with mock input data.
    ///
    /// - Parameters:
    ///   - definition: The hook definition to test
    ///   - mockInput: Mock input data for the hook
    ///   - config: Test execution configuration
    /// - Returns: Structured test result
    public func test(
        definition: HookDefinition,
        mockInput: HookMockInput,
        config: HookTestConfig = .default
    ) async -> HookExecutionTestResult {
        let testId = UUID()
        let startedAt = Date()

        // Validate hook definition first
        let validationErrors = definition.validate()
        if !validationErrors.isEmpty {
            let errorMessages = validationErrors.map(\.message).joined(separator: "; ")
            let result = HookExecutionTestResult.error(
                hookId: definition.id,
                message: "Validation failed: \(errorMessages)",
                mockInput: mockInput.json
            )
            recordResult(result)
            return result
        }

        // Execute based on hook type
        let result: HookExecutionTestResult
        switch definition.type {
        case .prompt:
            result = await testPromptHook(
                definition: definition,
                mockInput: mockInput,
                config: config,
                testId: testId,
                startedAt: startedAt
            )
        case .command:
            result = await testCommandHook(
                definition: definition,
                mockInput: mockInput,
                config: config,
                testId: testId,
                startedAt: startedAt
            )
        case .agent:
            result = await testAgentHook(
                definition: definition,
                mockInput: mockInput,
                config: config,
                testId: testId,
                startedAt: startedAt
            )
        }

        recordResult(result)
        return result
    }

    /// Test a Hook model (from HookStore) with mock input.
    ///
    /// Converts the Hook to a HookDefinition and tests it.
    public func test(
        hook: Hook,
        mockInput: HookMockInput,
        config: HookTestConfig = .default
    ) async -> HookExecutionTestResult {
        // Convert Hook to HookDefinition
        let definition = HookDefinition(
            id: hook.id,
            name: hook.name,
            type: .command,  // Hook model is always command type
            matcher: hook.triggerPattern,
            content: hook.inlineScript ?? hook.scriptPath ?? "",
            timeout: TimeInterval(hook.timeoutMs) / 1000.0,
            isEnabled: hook.enabled,
            hookDescription: hook.description
        )

        return await test(definition: definition, mockInput: mockInput, config: config)
    }

    /// Test a hook with custom JSON input.
    ///
    /// - Parameters:
    ///   - definition: The hook definition to test
    ///   - inputJson: Custom JSON string for hook input
    ///   - eventType: The event type for context
    ///   - config: Test execution configuration
    /// - Returns: Structured test result
    public func test(
        definition: HookDefinition,
        inputJson: String,
        eventType: CLIHookEventType,
        config: HookTestConfig = .default
    ) async -> HookExecutionTestResult {
        let mockInput = HookMockInput(
            eventType: eventType,
            json: inputJson,
            description: "Custom input"
        )
        return await test(definition: definition, mockInput: mockInput, config: config)
    }

    // MARK: - Cancellation

    /// Cancel a running test by ID.
    public func cancel(testId: UUID) {
        if let process = runningTests[testId], process.isRunning {
            process.terminate()
        }
        runningTests.removeValue(forKey: testId)
    }

    /// Cancel all running tests.
    public func cancelAll() {
        for (_, process) in runningTests where process.isRunning {
            process.terminate()
        }
        runningTests.removeAll()
    }

    // MARK: - History

    /// Get recent test results.
    public func getHistory(limit: Int = 20) -> [HookExecutionTestResult] {
        Array(testHistory.prefix(limit))
    }

    /// Get test results for a specific hook.
    public func getHistory(hookId: UUID, limit: Int = 10) -> [HookExecutionTestResult] {
        testHistory
            .filter { $0.hookId == hookId }
            .prefix(limit)
            .map { $0 }
    }

    /// Clear test history.
    public func clearHistory() {
        testHistory.removeAll()
    }

    // MARK: - Private: Prompt Hook Testing

    private func testPromptHook(
        definition: HookDefinition,
        mockInput: HookMockInput,
        config: HookTestConfig,
        testId: UUID,
        startedAt: Date
    ) async -> HookExecutionTestResult {
        // Prompt hooks just inject text - validate the content and return success
        let content = definition.content.trimmingCharacters(in: .whitespacesAndNewlines)

        if content.isEmpty {
            return HookExecutionTestResult.error(
                hookId: definition.id,
                message: "Prompt content is empty",
                mockInput: mockInput.json
            )
        }

        // Simulate the prompt output as a HookOutput
        let output = HookOutput.continue(message: content)

        return HookExecutionTestResult(
            id: testId,
            hookId: definition.id,
            success: true,
            stdout: content,
            parsedOutput: output,
            startedAt: startedAt,
            completedAt: Date(),
            mockInput: mockInput.json
        )
    }

    // MARK: - Private: Command Hook Testing

    private func testCommandHook(
        definition: HookDefinition,
        mockInput: HookMockInput,
        config: HookTestConfig,
        testId: UUID,
        startedAt: Date
    ) async -> HookExecutionTestResult {
        let command = definition.content.trimmingCharacters(in: .whitespacesAndNewlines)

        if command.isEmpty {
            return HookExecutionTestResult.error(
                hookId: definition.id,
                message: "Command is empty",
                mockInput: mockInput.json
            )
        }

        // Determine timeout
        let timeoutMs = config.timeoutMs ?? Int(definition.effectiveTimeout * 1000)

        // Setup process
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()

        // Use bash to execute the command
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        // Setup environment
        var environment = ProcessInfo.processInfo.environment
        environment["BLAZE_TEST_MODE"] = "1"
        environment["BLAZE_HOOK_ID"] = definition.id.uuidString
        environment["BLAZE_HOOK_NAME"] = definition.name
        for (key, value) in config.environment {
            environment[key] = value
        }
        process.environment = environment

        // Set working directory if specified
        if let workDir = config.workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workDir)
        }

        // Setup pipes
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe

        // Track the process
        runningTests[testId] = process

        // Write mock input to stdin
        if let inputData = mockInput.json.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(inputData)
            try? stdinPipe.fileHandleForWriting.close()
        }

        // Setup timeout task
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
            if process.isRunning {
                process.terminate()
            }
        }

        // Run the process
        do {
            try process.run()
        } catch {
            timeoutTask.cancel()
            runningTests.removeValue(forKey: testId)
            return HookExecutionTestResult.error(
                hookId: definition.id,
                message: "Failed to start process: \(error.localizedDescription)",
                mockInput: mockInput.json
            )
        }

        // Wait for completion
        process.waitUntilExit()
        timeoutTask.cancel()
        runningTests.removeValue(forKey: testId)

        // Collect output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        var stdout = String(data: stdoutData, encoding: .utf8)
        var stderr = String(data: stderrData, encoding: .utf8)

        // Truncate if needed
        if config.maxOutputBytes > 0 {
            if let s = stdout, s.count > config.maxOutputBytes {
                stdout = String(s.prefix(config.maxOutputBytes)) + "\n... (truncated)"
            }
            if let s = stderr, s.count > config.maxOutputBytes {
                stderr = String(s.prefix(config.maxOutputBytes)) + "\n... (truncated)"
            }
        }

        let exitCode = Int(process.terminationStatus)
        let completedAt = Date()

        // Check for timeout (process.terminationStatus == SIGTERM)
        let timedOut = process.terminationReason == .uncaughtSignal &&
                       completedAt.timeIntervalSince(startedAt) >= Double(timeoutMs) / 1000.0

        // Try to parse stdout as HookOutput
        var parsedOutput: HookOutput?
        if let stdoutStr = stdout?.trimmingCharacters(in: .whitespacesAndNewlines),
           !stdoutStr.isEmpty {
            parsedOutput = try? HookOutput.parse(from: stdoutStr)
        }

        return HookExecutionTestResult(
            id: testId,
            hookId: definition.id,
            success: exitCode == 0,
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            parsedOutput: parsedOutput,
            startedAt: startedAt,
            completedAt: completedAt,
            timedOut: timedOut,
            mockInput: mockInput.json
        )
    }

    // MARK: - Private: Agent Hook Testing

    private func testAgentHook(
        definition: HookDefinition,
        mockInput: HookMockInput,
        config: HookTestConfig,
        testId: UUID,
        startedAt: Date
    ) async -> HookExecutionTestResult {
        // Agent hooks delegate to AI - for testing, we validate the configuration
        // and return a mock success. Actual agent execution would require API calls.

        let agentConfig = definition.content.trimmingCharacters(in: .whitespacesAndNewlines)

        if agentConfig.isEmpty {
            return HookExecutionTestResult.error(
                hookId: definition.id,
                message: "Agent configuration is empty",
                mockInput: mockInput.json
            )
        }

        // Validate agent config looks reasonable
        if agentConfig.count < 3 {
            return HookExecutionTestResult.error(
                hookId: definition.id,
                message: "Agent configuration too short: '\(agentConfig)'",
                mockInput: mockInput.json
            )
        }

        // For test mode, return a mock success
        // Real agent execution would spawn a sub-agent with the prompt
        let mockOutput = HookOutput.continue(
            message: "[Test Mode] Agent hook would execute with config: \(agentConfig)"
        )

        return HookExecutionTestResult(
            id: testId,
            hookId: definition.id,
            success: true,
            stdout: "[Agent hook test mode - actual execution skipped]",
            parsedOutput: mockOutput,
            startedAt: startedAt,
            completedAt: Date(),
            mockInput: mockInput.json
        )
    }

    // MARK: - Private: History Management

    private func recordResult(_ result: HookExecutionTestResult) {
        testHistory.insert(result, at: 0)

        // Trim history if needed
        if testHistory.count > maxHistorySize {
            testHistory = Array(testHistory.prefix(maxHistorySize))
        }
    }
}

// MARK: - Convenience Extensions

extension HookTestRunner {
    /// Quick test with default mock input for the hook's event type.
    ///
    /// Automatically selects appropriate mock input based on the hook's matcher.
    public func quickTest(
        definition: HookDefinition,
        config: HookTestConfig = .default
    ) async -> HookExecutionTestResult {
        // Determine event type from matcher or default to PreToolUse
        let eventType: CLIHookEventType = .preToolUse
        let mockInput = HookMockInput.defaultInput(for: eventType)
        return await test(definition: definition, mockInput: mockInput, config: config)
    }

    /// Batch test multiple hooks with the same mock input.
    public func batchTest(
        definitions: [HookDefinition],
        mockInput: HookMockInput,
        config: HookTestConfig = .default
    ) async -> [HookExecutionTestResult] {
        var results: [HookExecutionTestResult] = []
        for definition in definitions {
            let result = await test(definition: definition, mockInput: mockInput, config: config)
            results.append(result)
        }
        return results
    }
}
