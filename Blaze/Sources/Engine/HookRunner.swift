import Foundation

// MARK: - Hook Runner

/// Executes automation hooks on normalized events.
///
/// **Phase 2 System Contract:**
/// - Matches events to registered hooks by event type and trigger pattern
/// - Executes hooks as child processes (shell, python, node, applescript)
/// - Enforces timeouts and captures output
/// - Records execution history for debugging
///
/// **Usage:**
/// ```swift
/// let runner = HookRunner(hookStore: store)
/// let results = await runner.executeHooks(for: event, sessionId: sessionId, repoId: repoId)
/// ```
public actor HookRunner {
    private let hookStore: HookStore
    private var runningProcesses: [UUID: Process] = [:]

    public init(hookStore: HookStore) {
        self.hookStore = hookStore
    }

    // MARK: - Hook Execution

    /// Execute all matching hooks for an event
    /// - Parameters:
    ///   - eventType: The hook event type that was triggered
    ///   - triggerContext: The context for pattern matching (file path, tool name, etc.)
    ///   - triggerData: Additional data to pass to the hook script
    ///   - sessionId: The current session ID
    ///   - repoId: The current repo ID (optional, for repo-scoped hooks)
    ///   - provider: The CLI provider context (for provider-specific filtering)
    ///   - worktreeId: The worktree ID (optional, for worktree-scoped hooks)
    /// - Returns: Array of hook execution results
    public func executeHooks(
        for eventType: HookEventType,
        triggerContext: String? = nil,
        triggerData: [String: String] = [:],
        sessionId: UUID?,
        repoId: UUID? = nil,
        provider: HookProvider? = nil,
        worktreeId: String? = nil
    ) async -> [HookExecutionResult] {
        // Check provider capability if specified
        if let provider = provider {
            let capability = HookCapability.forProvider(provider)
            // Map Blaze HookEventType to CLIHookEventType for capability check
            if let cliEvent = eventType.toCLIEventType, !capability.supports(event: cliEvent) {
                // Provider doesn't support this event type - skip execution
                return []
            }
        }

        do {
            // Get all enabled hooks for this event type
            let hooks = try await hookStore.getHooks(eventType: eventType, repoId: repoId)

            // Filter by trigger pattern if context provided
            let matchingHooks = hooks.filter { hook in
                matches(hook: hook, context: triggerContext)
            }

            // Execute hooks in order (by priority, then name)
            var results: [HookExecutionResult] = []

            // Separate sync and async hooks
            let syncHooks = matchingHooks.filter { !$0.runAsync }
            let asyncHooks = matchingHooks.filter { $0.runAsync }

            // Execute sync hooks sequentially
            for hook in syncHooks {
                let result = await executeHook(hook, triggerData: triggerData, sessionId: sessionId, provider: provider, worktreeId: worktreeId)
                results.append(result)

                // Record execution
                await recordExecution(result)

                // Stop if hook failed and it's a "pre" hook (blocking)
                if !result.success && eventType.isBlocking {
                    break
                }
            }

            // Execute async hooks concurrently (fire-and-forget style, but we still track them)
            await withTaskGroup(of: HookExecutionResult.self) { group in
                for hook in asyncHooks {
                    group.addTask {
                        let result = await self.executeHook(hook, triggerData: triggerData, sessionId: sessionId, provider: provider, worktreeId: worktreeId)
                        await self.recordExecution(result)
                        return result
                    }
                }

                for await result in group {
                    results.append(result)
                }
            }

            return results
        } catch {
            return [HookExecutionResult.error(message: "Failed to fetch hooks: \(error.localizedDescription)")]
        }
    }

    /// Execute a single hook
    private func executeHook(
        _ hook: Hook,
        triggerData: [String: String],
        sessionId: UUID?,
        provider: HookProvider? = nil,
        worktreeId: String? = nil
    ) async -> HookExecutionResult {
        guard hook.hasScript else {
            return HookExecutionResult(
                hookId: hook.id,
                hookName: hook.name,
                success: false,
                exitCode: nil,
                stdout: nil,
                stderr: "Hook has no script configured",
                startedAt: Date(),
                completedAt: Date(),
                cancelled: false
            )
        }

        let startedAt = Date()

        do {
            // Build the script to execute
            let (executable, scriptArgs) = try buildScript(hook)

            // Build environment with trigger data
            var environment = ProcessInfo.processInfo.environment
            environment["BLAZE_HOOK_ID"] = hook.id.uuidString
            environment["BLAZE_HOOK_NAME"] = hook.name
            environment["BLAZE_EVENT_TYPE"] = hook.eventType.rawValue
            if let sessionId = sessionId {
                environment["BLAZE_SESSION_ID"] = sessionId.uuidString
            }
            // Add provider context
            if let provider = provider {
                environment["BLAZE_PROVIDER"] = provider.rawValue
                environment["BLAZE_PROVIDER_NAME"] = provider.displayName
                environment["BLAZE_PROVIDER_CONFIG_DIR"] = provider.configDirectoryName
            }
            // Add worktree context
            if let worktreeId = worktreeId {
                environment["BLAZE_WORKTREE_ID"] = worktreeId
            }
            for (key, value) in triggerData {
                environment["BLAZE_TRIGGER_\(key.uppercased())"] = value
            }

            // Create process
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = scriptArgs
            process.environment = environment
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Track running process
            runningProcesses[hook.id] = process
            defer { runningProcesses.removeValue(forKey: hook.id) }

            // Setup timeout
            let timeoutMs = hook.timeoutMs
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
                process.terminate()
            }

            // Run process
            try process.run()
            process.waitUntilExit()

            // Cancel timeout if process completed
            timeoutTask.cancel()

            // Collect output
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            let stdout = String(data: stdoutData, encoding: .utf8)
            let stderr = String(data: stderrData, encoding: .utf8)
            let exitCode = process.terminationStatus
            let completedAt = Date()

            return HookExecutionResult(
                hookId: hook.id,
                hookName: hook.name,
                success: exitCode == 0,
                exitCode: Int(exitCode),
                stdout: stdout,
                stderr: stderr,
                startedAt: startedAt,
                completedAt: completedAt,
                cancelled: false
            )
        } catch {
            return HookExecutionResult(
                hookId: hook.id,
                hookName: hook.name,
                success: false,
                exitCode: nil,
                stdout: nil,
                stderr: error.localizedDescription,
                startedAt: startedAt,
                completedAt: Date(),
                cancelled: false
            )
        }
    }

    /// Build the executable and arguments for a hook
    private func buildScript(_ hook: Hook) throws -> (executable: String, arguments: [String]) {
        if let scriptPath = hook.scriptPath, !scriptPath.isEmpty {
            // External script file
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: scriptPath) else {
                throw HookError.scriptNotFound(path: scriptPath)
            }

            switch hook.scriptType {
            case .shell:
                return ("/bin/bash", [scriptPath])
            case .python:
                return ("/usr/bin/env", ["python3", scriptPath])
            case .node:
                return ("/usr/bin/env", ["node", scriptPath])
            case .applescript:
                return ("/usr/bin/osascript", [scriptPath])
            }
        } else if let inlineScript = hook.inlineScript, !inlineScript.isEmpty {
            // Inline script
            switch hook.scriptType {
            case .shell:
                return ("/bin/bash", ["-c", inlineScript])
            case .python:
                return ("/usr/bin/env", ["python3", "-c", inlineScript])
            case .node:
                return ("/usr/bin/env", ["node", "-e", inlineScript])
            case .applescript:
                return ("/usr/bin/osascript", ["-e", inlineScript])
            }
        } else {
            throw HookError.noScriptConfigured
        }
    }

    /// Check if a hook matches the trigger context
    private func matches(hook: Hook, context: String?) -> Bool {
        guard let pattern = hook.triggerPattern, !pattern.isEmpty else {
            // No pattern = matches everything
            return true
        }

        guard let context = context, !context.isEmpty else {
            // No context provided = no match if pattern exists
            return false
        }

        // Try glob matching first
        if pattern.contains("*") || pattern.contains("?") {
            return globMatch(pattern: pattern, string: context)
        }

        // Try regex matching
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(context.startIndex..<context.endIndex, in: context)
            return regex.firstMatch(in: context, range: range) != nil
        }

        // Fall back to simple substring match
        return context.contains(pattern)
    }

    /// Simple glob matching (supports * and ?)
    private func globMatch(pattern: String, string: String) -> Bool {
        // Convert glob to regex
        var regexPattern = "^"
        for char in pattern {
            switch char {
            case "*":
                regexPattern += ".*"
            case "?":
                regexPattern += "."
            case ".":
                regexPattern += "\\."
            default:
                regexPattern += String(char)
            }
        }
        regexPattern += "$"

        if let regex = try? NSRegularExpression(pattern: regexPattern) {
            let range = NSRange(string.startIndex..<string.endIndex, in: string)
            return regex.firstMatch(in: string, range: range) != nil
        }

        return false
    }

    /// Record a hook execution in the store
    private func recordExecution(_ result: HookExecutionResult) async {
        guard let hookId = result.hookId else { return }

        var execution = HookExecution(
            hookId: hookId,
            sessionId: nil,
            triggerData: nil
        )
        execution.completedAt = result.completedAt
        execution.exitCode = result.exitCode
        execution.stdout = result.stdout
        execution.stderr = result.stderr
        execution.success = result.success

        do {
            try await hookStore.recordExecution(execution)
        } catch {
            // Log error but don't fail
            print("Failed to record hook execution: \(error)")
        }
    }

    /// Cancel a running hook
    public func cancel(hookId: UUID) {
        if let process = runningProcesses[hookId], process.isRunning {
            process.terminate()
        }
    }

    /// Cancel all running hooks
    public func cancelAll() {
        for (_, process) in runningProcesses where process.isRunning {
            process.terminate()
        }
    }

    // MARK: - Script Validation

    /// Validate that a hook script can be executed
    public func validateScript(_ hook: Hook) async -> HookValidationResult {
        // Check script exists
        if let scriptPath = hook.scriptPath, !scriptPath.isEmpty {
            let fileManager = FileManager.default

            if !fileManager.fileExists(atPath: scriptPath) {
                return HookValidationResult(valid: false, message: "Script file not found: \(scriptPath)")
            }

            if !fileManager.isExecutableFile(atPath: scriptPath) && hook.scriptType == .shell {
                return HookValidationResult(valid: false, message: "Script file is not executable: \(scriptPath)")
            }
        } else if let inlineScript = hook.inlineScript, !inlineScript.isEmpty {
            // Inline scripts are always valid (will fail at runtime if syntax error)
        } else {
            return HookValidationResult(valid: false, message: "No script configured")
        }

        // Check interpreter exists
        let interpreter: String
        switch hook.scriptType {
        case .shell:
            interpreter = "/bin/bash"
        case .python:
            interpreter = "/usr/bin/env"
        case .node:
            interpreter = "/usr/bin/env"
        case .applescript:
            interpreter = "/usr/bin/osascript"
        }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: interpreter) {
            return HookValidationResult(valid: false, message: "Interpreter not found: \(interpreter)")
        }

        return HookValidationResult(valid: true, message: nil)
    }
}

// MARK: - Hook Event Type Extensions

extension HookEventType {
    /// Whether this event type blocks until hooks complete
    var isBlocking: Bool {
        switch self {
        case .preFileWrite, .preFileDelete, .preToolCall, .preCommit:
            return true
        default:
            return false
        }
    }

    /// Maps Blaze's internal HookEventType to the CLI provider's CLIHookEventType.
    /// Returns nil if there's no equivalent CLI event type.
    var toCLIEventType: CLIHookEventType? {
        switch self {
        case .preToolCall:
            return .preToolUse
        case .postToolCall:
            return .postToolUse
        case .sessionStart:
            return .sessionStart
        case .sessionEnd, .turnEnd:
            return .stop
        case .preFileWrite, .preFileDelete:
            // These map to PreToolUse for Write/Edit tools
            return .preToolUse
        case .postFileWrite, .postFileDelete:
            return .postToolUse
        case .turnStart:
            return nil  // No CLI equivalent
        case .toolApproved, .toolRejected:
            return .permissionRequest
        case .preCommit, .postCommit:
            return nil  // Git hooks are Blaze-internal only
        }
    }
}

// MARK: - Hook Execution Result

/// Result of executing a hook
public struct HookExecutionResult: Sendable {
    public let hookId: UUID?
    public let hookName: String?
    public let success: Bool
    public let exitCode: Int?
    public let stdout: String?
    public let stderr: String?
    public let startedAt: Date
    public let completedAt: Date
    public let cancelled: Bool

    public var duration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }

    /// Create an error result without a specific hook
    public static func error(message: String) -> HookExecutionResult {
        HookExecutionResult(
            hookId: nil,
            hookName: nil,
            success: false,
            exitCode: nil,
            stdout: nil,
            stderr: message,
            startedAt: Date(),
            completedAt: Date(),
            cancelled: false
        )
    }
}

// MARK: - Hook Validation Result

/// Result of validating a hook
public struct HookValidationResult: Sendable {
    public let valid: Bool
    public let message: String?
}

// MARK: - Hook Errors

/// Errors that can occur during hook execution
public enum HookError: Error, LocalizedError {
    case scriptNotFound(path: String)
    case noScriptConfigured
    case executionFailed(message: String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .scriptNotFound(let path):
            return "Script not found: \(path)"
        case .noScriptConfigured:
            return "No script configured for hook"
        case .executionFailed(let message):
            return "Hook execution failed: \(message)"
        case .timeout:
            return "Hook execution timed out"
        }
    }
}
