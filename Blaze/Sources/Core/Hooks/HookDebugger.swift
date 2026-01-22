import Foundation

// MARK: - Hook Debugger
//
// E005-F009-S002-T006-A001: Debug Mode Integration for Hooks
//
// Provides debugging utilities for hook development and troubleshooting:
// - Debug session management with structured logging
// - Breakpoint simulation (pause before/after hook execution)
// - Hook execution traces with timeline visualization
// - Export capabilities for sharing debug logs

// MARK: - Debug Log Entry

/// A single log entry in a debug session.
///
/// Captures a timestamped event during hook execution with associated data.
/// Used to build a complete picture of what happened during debugging.
public struct HookDebugLogEntry: Identifiable, Codable, Sendable, Equatable {
    /// Unique identifier for this log entry.
    public let id: UUID

    /// When this event occurred.
    public let timestamp: Date

    /// The type of debug event.
    public let event: HookDebugEvent

    /// Associated data for the event (JSON-encodable).
    public let data: [String: String]

    /// The hook ID this entry relates to (if applicable).
    public let hookId: UUID?

    /// The hook name for display purposes.
    public let hookName: String?

    /// Severity level for filtering and display.
    public let level: HookDebugLevel

    /// Optional message providing additional context.
    public let message: String?

    // MARK: - Computed Properties

    /// Formatted timestamp for display (HH:mm:ss.SSS).
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    /// Relative timestamp from session start (for timeline display).
    public func relativeTimestamp(from sessionStart: Date) -> TimeInterval {
        timestamp.timeIntervalSince(sessionStart)
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        event: HookDebugEvent,
        data: [String: String] = [:],
        hookId: UUID? = nil,
        hookName: String? = nil,
        level: HookDebugLevel = .info,
        message: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.data = data
        self.hookId = hookId
        self.hookName = hookName
        self.level = level
        self.message = message
    }
}

// MARK: - Debug Event Types

/// Types of events that can be logged during hook debugging.
public enum HookDebugEvent: String, Codable, Sendable, CaseIterable {
    // Session lifecycle
    case sessionStarted = "session_started"
    case sessionStopped = "session_stopped"
    case sessionPaused = "session_paused"
    case sessionResumed = "session_resumed"

    // Hook execution lifecycle
    case hookQueued = "hook_queued"
    case hookStarting = "hook_starting"
    case hookInputReceived = "hook_input_received"
    case hookOutputProduced = "hook_output_produced"
    case hookCompleted = "hook_completed"
    case hookFailed = "hook_failed"
    case hookTimeout = "hook_timeout"
    case hookCancelled = "hook_cancelled"

    // Breakpoint events
    case breakpointHit = "breakpoint_hit"
    case breakpointSkipped = "breakpoint_skipped"
    case breakpointContinue = "breakpoint_continue"

    // Data flow events
    case inputTransformed = "input_transformed"
    case outputTransformed = "output_transformed"
    case environmentSet = "environment_set"

    // Error events
    case validationError = "validation_error"
    case executionError = "execution_error"
    case parseError = "parse_error"

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .sessionStarted: return "Session Started"
        case .sessionStopped: return "Session Stopped"
        case .sessionPaused: return "Session Paused"
        case .sessionResumed: return "Session Resumed"
        case .hookQueued: return "Hook Queued"
        case .hookStarting: return "Hook Starting"
        case .hookInputReceived: return "Input Received"
        case .hookOutputProduced: return "Output Produced"
        case .hookCompleted: return "Hook Completed"
        case .hookFailed: return "Hook Failed"
        case .hookTimeout: return "Hook Timeout"
        case .hookCancelled: return "Hook Cancelled"
        case .breakpointHit: return "Breakpoint Hit"
        case .breakpointSkipped: return "Breakpoint Skipped"
        case .breakpointContinue: return "Breakpoint Continue"
        case .inputTransformed: return "Input Transformed"
        case .outputTransformed: return "Output Transformed"
        case .environmentSet: return "Environment Set"
        case .validationError: return "Validation Error"
        case .executionError: return "Execution Error"
        case .parseError: return "Parse Error"
        }
    }

    /// SF Symbol for the event type.
    public var icon: String {
        switch self {
        case .sessionStarted: return "play.circle.fill"
        case .sessionStopped: return "stop.circle.fill"
        case .sessionPaused: return "pause.circle.fill"
        case .sessionResumed: return "playpause.circle.fill"
        case .hookQueued: return "list.bullet.clipboard"
        case .hookStarting: return "arrow.right.circle"
        case .hookInputReceived: return "arrow.down.doc"
        case .hookOutputProduced: return "arrow.up.doc"
        case .hookCompleted: return "checkmark.circle.fill"
        case .hookFailed: return "xmark.circle.fill"
        case .hookTimeout: return "clock.badge.exclamationmark"
        case .hookCancelled: return "nosign"
        case .breakpointHit: return "pause.fill"
        case .breakpointSkipped: return "forward.fill"
        case .breakpointContinue: return "play.fill"
        case .inputTransformed: return "arrow.left.arrow.right"
        case .outputTransformed: return "arrow.left.arrow.right"
        case .environmentSet: return "gearshape"
        case .validationError: return "exclamationmark.triangle"
        case .executionError: return "exclamationmark.octagon"
        case .parseError: return "questionmark.diamond"
        }
    }
}

// MARK: - Debug Level

/// Severity level for debug log entries.
public enum HookDebugLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case trace = "trace"
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"

    /// Numeric value for comparison.
    private var order: Int {
        switch self {
        case .trace: return 0
        case .debug: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        }
    }

    public static func < (lhs: HookDebugLevel, rhs: HookDebugLevel) -> Bool {
        lhs.order < rhs.order
    }

    /// Human-readable display name.
    public var displayName: String {
        rawValue.uppercased()
    }

    /// Color name for UI display.
    public var colorName: String {
        switch self {
        case .trace: return "gray"
        case .debug: return "secondary"
        case .info: return "blue"
        case .warning: return "orange"
        case .error: return "red"
        }
    }
}

// MARK: - Debug Session

/// Represents an active or completed debug session.
public struct HookDebugSession: Identifiable, Codable, Sendable {
    /// Unique identifier for this debug session.
    public let id: UUID

    /// When the session started.
    public let startedAt: Date

    /// When the session ended (nil if still active).
    public var endedAt: Date?

    /// User-provided name for the session.
    public var name: String

    /// All log entries in chronological order.
    public var entries: [HookDebugLogEntry]

    /// Hooks that have breakpoints set.
    public var breakpointHookIds: Set<UUID>

    /// Whether breakpoints are enabled globally.
    public var breakpointsEnabled: Bool

    /// Minimum log level to capture.
    public var minimumLevel: HookDebugLevel

    // MARK: - Computed Properties

    /// Whether the session is currently active.
    public var isActive: Bool {
        endedAt == nil
    }

    /// Duration of the session.
    public var duration: TimeInterval {
        let end = endedAt ?? Date()
        return end.timeIntervalSince(startedAt)
    }

    /// Formatted duration for display.
    public var formattedDuration: String {
        let duration = self.duration
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else if duration < 3600 {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    /// Number of entries by level.
    public var entriesByLevel: [HookDebugLevel: Int] {
        Dictionary(grouping: entries, by: \.level)
            .mapValues { $0.count }
    }

    /// Number of error entries.
    public var errorCount: Int {
        entriesByLevel[.error] ?? 0
    }

    /// Number of warning entries.
    public var warningCount: Int {
        entriesByLevel[.warning] ?? 0
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        name: String = "Debug Session",
        minimumLevel: HookDebugLevel = .debug
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = nil
        self.name = name
        self.entries = []
        self.breakpointHookIds = []
        self.breakpointsEnabled = true
        self.minimumLevel = minimumLevel
    }

    // MARK: - Filtering

    /// Get entries filtered by level.
    public func entries(minimumLevel: HookDebugLevel) -> [HookDebugLogEntry] {
        entries.filter { $0.level >= minimumLevel }
    }

    /// Get entries for a specific hook.
    public func entries(forHookId hookId: UUID) -> [HookDebugLogEntry] {
        entries.filter { $0.hookId == hookId }
    }

    /// Get entries matching a search query.
    public func entries(matching query: String) -> [HookDebugLogEntry] {
        let lowercased = query.lowercased()
        return entries.filter { entry in
            entry.event.displayName.lowercased().contains(lowercased) ||
            entry.message?.lowercased().contains(lowercased) == true ||
            entry.hookName?.lowercased().contains(lowercased) == true ||
            entry.data.values.contains { $0.lowercased().contains(lowercased) }
        }
    }
}

// MARK: - Breakpoint Configuration

/// Configuration for a hook breakpoint.
public struct HookBreakpoint: Identifiable, Codable, Sendable, Equatable {
    /// The hook this breakpoint is set on.
    public let hookId: UUID

    /// Whether to pause before hook execution.
    public var pauseBefore: Bool

    /// Whether to pause after hook execution.
    public var pauseAfter: Bool

    /// Whether the breakpoint is currently enabled.
    public var isEnabled: Bool

    /// Optional condition (e.g., only break on certain input patterns).
    public var condition: String?

    // MARK: - Identifiable

    public var id: UUID { hookId }

    // MARK: - Initialization

    public init(
        hookId: UUID,
        pauseBefore: Bool = true,
        pauseAfter: Bool = false,
        isEnabled: Bool = true,
        condition: String? = nil
    ) {
        self.hookId = hookId
        self.pauseBefore = pauseBefore
        self.pauseAfter = pauseAfter
        self.isEnabled = isEnabled
        self.condition = condition
    }
}

// MARK: - Hook Debugger

/// Main debugger class for hook development and troubleshooting.
///
/// Provides:
/// - Debug session management with structured logging
/// - Breakpoint simulation for step-through debugging
/// - Execution trace timeline
/// - Log export capabilities
///
/// **Usage:**
/// ```swift
/// let debugger = HookDebugger()
///
/// // Start a debug session
/// debugger.startDebugSession(name: "Testing PreToolUse")
///
/// // Add breakpoint on a hook
/// debugger.setBreakpoint(hookId: myHook.id, before: true, after: true)
///
/// // Logs are added automatically during execution
/// debugger.addLogEntry(event: .hookStarting, hookId: myHook.id, hookName: myHook.name)
///
/// // Export when done
/// let json = try debugger.exportLogs(format: .json)
/// ```
@MainActor
public final class HookDebugger: ObservableObject {
    // MARK: - Published Properties

    /// Whether debug mode is currently enabled.
    @Published public var isDebugModeEnabled: Bool = false

    /// The currently active debug session (if any).
    @Published public private(set) var activeSession: HookDebugSession?

    /// History of completed debug sessions.
    @Published public private(set) var sessionHistory: [HookDebugSession] = []

    /// Configured breakpoints by hook ID.
    @Published public private(set) var breakpoints: [UUID: HookBreakpoint] = [:]

    /// Whether the debugger is currently paused at a breakpoint.
    @Published public private(set) var isPaused: Bool = false

    /// The hook ID we're currently paused on (if any).
    @Published public private(set) var pausedOnHookId: UUID?

    /// The pause reason (before/after).
    @Published public private(set) var pauseReason: PauseReason?

    // MARK: - Private Properties

    /// Continuation for breakpoint pause/resume.
    private var pauseContinuation: CheckedContinuation<Void, Never>?

    /// Maximum number of sessions to keep in history.
    private let maxHistorySize: Int

    /// Maximum number of entries per session.
    private let maxEntriesPerSession: Int

    // MARK: - Initialization

    public init(maxHistorySize: Int = 10, maxEntriesPerSession: Int = 10_000) {
        self.maxHistorySize = maxHistorySize
        self.maxEntriesPerSession = maxEntriesPerSession
    }

    // MARK: - Debug Mode Toggle

    /// Enable or disable debug mode.
    /// When disabled, no logs are captured and breakpoints are ignored.
    public func setDebugMode(enabled: Bool) {
        isDebugModeEnabled = enabled

        if !enabled && activeSession != nil {
            // Stop any active session when debug mode is disabled
            stopDebugSession()
        }
    }

    // MARK: - Session Management

    /// Start a new debug session.
    ///
    /// - Parameters:
    ///   - name: Human-readable name for the session
    ///   - minimumLevel: Minimum log level to capture
    /// - Returns: The new session ID
    @discardableResult
    public func startDebugSession(
        name: String = "Debug Session",
        minimumLevel: HookDebugLevel = .debug
    ) -> UUID {
        // Stop any existing session
        if activeSession != nil {
            stopDebugSession()
        }

        let session = HookDebugSession(
            name: name,
            minimumLevel: minimumLevel
        )
        activeSession = session
        isDebugModeEnabled = true

        addLogEntry(
            event: .sessionStarted,
            level: .info,
            message: "Debug session '\(name)' started"
        )

        return session.id
    }

    /// Stop the current debug session.
    public func stopDebugSession() {
        guard var session = activeSession else { return }

        addLogEntry(
            event: .sessionStopped,
            level: .info,
            message: "Debug session stopped"
        )

        session.endedAt = Date()

        // Move to history
        sessionHistory.insert(session, at: 0)

        // Trim history
        if sessionHistory.count > maxHistorySize {
            sessionHistory = Array(sessionHistory.prefix(maxHistorySize))
        }

        activeSession = nil

        // Resume if paused
        resumeFromBreakpoint()
    }

    /// Pause the current session (without stopping it).
    public func pauseSession() {
        guard activeSession != nil else { return }

        addLogEntry(
            event: .sessionPaused,
            level: .info,
            message: "Debug session paused"
        )
    }

    /// Resume a paused session.
    public func resumeSession() {
        guard activeSession != nil else { return }

        addLogEntry(
            event: .sessionResumed,
            level: .info,
            message: "Debug session resumed"
        )
    }

    // MARK: - Log Entry Management

    /// Add a log entry to the active session.
    ///
    /// - Parameters:
    ///   - event: The type of debug event
    ///   - data: Associated key-value data
    ///   - hookId: The related hook ID (if applicable)
    ///   - hookName: The related hook name (if applicable)
    ///   - level: Severity level
    ///   - message: Optional message providing context
    public func addLogEntry(
        event: HookDebugEvent,
        data: [String: String] = [:],
        hookId: UUID? = nil,
        hookName: String? = nil,
        level: HookDebugLevel = .info,
        message: String? = nil
    ) {
        guard isDebugModeEnabled, var session = activeSession else { return }
        guard level >= session.minimumLevel else { return }

        let entry = HookDebugLogEntry(
            event: event,
            data: data,
            hookId: hookId,
            hookName: hookName,
            level: level,
            message: message
        )

        session.entries.append(entry)

        // Trim if needed
        if session.entries.count > maxEntriesPerSession {
            session.entries = Array(session.entries.suffix(maxEntriesPerSession))
        }

        activeSession = session
    }

    /// Log hook input for debugging.
    public func logHookInput(
        hookId: UUID,
        hookName: String,
        input: String
    ) {
        addLogEntry(
            event: .hookInputReceived,
            data: ["input": input.prefix(4096).description],
            hookId: hookId,
            hookName: hookName,
            level: .debug,
            message: "Received input (\(input.count) chars)"
        )
    }

    /// Log hook output for debugging.
    public func logHookOutput(
        hookId: UUID,
        hookName: String,
        output: String,
        success: Bool
    ) {
        addLogEntry(
            event: .hookOutputProduced,
            data: [
                "output": output.prefix(4096).description,
                "success": success.description
            ],
            hookId: hookId,
            hookName: hookName,
            level: success ? .debug : .warning,
            message: "Produced output (\(output.count) chars)"
        )
    }

    /// Log hook completion.
    public func logHookCompletion(
        hookId: UUID,
        hookName: String,
        duration: TimeInterval,
        exitCode: Int?,
        success: Bool
    ) {
        var data: [String: String] = [
            "duration_ms": String(format: "%.0f", duration * 1000),
            "success": success.description
        ]
        if let exitCode = exitCode {
            data["exit_code"] = String(exitCode)
        }

        addLogEntry(
            event: success ? .hookCompleted : .hookFailed,
            data: data,
            hookId: hookId,
            hookName: hookName,
            level: success ? .info : .error,
            message: success ?
                "Completed in \(String(format: "%.1f", duration * 1000))ms" :
                "Failed with exit code \(exitCode ?? -1)"
        )
    }

    /// Log an error during hook execution.
    public func logError(
        hookId: UUID? = nil,
        hookName: String? = nil,
        error: Error,
        context: String? = nil
    ) {
        addLogEntry(
            event: .executionError,
            data: [
                "error": error.localizedDescription,
                "context": context ?? ""
            ],
            hookId: hookId,
            hookName: hookName,
            level: .error,
            message: "Error: \(error.localizedDescription)"
        )
    }

    // MARK: - Breakpoint Management

    /// Pause reason when stopped at a breakpoint.
    public enum PauseReason: String, Sendable {
        case beforeExecution = "before"
        case afterExecution = "after"

        public var displayName: String {
            switch self {
            case .beforeExecution: return "Before Execution"
            case .afterExecution: return "After Execution"
            }
        }
    }

    /// Set a breakpoint on a hook.
    public func setBreakpoint(
        hookId: UUID,
        before: Bool = true,
        after: Bool = false,
        condition: String? = nil
    ) {
        let breakpoint = HookBreakpoint(
            hookId: hookId,
            pauseBefore: before,
            pauseAfter: after,
            isEnabled: true,
            condition: condition
        )
        breakpoints[hookId] = breakpoint

        if var session = activeSession {
            session.breakpointHookIds.insert(hookId)
            activeSession = session
        }

        addLogEntry(
            event: .breakpointHit,
            data: [
                "pause_before": before.description,
                "pause_after": after.description
            ],
            hookId: hookId,
            level: .debug,
            message: "Breakpoint set"
        )
    }

    /// Remove a breakpoint from a hook.
    public func removeBreakpoint(hookId: UUID) {
        breakpoints.removeValue(forKey: hookId)

        if var session = activeSession {
            session.breakpointHookIds.remove(hookId)
            activeSession = session
        }
    }

    /// Toggle a breakpoint's enabled state.
    public func toggleBreakpoint(hookId: UUID) {
        guard var breakpoint = breakpoints[hookId] else { return }
        breakpoint.isEnabled.toggle()
        breakpoints[hookId] = breakpoint
    }

    /// Clear all breakpoints.
    public func clearAllBreakpoints() {
        breakpoints.removeAll()

        if var session = activeSession {
            session.breakpointHookIds.removeAll()
            activeSession = session
        }
    }

    /// Check if we should pause before executing a hook.
    ///
    /// Call this before executing a hook. If it returns true and `shouldPause` is set,
    /// await `waitForResume()` to pause execution.
    public func shouldPauseBeforeExecution(hookId: UUID) -> Bool {
        guard isDebugModeEnabled,
              let breakpoint = breakpoints[hookId],
              breakpoint.isEnabled,
              breakpoint.pauseBefore,
              activeSession?.breakpointsEnabled == true else {
            return false
        }
        return true
    }

    /// Check if we should pause after executing a hook.
    public func shouldPauseAfterExecution(hookId: UUID) -> Bool {
        guard isDebugModeEnabled,
              let breakpoint = breakpoints[hookId],
              breakpoint.isEnabled,
              breakpoint.pauseAfter,
              activeSession?.breakpointsEnabled == true else {
            return false
        }
        return true
    }

    /// Pause execution at a breakpoint.
    ///
    /// Call this from hook execution code when `shouldPauseBeforeExecution` or
    /// `shouldPauseAfterExecution` returns true.
    public func pauseAtBreakpoint(hookId: UUID, reason: PauseReason) async {
        isPaused = true
        pausedOnHookId = hookId
        pauseReason = reason

        addLogEntry(
            event: .breakpointHit,
            data: ["reason": reason.rawValue],
            hookId: hookId,
            level: .info,
            message: "Paused at breakpoint (\(reason.displayName))"
        )

        // Wait for resume
        await withCheckedContinuation { continuation in
            self.pauseContinuation = continuation
        }
    }

    /// Resume execution from a breakpoint.
    public func resumeFromBreakpoint() {
        guard isPaused else { return }

        if let hookId = pausedOnHookId {
            addLogEntry(
                event: .breakpointContinue,
                hookId: hookId,
                level: .info,
                message: "Resumed from breakpoint"
            )
        }

        isPaused = false
        pausedOnHookId = nil
        pauseReason = nil

        pauseContinuation?.resume()
        pauseContinuation = nil
    }

    /// Skip the current breakpoint without disabling it.
    public func skipBreakpoint() {
        resumeFromBreakpoint()

        if let hookId = pausedOnHookId {
            addLogEntry(
                event: .breakpointSkipped,
                hookId: hookId,
                level: .debug,
                message: "Breakpoint skipped"
            )
        }
    }

    // MARK: - Export

    /// Export format options.
    public enum ExportFormat: String, CaseIterable, Sendable {
        case json = "json"
        case csv = "csv"
        case markdown = "markdown"

        public var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            case .markdown: return "md"
            }
        }

        public var mimeType: String {
            switch self {
            case .json: return "application/json"
            case .csv: return "text/csv"
            case .markdown: return "text/markdown"
            }
        }
    }

    /// Export logs from the active or a historical session.
    ///
    /// - Parameters:
    ///   - sessionId: Session to export (nil for active session)
    ///   - format: Export format
    ///   - minimumLevel: Minimum level to include
    /// - Returns: Exported data as string
    /// - Throws: If session not found or export fails
    public func exportLogs(
        sessionId: UUID? = nil,
        format: ExportFormat = .json,
        minimumLevel: HookDebugLevel = .debug
    ) throws -> String {
        let session: HookDebugSession

        if let sessionId = sessionId {
            guard let found = sessionHistory.first(where: { $0.id == sessionId }) else {
                throw HookDebuggerError.sessionNotFound(sessionId)
            }
            session = found
        } else if let active = activeSession {
            session = active
        } else {
            throw HookDebuggerError.noActiveSession
        }

        let filteredEntries = session.entries(minimumLevel: minimumLevel)

        switch format {
        case .json:
            return try exportAsJSON(session: session, entries: filteredEntries)
        case .csv:
            return exportAsCSV(session: session, entries: filteredEntries)
        case .markdown:
            return exportAsMarkdown(session: session, entries: filteredEntries)
        }
    }

    /// Export all sessions as JSON.
    public func exportAllSessions() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        var allSessions = sessionHistory
        if let active = activeSession {
            allSessions.insert(active, at: 0)
        }

        let data = try encoder.encode(allSessions)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: - Private Export Methods

    private func exportAsJSON(session: HookDebugSession, entries: [HookDebugLogEntry]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let exportData = DebugExportData(session: session, entries: entries)
        let data = try encoder.encode(exportData)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func exportAsCSV(session: HookDebugSession, entries: [HookDebugLogEntry]) -> String {
        var lines: [String] = []

        // Header
        lines.append("timestamp,relative_ms,level,event,hook_name,message,data")

        // Entries
        let formatter = ISO8601DateFormatter()
        for entry in entries {
            let relativeMs = Int(entry.relativeTimestamp(from: session.startedAt) * 1000)
            let dataStr = entry.data.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            let escapedMessage = (entry.message ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let escapedData = dataStr.replacingOccurrences(of: "\"", with: "\"\"")

            lines.append([
                formatter.string(from: entry.timestamp),
                String(relativeMs),
                entry.level.rawValue,
                entry.event.rawValue,
                entry.hookName ?? "",
                "\"\(escapedMessage)\"",
                "\"\(escapedData)\""
            ].joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    private func exportAsMarkdown(session: HookDebugSession, entries: [HookDebugLogEntry]) -> String {
        var lines: [String] = []

        // Header
        lines.append("# Debug Session: \(session.name)")
        lines.append("")
        lines.append("- **ID:** `\(session.id.uuidString)`")
        lines.append("- **Started:** \(ISO8601DateFormatter().string(from: session.startedAt))")
        if let endedAt = session.endedAt {
            lines.append("- **Ended:** \(ISO8601DateFormatter().string(from: endedAt))")
        }
        lines.append("- **Duration:** \(session.formattedDuration)")
        lines.append("- **Entries:** \(entries.count)")
        lines.append("- **Errors:** \(session.errorCount)")
        lines.append("- **Warnings:** \(session.warningCount)")
        lines.append("")

        // Timeline
        lines.append("## Timeline")
        lines.append("")
        lines.append("| Time | Level | Event | Hook | Message |")
        lines.append("|------|-------|-------|------|---------|")

        for entry in entries {
            let relativeMs = Int(entry.relativeTimestamp(from: session.startedAt) * 1000)
            let timeStr = "+\(relativeMs)ms"
            let message = entry.message?.replacingOccurrences(of: "|", with: "\\|") ?? ""

            lines.append("| \(timeStr) | \(entry.level.displayName) | \(entry.event.displayName) | \(entry.hookName ?? "-") | \(message) |")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Utility

    /// Clear all debug history.
    public func clearHistory() {
        sessionHistory.removeAll()
    }

    /// Get the current session's timeline events for visualization.
    public func getTimelineEvents() -> [HookTimelineEvent] {
        guard let session = activeSession else { return [] }

        return session.entries.compactMap { entry -> HookTimelineEvent? in
            // Only include entries that have an associated hook
            guard entry.hookId != nil else { return nil }

            let status: HookTimelineStatus
            switch entry.event {
            case .hookCompleted:
                status = .completed
            case .hookFailed:
                status = .failed
            case .hookCancelled:
                status = .cancelled
            case .hookStarting:
                status = .running
            default:
                status = .pending
            }

            return HookTimelineEvent(
                id: entry.id,
                name: entry.hookName ?? "Unknown",
                category: .tool,
                startTime: entry.timestamp,
                endTime: nil,
                depth: 0,
                children: [],
                status: status
            )
        }
    }
}

// MARK: - Export Data Structure

/// Container for export data.
private struct DebugExportData: Codable {
    let sessionId: UUID
    let sessionName: String
    let startedAt: Date
    let endedAt: Date?
    let duration: TimeInterval
    let entryCount: Int
    let errorCount: Int
    let warningCount: Int
    let entries: [HookDebugLogEntry]

    init(session: HookDebugSession, entries: [HookDebugLogEntry]) {
        self.sessionId = session.id
        self.sessionName = session.name
        self.startedAt = session.startedAt
        self.endedAt = session.endedAt
        self.duration = session.duration
        self.entryCount = entries.count
        self.errorCount = entries.filter { $0.level == .error }.count
        self.warningCount = entries.filter { $0.level == .warning }.count
        self.entries = entries
    }
}

// MARK: - Errors

/// Errors that can occur during debugging operations.
public enum HookDebuggerError: Error, LocalizedError {
    case noActiveSession
    case sessionNotFound(UUID)
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active debug session"
        case .sessionNotFound(let id):
            return "Debug session not found: \(id)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}
