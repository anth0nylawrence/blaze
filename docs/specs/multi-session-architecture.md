# Multi-Session Architecture Specification

> Cogit0 Blaze - Concurrent Session Management for Multiple CLI Instances

**Version:** 1.0.0  
**Last Updated:** 2025-12-26  
**Status:** Draft  
**Parent Document:** [PRD Section 6.11](./prd.md#611-multi-session-architecture-p0)

---

## 1. Overview

### 1.1 Problem Statement

Power users routinely run multiple Claude Code CLI instances simultaneously:
- Frontend and backend in separate terminals
- Multiple git worktrees for parallel feature development
- Main branch for reference while working on a feature
- Different projects open at once

macOS applications are single-instance by default. When a user clicks the dock icon, macOS activates the existing window rather than launching a new instance. This creates a challenge: how do we support multiple concurrent AI coding sessions within a single application?

### 1.2 Solution

Blaze embraces the single-process model and implements **multi-session architecture**:
- One Blaze application process
- Multiple independent `SessionManager`-managed sessions
- Each session spawns and manages its own CLI process
- Four layout modes for organizing sessions: Tabs (default), Windows, Split View, Agent Lanes

### 1.3 Benefits Over Multiple App Instances

| Benefit | Description |
|---------|-------------|
| **Shared Resources** | Single memory footprint, shared caches, unified preferences |
| **Cross-Session Features** | Copy between sessions, compare outputs, unified search |
| **Unified UX** | One dock icon, one Cmd+Tab entry, consistent command palette |
| **Better OS Integration** | Proper window management, Mission Control support |
| **Policy Consistency** | Same policies apply across all sessions |

---

## 2. Architecture

### 2.1 High-Level Diagram

```
┌─────────────────────────────── Blaze.app (Single Process) ───────────────────────────────┐
│                                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              WindowManager                                           │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │ │
│  │  │   Window 1   │  │   Window 2   │  │   Window 3   │  │   Window 4   │             │ │
│  │  │  [Tab][Tab]  │  │   [Tab]      │  │  [Split]     │  │ [Agent Lanes]│             │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘             │ │
│  └─────────────────────────────────────────────────────────────────────────────────────┘ │
│                                          │                                               │
│                                          ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                            SessionManager (Singleton)                                │ │
│  │                                                                                      │ │
│  │  sessions: [Session]           Active Sessions Registry                             │ │
│  │  engineRunners: [ID: EngineRunner]   CLI Process Managers                           │ │
│  │  eventBus: EventBus            Cross-Session Event Distribution                     │ │
│  │                                                                                      │ │
│  └─────────────────────────────────────────────────────────────────────────────────────┘ │
│           │                    │                    │                    │               │
│           ▼                    ▼                    ▼                    ▼               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │  EngineRunner 1 │  │  EngineRunner 2 │  │  EngineRunner 3 │  │  EngineRunner 4 │     │
│  │  Session: abc   │  │  Session: def   │  │  Session: ghi   │  │  Session: jkl   │     │
│  │  Engine: Claude │  │  Engine: Claude │  │  Engine: Gemini │  │  Engine: Claude │     │
│  │  CWD: ~/proj-a  │  │  CWD: ~/proj-a  │  │  CWD: ~/proj-b  │  │  CWD: ~/proj-c  │     │
│  │  Worktree: main │  │  Worktree: feat │  │  Worktree: main │  │  Worktree: fix  │     │
│  │  PID: 1234      │  │  PID: 1235      │  │  PID: 1236      │  │  PID: 1237      │     │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘     │
│           │                    │                    │                    │               │
└───────────┼────────────────────┼────────────────────┼────────────────────┼───────────────┘
            │                    │                    │                    │
            ▼                    ▼                    ▼                    ▼
      claude -p ...        claude -p ...        gemini -p ...        claude -p ...
      (child process)      (child process)      (child process)      (child process)
```

### 2.2 Core Components

#### Session

```swift
/// Represents a single AI coding session with its own context and CLI process
struct Session: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    var name: String
    
    // Project context
    let projectId: Project.ID
    let workingDirectory: URL
    let worktreeBranch: String?
    
    // Engine configuration
    let engineType: EngineType
    var engineConfig: EngineConfig
    
    // State
    var state: SessionState
    var lastActivityAt: Date
    
    // Persistence
    var eventLogPath: URL
    var isRestored: Bool  // Was this session restored from disk?
}

enum SessionState: String, Codable {
    case idle           // No active CLI process
    case starting       // CLI process launching
    case active         // CLI running, ready for input
    case streaming      // CLI streaming response
    case waiting        // Waiting for user input (approval, etc.)
    case error          // CLI crashed or error state
    case closing        // Graceful shutdown in progress
}

enum EngineType: String, Codable, CaseIterable {
    case claudeCode = "claude"
    case geminiCli = "gemini"
    case codexCli = "codex"
    
    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .geminiCli: return "Gemini CLI"
        case .codexCli: return "OpenAI Codex"
        }
    }
    
    var iconName: String {
        switch self {
        case .claudeCode: return "brain.head.profile"
        case .geminiCli: return "sparkles"
        case .codexCli: return "chevron.left.forwardslash.chevron.right"
        }
    }
}
```

#### SessionManager

```swift
import SwiftUI
import Observation

/// Singleton that manages all active sessions across the application
@Observable
@MainActor
final class SessionManager {
    // MARK: - Singleton
    static let shared = SessionManager()
    
    // MARK: - State
    private(set) var sessions: [Session] = []
    private(set) var activeSessionId: Session.ID?
    
    private var engineRunners: [Session.ID: EngineRunner] = [:]
    private var eventSubscriptions: [Session.ID: AnyCancellable] = [:]
    
    // MARK: - Dependencies
    private let sessionStore: SessionStore
    private let policyEngine: PolicyEngine
    private let hookRunner: HookRunner
    private let eventBus: EventBus
    
    // MARK: - Computed Properties
    
    var activeSession: Session? {
        sessions.first { $0.id == activeSessionId }
    }
    
    var runningSessions: [Session] {
        sessions.filter { $0.state == .active || $0.state == .streaming }
    }
    
    var sessionsByProject: [Project.ID: [Session]] {
        Dictionary(grouping: sessions, by: \.projectId)
    }
    
    // MARK: - Session Lifecycle
    
    /// Create a new session with its own CLI process
    func createSession(
        project: Project,
        worktree: GitWorktree? = nil,
        engine: EngineType = .claudeCode,
        name: String? = nil,
        activate: Bool = true
    ) async throws -> Session {
        let workingDirectory = worktree?.path ?? project.rootURL
        
        let session = Session(
            id: UUID(),
            createdAt: Date(),
            name: name ?? generateSessionName(project: project, worktree: worktree),
            projectId: project.id,
            workingDirectory: workingDirectory,
            worktreeBranch: worktree?.branch,
            engineType: engine,
            engineConfig: EngineConfig.default(for: engine),
            state: .idle,
            lastActivityAt: Date(),
            eventLogPath: sessionStore.eventLogPath(for: UUID()),
            isRestored: false
        )
        
        // Create engine runner
        let runner = try await createEngineRunner(for: session)
        engineRunners[session.id] = runner
        
        // Subscribe to engine events
        subscribeToEngineEvents(session: session, runner: runner)
        
        // Add to sessions list
        sessions.append(session)
        
        // Persist session metadata
        try await sessionStore.save(session)
        
        // Activate if requested
        if activate {
            activeSessionId = session.id
        }
        
        // Notify
        eventBus.publish(.sessionCreated(session))
        
        return session
    }
    
    /// Resume a session from disk
    func restoreSession(_ sessionId: Session.ID) async throws -> Session {
        guard let storedSession = try await sessionStore.load(sessionId) else {
            throw SessionError.notFound(sessionId)
        }
        
        var session = storedSession
        session.isRestored = true
        session.state = .idle
        
        // Create engine runner (but don't start CLI yet)
        let runner = try await createEngineRunner(for: session)
        engineRunners[session.id] = runner
        
        subscribeToEngineEvents(session: session, runner: runner)
        
        sessions.append(session)
        
        return session
    }
    
    /// Close a session and cleanup its CLI process
    func closeSession(_ sessionId: Session.ID, force: Bool = false) async {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }
        
        var session = sessions[index]
        
        // If session is active, confirm with user unless forced
        if !force && (session.state == .active || session.state == .streaming) {
            // Show confirmation dialog
            let confirmed = await showCloseConfirmation(session: session)
            if !confirmed { return }
        }
        
        // Cancel CLI process
        if let runner = engineRunners[sessionId] {
            await runner.cancel()
        }
        
        // Cleanup
        engineRunners.removeValue(forKey: sessionId)
        eventSubscriptions.removeValue(forKey: sessionId)
        
        session.state = .closing
        sessions[index] = session
        
        // Update active session if needed
        if activeSessionId == sessionId {
            activeSessionId = sessions.first { $0.id != sessionId }?.id
        }
        
        // Remove from list
        sessions.remove(at: index)
        
        // Notify
        eventBus.publish(.sessionClosed(session))
    }
    
    // MARK: - Session Interaction
    
    /// Send a message to a session
    func send(message: String, to sessionId: Session.ID) async throws {
        guard let runner = engineRunners[sessionId] else {
            throw SessionError.notFound(sessionId)
        }
        
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else {
            throw SessionError.notFound(sessionId)
        }
        
        // Update state
        sessions[index].state = .streaming
        sessions[index].lastActivityAt = Date()
        
        // Run hooks
        await hookRunner.run(.onMessageSent, context: [
            "sessionId": sessionId.uuidString,
            "message": message
        ])
        
        // Send to engine
        do {
            for try await event in runner.send(message) {
                // Events are handled via subscription
                await processEvent(event, for: sessionId)
            }
            sessions[index].state = .idle
        } catch {
            sessions[index].state = .error
            throw error
        }
    }
    
    /// Cancel the current operation in a session
    func cancel(_ sessionId: Session.ID) async {
        guard let runner = engineRunners[sessionId] else { return }
        await runner.cancel()
        
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].state = .idle
        }
    }
    
    // MARK: - Session Navigation
    
    /// Activate a session (bring to focus)
    func activate(_ sessionId: Session.ID) {
        guard sessions.contains(where: { $0.id == sessionId }) else { return }
        activeSessionId = sessionId
        eventBus.publish(.sessionActivated(sessionId))
    }
    
    /// Get sessions for a specific project
    func sessions(for projectId: Project.ID) -> [Session] {
        sessions.filter { $0.projectId == projectId }
    }
    
    /// Get sessions for a specific worktree
    func sessions(for worktree: GitWorktree) -> [Session] {
        sessions.filter { $0.workingDirectory == worktree.path }
    }
    
    // MARK: - Private Helpers
    
    private func createEngineRunner(for session: Session) async throws -> EngineRunner {
        let adapter = try EngineAdapterFactory.create(for: session.engineType)
        
        return EngineRunner(
            adapter: adapter,
            workingDirectory: session.workingDirectory,
            config: session.engineConfig,
            policyEngine: policyEngine
        )
    }
    
    private func subscribeToEngineEvents(session: Session, runner: EngineRunner) {
        eventSubscriptions[session.id] = runner.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task {
                    await self?.processEvent(event, for: session.id)
                }
            }
    }
    
    private func processEvent(_ event: NormalizedEvent, for sessionId: Session.ID) async {
        // Store event
        try? await sessionStore.appendEvent(event, to: sessionId)
        
        // Run hooks
        await hookRunner.run(event.hookTrigger, context: event.hookContext)
        
        // Publish to event bus for UI updates
        eventBus.publish(.engineEvent(sessionId: sessionId, event: event))
    }
    
    private func generateSessionName(project: Project, worktree: GitWorktree?) -> String {
        if let worktree = worktree {
            return "\(project.name) (\(worktree.branch))"
        }
        return project.name
    }
}
```

#### EngineRunner

```swift
/// Manages a single CLI process for a session
actor EngineRunner {
    private let adapter: EngineAdapter
    private let workingDirectory: URL
    private let config: EngineConfig
    private let policyEngine: PolicyEngine
    
    private var process: Process?
    private var stdin: FileHandle?
    private var stdout: FileHandle?
    private var stderr: FileHandle?
    
    private let eventSubject = PassthroughSubject<NormalizedEvent, Never>()
    var eventPublisher: AnyPublisher<NormalizedEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    var isRunning: Bool {
        process?.isRunning ?? false
    }
    
    init(
        adapter: EngineAdapter,
        workingDirectory: URL,
        config: EngineConfig,
        policyEngine: PolicyEngine
    ) {
        self.adapter = adapter
        self.workingDirectory = workingDirectory
        self.config = config
        self.policyEngine = policyEngine
    }
    
    /// Send a message and stream responses
    func send(_ message: String) -> AsyncThrowingStream<NormalizedEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Start process if not running
                    if !isRunning {
                        try await startProcess()
                    }
                    
                    // Build command
                    let command = adapter.buildCommand(
                        message: message,
                        config: config
                    )
                    
                    // Write to stdin
                    try writeToStdin(command)
                    
                    // Stream responses
                    for try await line in readStdoutLines() {
                        if let event = try adapter.parseEvent(from: line) {
                            // Check policy before allowing certain events
                            if case .toolCallStarted(let payload) = event {
                                let decision = await policyEngine.evaluate(
                                    tool: payload.toolName,
                                    args: payload.input
                                )
                                if decision == .deny {
                                    continuation.yield(.policyViolation(PolicyViolationPayload(
                                        ruleId: decision.ruleId ?? "unknown",
                                        reason: decision.reason ?? "Policy denied",
                                        toolCallId: payload.toolCallId,
                                        overridable: decision.overridable
                                    )))
                                    continue
                                }
                            }
                            
                            continuation.yield(event)
                            eventSubject.send(event)
                            
                            // Check for completion
                            if case .sessionEnded = event {
                                continuation.finish()
                                return
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Cancel the current operation
    func cancel() async {
        guard let process = process, process.isRunning else { return }
        
        // Try graceful SIGINT first
        process.interrupt()
        
        // Wait up to 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Force kill if still running
        if process.isRunning {
            process.terminate()
        }
        
        cleanup()
    }
    
    // MARK: - Private
    
    private func startProcess() async throws {
        let process = Process()
        process.executableURL = adapter.executableURL
        process.currentDirectoryURL = workingDirectory
        process.environment = buildEnvironment()
        
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        self.stdin = stdinPipe.fileHandleForWriting
        self.stdout = stdoutPipe.fileHandleForReading
        self.stderr = stderrPipe.fileHandleForReading
        
        try process.run()
        self.process = process
    }
    
    private func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        
        // Add Blaze-specific vars
        env["BLAZE_SESSION"] = "true"
        env["TERM"] = "dumb"  // Disable ANSI colors
        
        // Remove sensitive vars
        env.removeValue(forKey: "ANTHROPIC_API_KEY")
        env.removeValue(forKey: "OPENAI_API_KEY")
        env.removeValue(forKey: "GOOGLE_API_KEY")
        
        return env
    }
    
    private func cleanup() {
        try? stdin?.close()
        try? stdout?.close()
        try? stderr?.close()
        process = nil
        stdin = nil
        stdout = nil
        stderr = nil
    }
}
```

---

## 3. Layout Modes

### 3.1 Tabs Mode (Default)

The primary layout mode. Sessions appear as tabs in a tab bar, similar to browser tabs or Terminal.app.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [✕ Frontend (main)] [✕ Backend (feat-auth)] [✕ Tests (main)] [+]             │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐                                                             │
│  │ Sessions    │         Active Session Content                              │
│  ├─────────────┤         (Chat timeline, tool cards, etc.)                   │
│  │ > Today     │                                                             │
│  │   Session 1 │                                                             │
│  │   Session 2 │                                                             │
│  │ > Yesterday │                                                             │
│  │   Session 3 │                                                             │
│  └─────────────┘                                                             │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### SwiftUI Implementation

```swift
struct TabBarView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var hoveredTabId: Session.ID?
    @State private var draggedTabId: Session.ID?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(sessionManager.sessions) { session in
                    SessionTabView(
                        session: session,
                        isActive: session.id == sessionManager.activeSessionId,
                        isHovered: session.id == hoveredTabId,
                        onSelect: { sessionManager.activate(session.id) },
                        onClose: { Task { await sessionManager.closeSession(session.id) } }
                    )
                    .onHover { isHovered in
                        hoveredTabId = isHovered ? session.id : nil
                    }
                    .onDrag {
                        draggedTabId = session.id
                        return NSItemProvider(object: session.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TabDropDelegate(
                        sessionId: session.id,
                        draggedId: $draggedTabId,
                        sessionManager: sessionManager
                    ))
                }
                
                // New tab button
                Button(action: { showNewSessionSheet() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New Session (⌘T)")
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(.bar)
    }
}

struct SessionTabView: View {
    let session: Session
    let isActive: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // Engine icon
            Image(systemName: session.engineType.iconName)
                .font(.system(size: 10))
                .foregroundStyle(session.state.iconColor)
            
            // Session name
            Text(session.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
            
            // State indicator
            if session.state == .streaming {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
            
            // Close button (visible on hover or active)
            if isActive || isHovered {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

extension SessionState {
    var iconColor: Color {
        switch self {
        case .idle: return .secondary
        case .starting: return .orange
        case .active: return .green
        case .streaming: return .blue
        case .waiting: return .yellow
        case .error: return .red
        case .closing: return .gray
        }
    }
}
```

### 3.2 Windows Mode

Each session opens in its own window. Useful for multi-monitor setups or when working on unrelated projects.

```swift
@main
struct BlazeApp: App {
    @State private var sessionManager = SessionManager.shared
    @AppStorage("sessionLayoutMode") private var layoutMode: SessionLayoutMode = .tabs
    
    var body: some Scene {
        // Primary window group for tabs mode
        WindowGroup {
            if layoutMode == .tabs {
                TabsLayoutView()
                    .environment(sessionManager)
            } else {
                WindowsLayoutRootView()
                    .environment(sessionManager)
            }
        }
        .commands {
            SessionCommands()
        }
        
        // Secondary window group for individual sessions (windows mode)
        WindowGroup(for: Session.ID.self) { $sessionId in
            if let sessionId = sessionId {
                SessionWindowView(sessionId: sessionId)
                    .environment(sessionManager)
            }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
    }
}

struct SessionCommands: Commands {
    @Environment(SessionManager.self) private var sessionManager
    @AppStorage("sessionLayoutMode") private var layoutMode: SessionLayoutMode = .tabs
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Session") {
                Task { try? await sessionManager.createSession(project: .current) }
            }
            .keyboardShortcut("t", modifiers: .command)
            
            Button("New Session in Window") {
                Task {
                    let session = try? await sessionManager.createSession(project: .current)
                    if let session = session {
                        openWindow(value: session.id)
                    }
                }
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Close Session") {
                if let activeId = sessionManager.activeSessionId {
                    Task { await sessionManager.closeSession(activeId) }
                }
            }
            .keyboardShortcut("w", modifiers: .command)
        }
        
        CommandGroup(after: .windowArrangement) {
            Picker("Session Layout", selection: $layoutMode) {
                Text("Tabs").tag(SessionLayoutMode.tabs)
                Text("Windows").tag(SessionLayoutMode.windows)
                Text("Split View").tag(SessionLayoutMode.splitView)
            }
        }
    }
}

enum SessionLayoutMode: String, CaseIterable {
    case tabs
    case windows
    case splitView
    case agentLanes
    
    var displayName: String {
        switch self {
        case .tabs: return "Tabs"
        case .windows: return "Windows"
        case .splitView: return "Split View"
        case .agentLanes: return "Agent Lanes"
        }
    }
}
```

### 3.3 Split View Mode

Two sessions side-by-side in the same window. Useful for comparing outputs or reviewing code.

```swift
struct SplitViewLayout: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var leftSessionId: Session.ID?
    @State private var rightSessionId: Session.ID?
    @State private var splitRatio: CGFloat = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left session
                if let leftId = leftSessionId {
                    SessionContentView(sessionId: leftId)
                        .frame(width: geometry.size.width * splitRatio)
                } else {
                    EmptySessionPlaceholder(position: .left) {
                        showSessionPicker(for: .left)
                    }
                    .frame(width: geometry.size.width * splitRatio)
                }
                
                // Divider (draggable)
                SplitDivider(ratio: $splitRatio)
                    .frame(width: 6)
                
                // Right session
                if let rightId = rightSessionId {
                    SessionContentView(sessionId: rightId)
                } else {
                    EmptySessionPlaceholder(position: .right) {
                        showSessionPicker(for: .right)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Menu {
                    Button("Swap Sides") {
                        swap(&leftSessionId, &rightSessionId)
                    }
                    Button("Reset Split") {
                        splitRatio = 0.5
                    }
                    Divider()
                    Button("Exit Split View") {
                        // Return to tabs mode
                    }
                } label: {
                    Image(systemName: "rectangle.split.2x1")
                }
            }
        }
    }
}

struct SplitDivider: View {
    @Binding var ratio: CGFloat
    @State private var isDragging = false
    
    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.accentColor : Color.separator)
            .frame(width: 1)
            .padding(.horizontal, 2.5)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        // Calculate new ratio based on drag
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}
```

### 3.4 Agent Lanes Mode

Visualizes multiple parallel agents as swim lanes. Used for multi-agent orchestration.

```swift
struct AgentLanesLayout: View {
    @Environment(SessionManager.self) private var sessionManager
    let orchestration: AgentOrchestration
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(orchestration.lanes) { lane in
                    AgentLaneView(lane: lane)
                        .frame(width: 400)
                }
                
                // Add lane button
                Button(action: { orchestration.addLane() }) {
                    VStack {
                        Image(systemName: "plus.circle.dashed")
                            .font(.system(size: 32))
                        Text("Add Agent")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .frame(width: 100, height: 100)
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }
}

struct AgentLaneView: View {
    let lane: AgentLane
    @Environment(SessionManager.self) private var sessionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Lane header
            HStack {
                Image(systemName: lane.session.engineType.iconName)
                Text(lane.name)
                    .font(.headline)
                Spacer()
                
                // Lane status
                StatusBadge(state: lane.session.state)
                
                // Lane actions
                Menu {
                    Button("Pause") { lane.pause() }
                    Button("Cancel") { lane.cancel() }
                    Divider()
                    Button("Remove Lane", role: .destructive) { lane.remove() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .padding()
            .background(.bar)
            
            Divider()
            
            // Lane content (mini chat view)
            SessionContentView(sessionId: lane.session.id, compact: true)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.separator, lineWidth: 1)
        )
    }
}
```

---

## 4. Session Lifecycle

### 4.1 State Machine

```
                                    ┌─────────────────────┐
                                    │                     │
                                    ▼                     │
┌─────────┐    create    ┌─────────────┐    send    ┌─────────────┐
│  (nil)  │─────────────▶│    idle     │───────────▶│  starting   │
└─────────┘              └─────────────┘            └─────────────┘
                               ▲                          │
                               │                          │ process ready
                               │                          ▼
                          ┌────┴────┐              ┌─────────────┐
                          │  idle   │◀─────────────│   active    │
                          └─────────┘   complete   └─────────────┘
                               ▲                          │
                               │                          │ send message
                               │                          ▼
                          ┌────┴────┐              ┌─────────────┐
                          │  error  │◀─────────────│  streaming  │
                          └─────────┘    error     └─────────────┘
                               │                          │
                               │ retry                    │ approval needed
                               ▼                          ▼
                          ┌─────────┐              ┌─────────────┐
                          │ starting│              │   waiting   │
                          └─────────┘              └─────────────┘
                                                         │
                                                         │ decision made
                                                         ▼
                                                   ┌─────────────┐
                                                   │  streaming  │
                                                   └─────────────┘
```

### 4.2 Session Persistence

Sessions are persisted to disk for crash recovery and app restart:

```swift
/// Handles session persistence to disk
actor SessionStore {
    private let baseDirectory: URL
    private let database: SQLiteDatabase
    
    init() {
        baseDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("com.cogit0.blaze/sessions")
    }
    
    /// Save session metadata
    func save(_ session: Session) async throws {
        let data = try JSONEncoder().encode(session)
        let path = sessionMetadataPath(for: session.id)
        try data.write(to: path)
        
        // Also save to SQLite for querying
        try await database.execute("""
            INSERT OR REPLACE INTO sessions 
            (id, name, project_id, working_directory, engine_type, created_at, last_activity_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, [
            session.id.uuidString,
            session.name,
            session.projectId.uuidString,
            session.workingDirectory.path,
            session.engineType.rawValue,
            session.createdAt.timeIntervalSince1970,
            session.lastActivityAt.timeIntervalSince1970
        ])
    }
    
    /// Load session from disk
    func load(_ sessionId: Session.ID) async throws -> Session? {
        let path = sessionMetadataPath(for: sessionId)
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(Session.self, from: data)
    }
    
    /// Append event to session's event log
    func appendEvent(_ event: NormalizedEvent, to sessionId: Session.ID) async throws {
        let path = eventLogPath(for: sessionId)
        let data = try JSONEncoder().encode(event)
        let line = data + Data("\n".utf8)
        
        if FileManager.default.fileExists(atPath: path.path) {
            let handle = try FileHandle(forWritingTo: path)
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
            try handle.close()
        } else {
            try line.write(to: path)
        }
    }
    
    /// Load all events for a session
    func loadEvents(for sessionId: Session.ID) async throws -> [NormalizedEvent] {
        let path = eventLogPath(for: sessionId)
        guard FileManager.default.fileExists(atPath: path.path) else {
            return []
        }
        
        let data = try Data(contentsOf: path)
        let lines = data.split(separator: UInt8(ascii: "\n"))
        
        return try lines.compactMap { line in
            try JSONDecoder().decode(NormalizedEvent.self, from: Data(line))
        }
    }
    
    /// List all persisted sessions
    func listSessions() async throws -> [Session.ID] {
        let rows = try await database.query("""
            SELECT id FROM sessions ORDER BY last_activity_at DESC
        """)
        return rows.compactMap { UUID(uuidString: $0["id"] as? String ?? "") }
    }
    
    // MARK: - Paths
    
    func sessionMetadataPath(for id: Session.ID) -> URL {
        baseDirectory.appendingPathComponent("\(id.uuidString).json")
    }
    
    func eventLogPath(for id: Session.ID) -> URL {
        baseDirectory.appendingPathComponent("\(id.uuidString).jsonl")
    }
}
```

### 4.3 App Lifecycle Integration

```swift
@main
struct BlazeApp: App {
    @State private var sessionManager = SessionManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // App became active
                Task {
                    await sessionManager.resumeAllSessions()
                }
                
            case .inactive:
                // App going to background
                Task {
                    await sessionManager.pauseAllSessions()
                }
                
            case .background:
                // App in background - save state
                Task {
                    await sessionManager.persistState()
                }
                
            @unknown default:
                break
            }
        }
    }
}
```

---

## 5. Worktree Integration

### 5.1 Git Worktree Discovery

```swift
/// Manages git worktree operations
actor GitWorktreeManager {
    
    /// List all worktrees for a repository
    func listWorktrees(in repoPath: URL) async throws -> [GitWorktree] {
        let output = try await runGit(["worktree", "list", "--porcelain"], in: repoPath)
        return parseWorktreeList(output)
    }
    
    /// Create a new worktree
    func createWorktree(
        in repoPath: URL,
        branch: String,
        path: URL? = nil
    ) async throws -> GitWorktree {
        let worktreePath = path ?? defaultWorktreePath(for: branch, in: repoPath)
        
        try await runGit([
            "worktree", "add",
            worktreePath.path,
            branch
        ], in: repoPath)
        
        return GitWorktree(
            path: worktreePath,
            branch: branch,
            commit: try await getCurrentCommit(in: worktreePath),
            isMain: false
        )
    }
    
    /// Remove a worktree
    func removeWorktree(_ worktree: GitWorktree, in repoPath: URL) async throws {
        try await runGit(["worktree", "remove", worktree.path.path], in: repoPath)
    }
    
    private func defaultWorktreePath(for branch: String, in repoPath: URL) -> URL {
        let sanitizedBranch = branch.replacingOccurrences(of: "/", with: "-")
        return repoPath
            .deletingLastPathComponent()
            .appendingPathComponent(".blaze-worktrees")
            .appendingPathComponent(sanitizedBranch)
    }
}

struct GitWorktree: Identifiable, Codable {
    var id: URL { path }
    let path: URL
    let branch: String
    let commit: String
    let isMain: Bool
}
```

### 5.2 New Session with Worktree Selection

```swift
struct NewSessionSheet: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    
    @State private var selectedWorktree: GitWorktree?
    @State private var worktrees: [GitWorktree] = []
    @State private var selectedEngine: EngineType = .claudeCode
    @State private var sessionName: String = ""
    @State private var isCreatingWorktree = false
    @State private var newBranchName = ""
    
    var body: some View {
        Form {
            Section("Project") {
                LabeledContent("Name", value: project.name)
                LabeledContent("Path", value: project.rootURL.path)
            }
            
            Section("Working Directory") {
                Picker("Worktree", selection: $selectedWorktree) {
                    Text("Main: \(project.rootURL.lastPathComponent)")
                        .tag(nil as GitWorktree?)
                    
                    if !worktrees.isEmpty {
                        Divider()
                        ForEach(worktrees) { worktree in
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                Text(worktree.branch)
                                Spacer()
                                Text(worktree.path.lastPathComponent)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(worktree as GitWorktree?)
                        }
                    }
                }
                
                DisclosureGroup("Create New Worktree", isExpanded: $isCreatingWorktree) {
                    TextField("Branch name", text: $newBranchName)
                    
                    Button("Create Worktree") {
                        Task {
                            let worktree = try await GitWorktreeManager()
                                .createWorktree(in: project.rootURL, branch: newBranchName)
                            worktrees.append(worktree)
                            selectedWorktree = worktree
                            isCreatingWorktree = false
                            newBranchName = ""
                        }
                    }
                    .disabled(newBranchName.isEmpty)
                }
            }
            
            Section("Engine") {
                Picker("AI Engine", selection: $selectedEngine) {
                    ForEach(EngineType.allCases, id: \.self) { engine in
                        Label(engine.displayName, systemImage: engine.iconName)
                            .tag(engine)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Session") {
                TextField("Session Name (optional)", text: $sessionName)
                    .textFieldStyle(.roundedBorder)
                
                Text("Leave blank to auto-generate from project and branch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create Session") {
                    createSession()
                }
                .keyboardShortcut(.return)
            }
        }
        .task {
            worktrees = (try? await GitWorktreeManager()
                .listWorktrees(in: project.rootURL)) ?? []
        }
    }
    
    private func createSession() {
        Task {
            let session = try await sessionManager.createSession(
                project: project,
                worktree: selectedWorktree,
                engine: selectedEngine,
                name: sessionName.isEmpty ? nil : sessionName
            )
            dismiss()
        }
    }
}
```

---

## 6. Keyboard Shortcuts

### 6.1 Session Navigation

| Shortcut | Action |
|----------|--------|
| `⌘T` | New session (tab) |
| `⌘⇧N` | New session (window) |
| `⌘W` | Close current session |
| `⌘⇧W` | Close window |
| `⌘1` - `⌘9` | Switch to session 1-9 |
| `⌘⇧[` | Previous session |
| `⌘⇧]` | Next session |
| `⌘⇧O` | Quick switch session (fuzzy search) |
| `⌘\` | Toggle split view |
| `⌘⌥\` | Add session to split |

### 6.2 Implementation

```swift
struct SessionKeyboardShortcuts: Commands {
    @Environment(SessionManager.self) private var sessionManager
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Session") {
                Task { try? await sessionManager.createSession(project: .current) }
            }
            .keyboardShortcut("t", modifiers: .command)
            
            Button("New Session in Window") {
                // Open in new window
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        
        CommandGroup(after: .newItem) {
            Divider()
            
            ForEach(0..<min(9, sessionManager.sessions.count), id: \.self) { index in
                Button("Switch to \(sessionManager.sessions[index].name)") {
                    sessionManager.activate(sessionManager.sessions[index].id)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
            
            Divider()
            
            Button("Previous Session") {
                sessionManager.activatePrevious()
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            
            Button("Next Session") {
                sessionManager.activateNext()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
        }
        
        CommandGroup(replacing: .windowSize) {
            Button("Toggle Split View") {
                // Toggle split mode
            }
            .keyboardShortcut("\\", modifiers: .command)
            
            Button("Add to Split") {
                // Add current session to split
            }
            .keyboardShortcut("\\", modifiers: [.command, .option])
        }
    }
}
```

---

## 7. Settings

### 7.1 Session Preferences

```swift
struct SessionPreferencesView: View {
    @AppStorage("sessionLayoutMode") private var layoutMode: SessionLayoutMode = .tabs
    @AppStorage("restoreSessionsOnLaunch") private var restoreOnLaunch = true
    @AppStorage("confirmCloseActiveSessions") private var confirmClose = true
    @AppStorage("maxConcurrentSessions") private var maxSessions = 10
    @AppStorage("defaultEngine") private var defaultEngine: EngineType = .claudeCode
    
    var body: some View {
        Form {
            Section("Layout") {
                Picker("Session Layout", selection: $layoutMode) {
                    ForEach(SessionLayoutMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text("Choose how sessions are displayed. Tabs is recommended for most users.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Behavior") {
                Toggle("Restore sessions on launch", isOn: $restoreOnLaunch)
                Toggle("Confirm before closing active sessions", isOn: $confirmClose)
                
                Stepper("Maximum concurrent sessions: \(maxSessions)", value: $maxSessions, in: 1...50)
            }
            
            Section("Defaults") {
                Picker("Default AI Engine", selection: $defaultEngine) {
                    ForEach(EngineType.allCases, id: \.self) { engine in
                        Label(engine.displayName, systemImage: engine.iconName)
                            .tag(engine)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

---

## 8. Cross-Session Features

### 8.1 Unified Command Palette

The command palette searches across all sessions:

```swift
struct CommandPaletteResults: View {
    let query: String
    @Environment(SessionManager.self) private var sessionManager
    
    var body: some View {
        List {
            // Session switching
            Section("Sessions") {
                ForEach(matchingSessions) { session in
                    CommandRow(
                        icon: session.engineType.iconName,
                        title: "Switch to \(session.name)",
                        subtitle: session.workingDirectory.path
                    ) {
                        sessionManager.activate(session.id)
                    }
                }
            }
            
            // Cross-session search results
            Section("Messages") {
                ForEach(matchingMessages) { result in
                    CommandRow(
                        icon: "message",
                        title: result.preview,
                        subtitle: "in \(result.session.name)"
                    ) {
                        sessionManager.activate(result.session.id)
                        // Scroll to message
                    }
                }
            }
        }
    }
    
    var matchingSessions: [Session] {
        sessionManager.sessions.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.workingDirectory.path.localizedCaseInsensitiveContains(query)
        }
    }
    
    var matchingMessages: [MessageSearchResult] {
        // Search across all session event logs
        []
    }
}
```

### 8.2 Cross-Session Copy/Paste

```swift
extension SessionManager {
    /// Copy content from one session for use in another
    func copyFromSession(_ sourceId: Session.ID, content: CopyableContent) {
        clipboard = SessionClipboard(sourceSessionId: sourceId, content: content)
    }
    
    /// Paste copied content into target session
    func pasteToSession(_ targetId: Session.ID) async throws {
        guard let clipboard = clipboard else { return }
        
        switch clipboard.content {
        case .message(let text):
            try await send(message: "Context from another session:\n\(text)", to: targetId)
            
        case .diff(let diff):
            try await send(message: "Apply this diff:\n```diff\n\(diff)\n```", to: targetId)
            
        case .toolOutput(let output):
            try await send(message: "Output from another session:\n```\n\(output)\n```", to: targetId)
        }
    }
}

enum CopyableContent {
    case message(String)
    case diff(String)
    case toolOutput(String)
}

struct SessionClipboard {
    let sourceSessionId: Session.ID
    let content: CopyableContent
    let copiedAt: Date = Date()
}
```

---

## 9. Performance Considerations

### 9.1 Resource Limits

| Resource | Limit | Behavior at Limit |
|----------|-------|-------------------|
| Concurrent sessions | 10 (configurable) | New session prompt to close one |
| CLI processes | 10 | Same as sessions |
| Event log size | 100MB per session | Auto-compact older events |
| Memory per session | ~50MB baseline | Warning at 200MB |

### 9.2 Process Management

```swift
extension SessionManager {
    /// Monitor resource usage across sessions
    func monitorResources() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                for session in sessions {
                    if let runner = engineRunners[session.id] {
                        let usage = await runner.resourceUsage()
                        
                        if usage.memory > 200_000_000 { // 200MB
                            await showResourceWarning(session: session, usage: usage)
                        }
                    }
                }
            }
        }
    }
    
    /// Cleanup idle sessions to free resources
    func cleanupIdleSessions(olderThan: TimeInterval = 3600) async {
        let cutoff = Date().addingTimeInterval(-olderThan)
        
        for session in sessions where session.state == .idle && session.lastActivityAt < cutoff {
            if let runner = engineRunners[session.id] {
                await runner.terminateProcess()
                // Keep session metadata, just free the process
            }
        }
    }
}
```

---

## 10. Testing Strategy

### 10.1 Unit Tests

```swift
final class SessionManagerTests: XCTestCase {
    var sessionManager: SessionManager!
    var mockProject: Project!
    
    override func setUp() async throws {
        sessionManager = SessionManager()
        mockProject = Project(
            id: UUID(),
            name: "Test Project",
            rootURL: FileManager.default.temporaryDirectory
        )
    }
    
    func testCreateSession() async throws {
        let session = try await sessionManager.createSession(project: mockProject)
        
        XCTAssertEqual(sessionManager.sessions.count, 1)
        XCTAssertEqual(sessionManager.activeSessionId, session.id)
        XCTAssertEqual(session.projectId, mockProject.id)
        XCTAssertEqual(session.state, .idle)
    }
    
    func testMultipleSessions() async throws {
        let session1 = try await sessionManager.createSession(project: mockProject)
        let session2 = try await sessionManager.createSession(project: mockProject)
        
        XCTAssertEqual(sessionManager.sessions.count, 2)
        XCTAssertEqual(sessionManager.activeSessionId, session2.id)
    }
    
    func testCloseSession() async throws {
        let session = try await sessionManager.createSession(project: mockProject)
        await sessionManager.closeSession(session.id, force: true)
        
        XCTAssertTrue(sessionManager.sessions.isEmpty)
        XCTAssertNil(sessionManager.activeSessionId)
    }
    
    func testSwitchSession() async throws {
        let session1 = try await sessionManager.createSession(project: mockProject)
        let _ = try await sessionManager.createSession(project: mockProject)
        
        sessionManager.activate(session1.id)
        
        XCTAssertEqual(sessionManager.activeSessionId, session1.id)
    }
}
```

### 10.2 Integration Tests

```swift
final class MultiSessionIntegrationTests: XCTestCase {
    func testConcurrentSessionsWithDifferentWorktrees() async throws {
        // Create project with worktrees
        let project = try await createTestProject()
        let worktree1 = try await GitWorktreeManager().createWorktree(
            in: project.rootURL,
            branch: "feature-1"
        )
        let worktree2 = try await GitWorktreeManager().createWorktree(
            in: project.rootURL,
            branch: "feature-2"
        )
        
        // Create sessions
        let session1 = try await SessionManager.shared.createSession(
            project: project,
            worktree: worktree1
        )
        let session2 = try await SessionManager.shared.createSession(
            project: project,
            worktree: worktree2
        )
        
        // Verify isolation
        XCTAssertEqual(session1.workingDirectory, worktree1.path)
        XCTAssertEqual(session2.workingDirectory, worktree2.path)
        
        // Send messages concurrently
        async let result1 = SessionManager.shared.send(
            message: "What branch am I on?",
            to: session1.id
        )
        async let result2 = SessionManager.shared.send(
            message: "What branch am I on?",
            to: session2.id
        )
        
        // Both should complete without interference
        try await result1
        try await result2
    }
}
```

---

## 11. Acceptance Criteria

| Requirement | Criteria | Priority |
|-------------|----------|----------|
| Tab-based sessions | Cmd+T creates new tab, tabs display in tab bar, Cmd+1-9 switches | P0 |
| Concurrent CLI processes | Each session spawns independent CLI, processes don't interfere | P0 |
| Session state isolation | Message to session A doesn't affect session B | P0 |
| Worktree integration | New session shows worktree picker, sessions track worktree | P0 |
| Session persistence | Sessions survive app restart, event logs preserved | P0 |
| Window mode | Setting to use windows instead of tabs | P1 |
| Split view mode | Side-by-side sessions, adjustable divider | P1 |
| Session drag-and-drop | Reorder tabs, drag to new window | P2 |
| Agent lanes | Parallel agents visualized as swim lanes | P3 |
| Cross-session copy | Copy messages/diffs between sessions | P2 |
| Unified search | Command palette searches across all sessions | P1 |

---

## 12. Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-26 | Product Team | Initial specification |

---

**End of Document**
