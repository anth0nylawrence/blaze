import Foundation
import os

// MARK: - TerminalManager (E001-F006-S001-T005-A001)

/// Central manager for terminal lifecycle, tab management, and Claude background detection.
///
/// **Phase 2 System Contract:**
/// - Owns PTY lifecycle and stream ingestion
/// - Tab list with scrollback buffers
/// - Auto-show panel when Claude runs foreground commands
/// - Persistence pointers for terminal output
public actor TerminalManager {
    // MARK: - Properties

    private var tabs: [UUID: TerminalTab] = [:]
    private var backends: [UUID: any TerminalBackend] = [:]
    private var scrollbackBuffers: [UUID: ScrollbackBuffer] = [:]
    private var processes: [UUID: TerminalProcess] = [:]

    private var preferences: TerminalPreferences = .default
    private let logger = Logger(subsystem: "com.blaze.terminal", category: "TerminalManager")

    // Event streams
    private var tabEventsContinuation: AsyncStream<TerminalTabEvent>.Continuation?
    private var _tabEventsStream: AsyncStream<TerminalTabEvent>?

    private var outputEventsContinuation: AsyncStream<TerminalOutputEvent>.Continuation?
    private var _outputEventsStream: AsyncStream<TerminalOutputEvent>?

    // Claude background detection
    private var autoShowHandler: ((UUID) -> Void)?

    // MARK: - Initialization

    public init() {
        // Create tab events stream
        var tabCont: AsyncStream<TerminalTabEvent>.Continuation?
        _tabEventsStream = AsyncStream { continuation in
            tabCont = continuation
        }
        tabEventsContinuation = tabCont

        // Create output events stream
        var outputCont: AsyncStream<TerminalOutputEvent>.Continuation?
        _outputEventsStream = AsyncStream { continuation in
            outputCont = continuation
        }
        outputEventsContinuation = outputCont
    }

    deinit {
        tabEventsContinuation?.finish()
        outputEventsContinuation?.finish()
    }

    // MARK: - Streams

    /// Stream of tab lifecycle events
    public var tabEvents: AsyncStream<TerminalTabEvent> {
        _tabEventsStream ?? AsyncStream { _ in }
    }

    /// Stream of terminal output events
    public var outputEvents: AsyncStream<TerminalOutputEvent> {
        _outputEventsStream ?? AsyncStream { _ in }
    }

    // MARK: - Tab Management

    /// Create a new user terminal tab
    /// - Parameters:
    ///   - sessionId: The session this terminal belongs to
    ///   - title: Optional title for the tab
    ///   - workingDirectory: Working directory for the shell
    /// - Returns: The created tab
    public func createUserTerminal(
        sessionId: UUID,
        title: String? = nil,
        workingDirectory: URL
    ) async throws -> TerminalTab {
        let tab = TerminalTab(
            sessionId: sessionId,
            kind: .user,
            title: title,
            configuration: TerminalTabConfiguration(
                shellConfiguration: ShellConfiguration(shellPath: preferences.defaultShell)
            )
        )

        tabs[tab.id] = tab
        scrollbackBuffers[tab.id] = ScrollbackBuffer(limit: preferences.scrollbackLimit)

        logger.info("Created user terminal tab: \(tab.id.uuidString)")

        // Create and spawn backend
        let backend = TerminalBackendFactory.create(type: preferences.backendType)
        backends[tab.id] = backend

        let shellConfig = tab.configuration.shellConfiguration ?? ShellConfiguration()
        try await backend.spawn(
            shell: shellConfig.shellPath,
            cwd: workingDirectory,
            env: shellConfig.buildEnvironment(),
            size: tab.configuration.initialSize
        )

        // Track process
        if case .running(let pid) = await backend.state {
            processes[tab.id] = TerminalProcess(
                tabId: tab.id,
                pid: pid,
                command: shellConfig.shellPath
            )
        }

        // Start output monitoring
        Task {
            await monitorOutput(tabId: tab.id, backend: backend)
        }

        emitTabEvent(.created(tab))
        return tab
    }

    /// Create a Claude output terminal tab
    /// - Parameter sessionId: The session this terminal belongs to
    /// - Returns: The created tab
    public func createClaudeTerminal(sessionId: UUID) async -> TerminalTab {
        // Check if one already exists for this session
        if let existing = tabs.values.first(where: { $0.sessionId == sessionId && $0.kind == .claude }) {
            return existing
        }

        let tab = TerminalTab(
            sessionId: sessionId,
            kind: .claude,
            configuration: .claudeTerminal
        )

        tabs[tab.id] = tab
        scrollbackBuffers[tab.id] = ScrollbackBuffer(limit: preferences.scrollbackLimit)

        logger.info("Created Claude terminal tab: \(tab.id.uuidString)")

        emitTabEvent(.created(tab))
        return tab
    }

    /// Get a terminal tab by ID
    public func getTab(_ id: UUID) -> TerminalTab? {
        tabs[id]
    }

    /// Get all tabs for a session
    public func getTabsForSession(_ sessionId: UUID) -> [TerminalTab] {
        tabs.values.filter { $0.sessionId == sessionId && !$0.isClosed }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Close a terminal tab
    /// - Parameters:
    ///   - id: Tab ID to close
    ///   - force: Force close even if process is running
    public func closeTab(_ id: UUID, force: Bool = false) async {
        guard var tab = tabs[id] else { return }

        // Terminate backend if running
        if let backend = backends[id] {
            if force {
                await backend.forceTerminate()
            } else {
                await backend.terminate()
            }
            backends[id] = nil
        }

        tab.isClosed = true
        tab.closedAt = Date()
        tabs[id] = tab

        logger.info("Closed terminal tab: \(id.uuidString)")
        emitTabEvent(.closed(tab))
    }

    /// Update tab title
    public func updateTabTitle(_ id: UUID, title: String) {
        guard var tab = tabs[id] else { return }
        tab.title = title
        tabs[id] = tab
        emitTabEvent(.updated(tab))
    }

    /// Set active tab
    public func setActiveTab(_ id: UUID) {
        for (tabId, var tab) in tabs {
            let wasActive = tab.isActive
            tab.isActive = (tabId == id)
            if wasActive != tab.isActive {
                tabs[tabId] = tab
                emitTabEvent(.updated(tab))
            }
        }
    }

    // MARK: - I/O Operations

    /// Write to a terminal
    public func write(_ id: UUID, data: Data) async {
        guard let backend = backends[id] else {
            logger.warning("No backend for terminal: \(id.uuidString)")
            return
        }
        await backend.write(data)
    }

    /// Write string to a terminal
    public func write(_ id: UUID, string: String) async {
        guard let data = string.data(using: .utf8) else { return }
        await write(id, data: data)
    }

    /// Resize a terminal
    public func resize(_ id: UUID, size: TerminalSize) async {
        guard let backend = backends[id] else { return }
        await backend.resize(size)
    }

    /// Get scrollback buffer for a terminal
    public func getScrollback(_ id: UUID) -> ScrollbackBuffer? {
        scrollbackBuffers[id]
    }

    /// Clear scrollback buffer
    public func clearScrollback(_ id: UUID) async {
        await scrollbackBuffers[id]?.clear()
    }

    /// Export terminal output
    public func exportOutput(_ id: UUID) async -> String? {
        await scrollbackBuffers[id]?.export()
    }

    // MARK: - Claude Output Handling

    /// Write Claude tool output to the Claude terminal
    /// - Parameters:
    ///   - sessionId: Session ID
    ///   - output: Output data
    ///   - isBackground: Whether this is a background command
    public func writeClaudeOutput(
        sessionId: UUID,
        output: Data,
        isBackground: Bool
    ) async {
        // Get or create Claude terminal for this session
        let tab: TerminalTab
        if let existing = tabs.values.first(where: { $0.sessionId == sessionId && $0.kind == .claude }) {
            tab = existing
        } else {
            tab = await createClaudeTerminal(sessionId: sessionId)
        }

        // Append to scrollback
        await scrollbackBuffers[tab.id]?.appendData(output)

        // Emit output event
        let event = TerminalOutputEvent(
            tabId: tab.id,
            sequence: await scrollbackBuffers[tab.id]?.totalLinesAdded ?? 0,
            stream: .stdout,
            content: .bytes(output)
        )
        outputEventsContinuation?.yield(event)

        // Auto-show if foreground command
        if !isBackground {
            autoShowHandler?(sessionId)
        }
    }

    /// Set handler for auto-show events
    public func setAutoShowHandler(_ handler: @escaping (UUID) -> Void) {
        autoShowHandler = handler
    }

    // MARK: - Background Detection (E001-F006-S001-T006-A001)

    /// Check if a tool call should trigger terminal auto-show
    /// - Parameter toolEvent: The tool event to check
    /// - Returns: Whether to auto-show the terminal
    public func shouldAutoShow(for toolEvent: ToolAutoShowEvent) -> Bool {
        guard preferences.autoShowOnForegroundCommand else { return false }

        // Check if this is a Bash tool running in foreground
        if toolEvent.toolName == "Bash" && !toolEvent.runInBackground {
            return true
        }

        return false
    }

    // MARK: - Preferences

    /// Update terminal preferences
    public func updatePreferences(_ newPreferences: TerminalPreferences) {
        preferences = newPreferences
        logger.info("Terminal preferences updated")
    }

    /// Get current preferences
    public func getPreferences() -> TerminalPreferences {
        preferences
    }

    // MARK: - Private Helpers

    private func monitorOutput(tabId: UUID, backend: any TerminalBackend) async {
        var sequence = 0

        for await data in await backend.output {
            // Append to scrollback
            await scrollbackBuffers[tabId]?.appendData(data)

            // Emit output event
            let event = TerminalOutputEvent(
                tabId: tabId,
                sequence: sequence,
                stream: .stdout,
                content: .bytes(data)
            )
            sequence += 1
            outputEventsContinuation?.yield(event)
        }

        // Backend output stream ended - check state
        if case .terminated(let exitCode) = await backend.state {
            if var process = processes[tabId] {
                process.exitCode = exitCode
                process.exitedAt = Date()
                processes[tabId] = process
            }

            if let tab = tabs[tabId] {
                emitTabEvent(.processTerminated(tab, exitCode: exitCode))
            }

            logger.info("Terminal \(tabId.uuidString) process terminated with code: \(exitCode)")
        }
    }

    private func emitTabEvent(_ event: TerminalTabEvent) {
        tabEventsContinuation?.yield(event)
    }
}

// MARK: - TerminalTabEvent

/// Events related to terminal tab lifecycle
public enum TerminalTabEvent: Sendable {
    case created(TerminalTab)
    case updated(TerminalTab)
    case closed(TerminalTab)
    case processTerminated(TerminalTab, exitCode: Int32)
}

// MARK: - ToolAutoShowEvent

/// Event for checking if terminal should auto-show
public struct ToolAutoShowEvent: Sendable {
    public let toolName: String
    public let runInBackground: Bool
    public let sessionId: UUID

    public init(toolName: String, runInBackground: Bool, sessionId: UUID) {
        self.toolName = toolName
        self.runInBackground = runInBackground
        self.sessionId = sessionId
    }
}

// MARK: - Claude Background Detector (E001-F006-S001-T006-A001)

/// Detects when Claude runs foreground commands for terminal auto-show.
///
/// **Phase 2 System Contract:**
/// - Parse NDJSON for `run_in_background` field
/// - Auto-show terminal panel when foreground command runs
/// - Only show for Bash tool calls
public struct ClaudeBackgroundDetector {
    /// Parse a tool request event and determine if it should trigger auto-show
    /// - Parameter event: The normalized event from NDJSON stream
    /// - Returns: ToolAutoShowEvent if this is a relevant tool call, nil otherwise
    public static func parseToolEvent(_ event: NormalizedEvent, sessionId: UUID) -> ToolAutoShowEvent? {
        switch event {
        case .toolCallStarted(let started):
            // Check if this is a Bash tool
            if started.toolName == "Bash" {
                // Parse input to check for run_in_background
                let runInBackground = parseRunInBackground(from: started.input)
                return ToolAutoShowEvent(
                    toolName: started.toolName,
                    runInBackground: runInBackground,
                    sessionId: sessionId
                )
            }
            return nil

        default:
            return nil
        }
    }

    /// Parse the run_in_background flag from tool input
    private static func parseRunInBackground(from input: String) -> Bool {
        // Try to parse as JSON
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        return json["run_in_background"] as? Bool ?? false
    }
}
