import SwiftUI
import os.log

private let appStateLog = OSLog(subsystem: "com.cogit0.Blaze", category: "AppState")

// MARK: - Notification Names

extension Notification.Name {
    static let openUIGallery = Notification.Name("openUIGallery")
    static let openSettings = Notification.Name("openSettings")
}

// MARK: - Window Actions (for commands to access)

/// Shared holder for window actions since Commands can't access Environment
@MainActor
final class WindowActions: ObservableObject {
    static let shared = WindowActions()
    var openUIGallery: OpenWindowAction?
}

/// Cogit0 Blaze - Native macOS harness for agentic coding CLIs
@main
struct BlazeApp: App {
    @StateObject private var appState: AppState
    @State private var themeManager: ThemeManager
    @AppStorage("globalFontScale") private var globalFontScale: Double = 1.0

    // MARK: - Onboarding & Tutorial State
    @State private var onboardingViewModel = OnboardingViewModel()
    @State private var tutorialViewModel = TutorialViewModel()

    init() {
        // Initialize theme system first (needed for DSColors)
        let themeStore = ThemeStore()
        let manager = ThemeManager(themeStore: themeStore)
        _themeManager = State(initialValue: manager)

        // Wire up DSColors to read from ThemeManager
        DSColors.themeManager = manager
        // Initialize databases in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let blazeDir = appSupport.appendingPathComponent("Blaze", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: blazeDir, withIntermediateDirectories: true)

        let dbPath = blazeDir.appendingPathComponent("blaze.db").path
        let jsonlPath = blazeDir.appendingPathComponent("events.jsonl").path

        // Initialize stores (with fallback for errors)
        var sessionStore: SessionStore?
        var eventStore: EventStore?
        var tokenStore: TokenStore?
        var logStore: LogStore?
        var hookExecutionStore: HookExecutionStore?

        do {
            sessionStore = try SessionStore(path: dbPath)
            eventStore = try EventStore(dbPath: dbPath, jsonlPath: jsonlPath)

            // Initialize TokenStore, LogStore, and HookExecutionStore with same dbPool as SessionStore
            if let sessionStore = sessionStore {
                tokenStore = TokenStore(dbPool: sessionStore.database)
                logStore = LogStore(dbPool: sessionStore.database)
                hookExecutionStore = HookExecutionStore(dbPool: sessionStore.database)
            }
        } catch {
            print("[BlazeApp] Failed to initialize stores: \(error)")
        }

        // Initialize engine manager with Claude adapter
        let engineManager = EngineManager()

        // Initialize orchestrator with engineManager for PTY support
        let orchestrator = SessionOrchestrator(engineManager: engineManager, eventStore: eventStore)

        // Create AppState with dependencies
        let state = AppState(
            sessionStore: sessionStore,
            eventStore: eventStore,
            tokenStore: tokenStore,
            logStore: logStore,
            hookExecutionStore: hookExecutionStore,
            engineManager: engineManager,
            orchestrator: orchestrator
        )

        _appState = StateObject(wrappedValue: state)

        // Register adapters and run migrations after AppState is created
        Task { @MainActor in
            // Run database migrations first
            if let store = sessionStore {
                do {
                    let version = try await store.runMigrations()
                    print("[BlazeApp] Migrations complete, schema version: \(version)")
                } catch {
                    print("[BlazeApp] Migration failed: \(error)")
                }
            }

            // Register engine adapters (E005-F008-S002-T014-A001: Register all providers)
            let claudeAdapter = ClaudeCodeAdapter()
            let geminiAdapter = GeminiCliAdapter()
            let codexAdapter = CodexCliAdapter()
            engineManager.register(adapter: claudeAdapter)
            engineManager.register(adapter: geminiAdapter)
            engineManager.register(adapter: codexAdapter)
            await engineManager.validateAll()

            // Load persisted theme selection
            await manager.loadActiveTheme()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // Use isComplete (observable) not hasCompletedOnboarding (@ObservationIgnored)
                // Also check persisted value for app restart scenarios
                if onboardingViewModel.isComplete || onboardingViewModel.hasCompletedOnboarding {
                    // Normal app flow with tutorial overlay
                    MainContentView()
                        .environment(\.tutorialViewModel, tutorialViewModel)
                        .tutorialOverlay()
                } else {
                    // First launch: show onboarding
                    OnboardingRootView()
                        .environment(onboardingViewModel)
                }
            }
            .environmentObject(appState)
            .environment(\.themeManager, themeManager)
            .environment(\.globalFontScale, globalFontScale)
            .themeAware()
            .task {
                // CRITICAL: Ensure app is a regular foreground app with menu bar.
                // SPM-built SwiftUI apps don't activate as foreground by default.
                // This must run for BOTH onboarding and main content paths.
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    appState.createNewSession()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            // Settings command (Cmd+,) - replaces built-in since we use Window instead of Settings scene
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Session") {
                Button("Clear Context") {
                    appState.clearCurrentContext()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Divider()

                Button("Export Session...") {
                    appState.exportCurrentSession()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            // Developer tools menu
            CommandMenu("Developer") {
                Button("UI Gallery") {
                    print("[DEBUG] UI Gallery menu clicked")
                    print("[DEBUG] WindowActions.shared.openUIGallery: \(WindowActions.shared.openUIGallery != nil ? "set" : "nil")")
                    NotificationCenter.default.post(name: .openUIGallery, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .option])
            }

            // Editor menu for file editing commands
            CommandMenu("Editor") {
                Button("Format Document") {
                    Task {
                        await appState.formatCurrentDocument()
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(!appState.canFormatCurrentDocument)
            }

            // View menu for display controls
            CommandMenu("View") {
                Button("Increase Font Size") {
                    globalFontScale = min(globalFontScale + 0.1, 2.0)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Font Size") {
                    globalFontScale = max(globalFontScale - 0.1, 0.5)
                }
                .keyboardShortcut("-", modifiers: .command)

                Divider()

                Button("Reset Font Size") {
                    globalFontScale = 1.0
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }

        // UI Gallery window for visual QA
        Window("UI Gallery", id: "ui-gallery") {
            UIGalleryView()
                .onAppear {
                    print("[DEBUG] UIGalleryView appeared!")
                }
        }
        .defaultSize(width: 1200, height: 800)

        // Settings window (using Window instead of Settings scene for full transparency control)
        Window("Settings", id: "settings") {
            SettingsWindowContent()
                .environment(\.themeManager, themeManager)
                .environment(\.globalFontScale, globalFontScale)
                .themeAware()
        }
        .defaultSize(width: 750, height: 550)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

// MARK: - Center Pane Mode

/// Mode for the center pane display
public enum CenterPaneMode: String, Codable, Sendable {
    case chat
    case files
    case split // Future: side-by-side view
}

/// Represents an open file tab in the file viewer
public struct FileTab: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let filePath: String
    public var isPreview: Bool  // Preview tabs auto-close when opening another file
    public let openedAt: Date
    public var isDirty: Bool  // Has unsaved changes
    public var originalContent: String?  // Original content for dirty detection

    public var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    public var fileExtension: String {
        (filePath as NSString).pathExtension.lowercased()
    }

    public init(id: UUID = UUID(), filePath: String, isPreview: Bool = false) {
        self.id = id
        self.filePath = filePath
        self.isPreview = isPreview
        self.openedAt = Date()
        self.isDirty = false
        self.originalContent = nil
    }
}

/// Global application state
@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State

    @Published var sessions: [Session] = []
    @Published var currentSessionId: UUID? {
        didSet {
            if let sessionId = currentSessionId, sessionId != oldValue {
                loadEventsForSession(sessionId)

                // Bug 2 fix: Clear unread count when switching to a session
                if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
                    var updatedSession = sessions[index]
                    updatedSession.unreadCount = 0
                    sessions[index] = updatedSession
                    updateSessionGrouping()
                }
            }
        }
    }
    /// Set of session IDs currently processing (enables per-session typing indicators)
    @Published var processingSessionIds: Set<UUID> = []

    /// Computed property: true if the current session is processing
    var isProcessing: Bool {
        guard let currentSessionId else { return false }
        return processingSessionIds.contains(currentSessionId)
    }

    /// Check if a specific session is processing
    func isProcessing(sessionId: UUID) -> Bool {
        processingSessionIds.contains(sessionId)
    }

    @Published var currentError: String?

    // MARK: - Center Pane State

    /// Current center pane display mode
    @Published var centerPaneMode: CenterPaneMode = .chat

    /// Open file tabs in the file viewer
    @Published var openFileTabs: [FileTab] = []

    /// Currently active file tab ID
    @Published var activeFileTabId: UUID?

    /// Event storage per session (sessionId -> events)
    @Published private var sessionEvents: [UUID: [EventEnvelope]] = [:]

    /// ID of event to scroll to in chat timeline
    @Published var scrollToEventId: UUID?

    /// Pending diffs awaiting user decision (sessionId -> diffs)
    @Published var pendingDiffs: [UUID: [FileDiff]] = [:]

    /// Editor sessions for syntax highlighting and diagnostics (tabId -> EditorSession)
    private var editorSessions: [UUID: EditorSession] = [:]

    // MARK: - Tool Prompt State

    /// FIFO queue for pending tool prompts
    let promptQueue = PromptQueue()

    /// Policy evaluator for tool prompt safety
    let promptPolicyEvaluator = PromptPolicyEvaluator()

    /// Current tool prompt (front of queue)
    @Published var currentToolPrompt: ToolPromptEvent?

    /// Submission state for current prompt
    @Published var promptSubmissionState: SubmissionState = .idle

    /// Policy decision for current prompt
    @Published var promptPolicyDecision: PromptPolicyDecision = .allow

    /// Number of pending prompts in queue
    @Published var pendingPromptCount: Int = 0

    private struct PromptResponseRecord {
        let prompt: ToolPromptEvent
        var response: ToolPromptResponse
    }

    private var promptResponseBatch: [PromptResponseRecord] = []

    // MARK: - Dependencies

    let sessionStore: SessionStore?
    let eventStore: EventStore?
    let tokenStore: TokenStore?
    let logStore: LogStore?
    let hookExecutionStore: HookExecutionStore?
    let engineManager: EngineManager
    let orchestrator: SessionOrchestrator
    let diffService: DiffService
    let terminalManager: TerminalManager

    // MARK: - Subagent Infrastructure

    /// Registry for tracking subagent correlations (toolUseId ↔ internalId)
    let subagentRegistry: SubagentRegistry

    /// Pool for managing subagent concurrency and queue
    let subagentPool: SubagentPool

    // MARK: - Active Tasks

    private var activeTurnTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        sessionStore: SessionStore? = nil,
        eventStore: EventStore? = nil,
        tokenStore: TokenStore? = nil,
        logStore: LogStore? = nil,
        hookExecutionStore: HookExecutionStore? = nil,
        engineManager: EngineManager? = nil,
        orchestrator: SessionOrchestrator? = nil,
        diffService: DiffService? = nil,
        terminalManager: TerminalManager? = nil,
        subagentRegistry: SubagentRegistry? = nil,
        subagentPool: SubagentPool? = nil
    ) {
        self.sessionStore = sessionStore
        self.eventStore = eventStore
        self.tokenStore = tokenStore
        self.logStore = logStore
        self.hookExecutionStore = hookExecutionStore
        self.engineManager = engineManager ?? EngineManager()
        // Orchestrator requires engineManager for PTY-based adapter access
        self.orchestrator = orchestrator ?? SessionOrchestrator(engineManager: self.engineManager)
        self.diffService = diffService ?? DiffService()
        self.terminalManager = terminalManager ?? TerminalManager()

        // Initialize subagent infrastructure
        let registry = subagentRegistry ?? SubagentRegistry()
        self.subagentRegistry = registry
        self.subagentPool = subagentPool ?? SubagentPool(registry: registry)

        // Load sessions from store
        if let store = sessionStore {
            Task {
                do {
                    let loaded = try await store.getAll()
                    await MainActor.run {
                        self.sessions = loaded
                        self.updateSessionGrouping()
                        if let first = loaded.first {
                            self.currentSessionId = first.id
                        }
                    }

                    // Scan for orphan worktrees after sessions are loaded (Phase 2)
                    await self.scanForOrphanWorktrees()
                } catch {
                    print("[AppState] Failed to load sessions: \(error)")
                }
            }
        }
    }

    // MARK: - Session Management

    /// Whether the new session modal should be shown
    @Published var showNewSessionModal: Bool = false

    /// Git worktree manager for session isolation
    let gitWorktreeManager = GitWorktreeManager()

    /// Sessions grouped by project path for sidebar display
    @Published var sessionsGroupedByProject: [String: [Session]] = [:]

    /// Orphan worktrees detected on startup (worktrees without matching sessions)
    @Published var orphanWorktrees: [OrphanWorktree] = []

    /// Whether we're currently scanning for orphan worktrees
    @Published var isScanningOrphans: Bool = false

    func createNewSession() {
        // Phase 2: Show modal for directory selection
        showNewSessionModal = true
    }

    /// Create a new session with worktree isolation (Phase 2 flow)
    func createSessionWithWorktree(
        name: String,
        projectPath: String,
        trustMode: TrustMode = .prompt,
        baseBranch: String? = nil,
        provider: AIProvider = .anthropic
    ) async {
        // Canonicalize path
        guard let canonicalPath = PathUtilities.canonicalize(projectPath) else {
            currentError = "Invalid project path: \(projectPath)"
            return
        }

        // Create session in "creating" state
        let sessionId = UUID()
        let defaultModelId = AIModelRegistry.defaultModel(for: provider)?.id ?? "sonnet"
        var session = Session(
            id: sessionId,
            name: name,
            originalProjectPath: canonicalPath,
            status: .creating,
            trustMode: trustMode,
            engineType: provider.engineType,
            provider: provider,
            modelId: defaultModelId
        )

        // Add to local state immediately
        sessions.append(session)
        currentSessionId = session.id
        sessionEvents[session.id] = []
        updateSessionGrouping()

        // Persist initial session
        if let store = sessionStore {
            do {
                try await store.create(session)
            } catch {
                print("[AppState] Failed to persist session: \(error)")
                currentError = "Failed to create session: \(error.localizedDescription)"
                // Remove from local state
                sessions.removeAll { $0.id == sessionId }
                updateSessionGrouping()
                return
            }
        }

        // Create worktree
        do {
            let worktreeInfo = try await gitWorktreeManager.createWorktree(
                repoPath: canonicalPath,
                sessionId: sessionId,
                baseBranch: baseBranch
            )

            // Update session with worktree info
            session.worktreePath = worktreeInfo.path
            session.branchName = worktreeInfo.branchName
            session.status = .ready

            // Update local state
            if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
                sessions[index] = session
            }
            updateSessionGrouping()

            // Update in store
            if let store = sessionStore {
                try await store.updateWorktree(
                    sessionId,
                    worktreePath: worktreeInfo.path,
                    branchName: worktreeInfo.branchName ?? ""
                )
            }

            print("[AppState] Created session with worktree: \(worktreeInfo.path)")
        } catch {
            print("[AppState] Failed to create worktree: \(error)")
            currentError = "Failed to create worktree: \(error.localizedDescription)"

            // Update session to errored state
            session.status = .errored

            if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
                sessions[index] = session
            }
            updateSessionGrouping()

            if let store = sessionStore {
                try? await store.updateStatus(sessionId, status: .errored)
            }
        }
    }

    /// Create a quick session without worktree (legacy mode)
    func createQuickSession() {
        // Default project path to user's home directory
        // This ensures the CLI has a valid working directory for file operations
        let defaultProjectPath = FileManager.default.homeDirectoryForCurrentUser.path
        let session = Session(name: "New Session", projectPath: defaultProjectPath)
        sessions.append(session)
        currentSessionId = session.id
        sessionEvents[session.id] = []
        updateSessionGrouping()

        // Persist to store
        if let store = sessionStore {
            Task {
                do {
                    try await store.create(session)
                } catch {
                    print("[AppState] Failed to persist session: \(error)")
                }
            }
        }
    }

    /// Update sessions grouped by project for sidebar display
    private func updateSessionGrouping() {
        var grouped: [String: [Session]] = [:]
        for session in sessions {
            let projectKey = session.originalProjectPath ?? session.projectPath ?? ""
            if grouped[projectKey] == nil {
                grouped[projectKey] = []
            }
            grouped[projectKey]?.append(session)
        }
        sessionsGroupedByProject = grouped
    }

    // MARK: - Session Reordering

    /// Reorder sessions within a project group (drag and drop)
    func reorderSessions(projectPath: String, from source: IndexSet, to destination: Int) {
        guard var projectSessions = sessionsGroupedByProject[projectPath] else { return }

        // Perform the move within the project's sessions
        projectSessions.move(fromOffsets: source, toOffset: destination)

        // Update the display order in the session metadata
        // For now, we update timestamps to maintain order (crude but effective)
        // Future: Add explicit displayOrder field to Session model
        var now = Date()
        for (_, session) in projectSessions.enumerated().reversed() {
            if let globalIndex = sessions.firstIndex(where: { $0.id == session.id }) {
                // Adjust updatedAt slightly to preserve order
                sessions[globalIndex].updatedAt = now
                now = now.addingTimeInterval(-1) // Each prior session is 1 second older
            }
        }

        // Update grouping
        updateSessionGrouping()

        // Persist changes
        Task {
            for session in projectSessions {
                if let store = sessionStore {
                    try? await store.update(session)
                }
            }
        }
    }

    /// Move a session to a different project (cross-project drag)
    func moveSessionToProject(sessionId: UUID, toProjectPath: String) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) else { return }

        // Update the session's project path
        sessions[sessionIndex].originalProjectPath = toProjectPath.isEmpty ? nil : toProjectPath
        sessions[sessionIndex].projectPath = toProjectPath.isEmpty ? nil : toProjectPath
        sessions[sessionIndex].updatedAt = Date()

        // Update grouping
        updateSessionGrouping()

        // Persist the change
        Task {
            if let store = sessionStore {
                try? await store.update(sessions[sessionIndex])
            }
        }
    }

    /// Get display name for a project path
    func projectDisplayName(for path: String) -> String {
        if path.isEmpty {
            return "Uncategorized"
        }
        return (path as NSString).lastPathComponent
    }

    // MARK: - Subagent Management

    /// Get all subagents for a session
    func getSubagents(for sessionId: UUID) async -> [SubagentCorrelation] {
        await subagentRegistry.getAll(for: sessionId)
    }

    /// Get running subagents for a session
    func getRunningSubagents(for sessionId: UUID) async -> [SubagentCorrelation] {
        await subagentRegistry.getAll(for: sessionId).filter { $0.status == .running }
    }

    /// Get queued subagents for a session
    func getQueuedSubagents(for sessionId: UUID) async -> [SubagentCorrelation] {
        await subagentRegistry.getAll(for: sessionId)
            .filter { $0.status == .queued }
            .sorted { ($0.queuePosition ?? Int.max) < ($1.queuePosition ?? Int.max) }
    }

    // MARK: - Orphan Worktree Management

    /// Scan for orphan worktrees (worktrees without matching sessions).
    /// Called on startup per Phase 2 System Contract.
    func scanForOrphanWorktrees() async {
        await MainActor.run {
            isScanningOrphans = true
        }

        defer {
            Task { @MainActor in
                self.isScanningOrphans = false
            }
        }

        // Get unique project paths that might have worktrees
        let projectPaths = sessions.compactMap { $0.originalProjectPath ?? $0.projectPath }
        let uniquePaths = Array(Set(projectPaths))

        guard !uniquePaths.isEmpty else {
            print("[AppState] No project paths to scan for orphan worktrees")
            return
        }

        // Get known session IDs
        let knownSessionIds = Set(sessions.map { $0.id })

        do {
            let orphans = try await gitWorktreeManager.scanForOrphans(
                knownSessionIds: knownSessionIds,
                projectPaths: uniquePaths
            )

            await MainActor.run {
                self.orphanWorktrees = orphans
            }

            if !orphans.isEmpty {
                print("[AppState] Found \(orphans.count) orphan worktree(s)")
                for orphan in orphans {
                    print("  - \(orphan.path) (session: \(orphan.sessionId))")
                }
            }
        } catch {
            print("[AppState] Failed to scan for orphan worktrees: \(error)")
        }
    }

    /// Clean up an orphan worktree
    func cleanupOrphanWorktree(_ orphan: OrphanWorktree) async {
        do {
            try await gitWorktreeManager.removeWorktree(worktreePath: orphan.path)
            await MainActor.run {
                self.orphanWorktrees.removeAll { $0.id == orphan.id }
            }
            print("[AppState] Cleaned up orphan worktree: \(orphan.path)")
        } catch {
            print("[AppState] Failed to clean up orphan worktree: \(error)")
            await MainActor.run {
                self.currentError = "Failed to clean up orphan worktree: \(error.localizedDescription)"
            }
        }
    }

    /// Clean up all orphan worktrees
    func cleanupAllOrphanWorktrees() async {
        for orphan in orphanWorktrees {
            await cleanupOrphanWorktree(orphan)
        }
    }

    func clearCurrentContext() {
        guard let sessionId = currentSessionId else { return }
        sessionEvents[sessionId] = []
        orchestrator.resetSequence(for: sessionId)
    }

    func exportCurrentSession() {
        // TODO: Implement session export
    }

    /// Load events from EventStore for a session
    private func loadEventsForSession(_ sessionId: UUID) {
        guard let store = eventStore else { return }

        // Skip if we already have events loaded for this session
        if sessionEvents[sessionId] != nil && !sessionEvents[sessionId]!.isEmpty {
            return
        }

        Task {
            do {
                let events = try await store.getEvents(sessionId: sessionId)
                await MainActor.run {
                    self.sessionEvents[sessionId] = events
                }
            } catch {
                print("[AppState] Failed to load events for session \(sessionId): \(error)")
            }
        }
    }

    /// Delete a session by ID
    /// - Parameters:
    ///   - sessionId: The session ID to delete
    ///   - deleteWorktree: Whether to also delete the worktree (default: true)
    func deleteSession(_ sessionId: UUID, deleteWorktree: Bool = true) {
        // Get session before removing
        let session = sessions.first { $0.id == sessionId }

        // Remove from local state
        sessions.removeAll { $0.id == sessionId }
        sessionEvents.removeValue(forKey: sessionId)
        pendingDiffs.removeValue(forKey: sessionId)
        updateSessionGrouping()

        // Update current selection if needed
        if currentSessionId == sessionId {
            currentSessionId = sessions.first?.id
        }

        // Remove from store and clean up worktree
        Task {
            // Clean up worktree if requested and it exists
            if deleteWorktree, let worktreePath = session?.worktreePath {
                do {
                    try await gitWorktreeManager.removeWorktree(worktreePath: worktreePath)
                    print("[AppState] Removed worktree: \(worktreePath)")
                } catch {
                    print("[AppState] Failed to remove worktree: \(error)")
                    // Continue with session deletion even if worktree cleanup fails
                }
            }

            // Remove from store
            if let store = sessionStore {
                do {
                    try await store.delete(id: sessionId)
                } catch {
                    print("[AppState] Failed to delete session: \(error)")
                }
            }
        }
    }

    /// Rename a session
    /// - Parameters:
    ///   - sessionId: The session ID to rename
    ///   - newName: The new name for the session
    func renameSession(_ sessionId: UUID, to newName: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }

        // Update local state
        sessions[index].name = newName
        sessions[index].updatedAt = Date()
        updateSessionGrouping()

        // Persist the change
        Task {
            if let store = sessionStore {
                do {
                    try await store.update(sessions[index])
                    print("[AppState] Renamed session to: \(newName)")
                } catch {
                    print("[AppState] Failed to rename session: \(error)")
                }
            }
        }
    }

    /// Update the trust mode for a session
    /// - Parameters:
    ///   - sessionId: The session ID to update
    ///   - trustMode: The new trust mode
    func updateSessionTrustMode(_ sessionId: UUID, trustMode: TrustMode) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }

        // Update local state
        sessions[index].trustMode = trustMode
        sessions[index].updatedAt = Date()

        // Persist the change
        Task {
            if let store = sessionStore {
                do {
                    try await store.update(sessions[index])
                    print("[AppState] Updated session trust mode to: \(trustMode.displayName)")
                } catch {
                    print("[AppState] Failed to update session trust mode: \(error)")
                }
            }
        }
    }

    /// Update the model and/or reasoning effort for a session
    /// - Parameters:
    ///   - sessionId: The session ID to update
    ///   - modelId: Optional new model ID
    ///   - reasoningEffort: Optional new reasoning effort (OpenAI only)
    func updateSessionConfig(sessionId: UUID, modelId: String? = nil, reasoningEffort: ReasoningEffort? = nil) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }

        // Update local state
        var didChange = false
        if let modelId = modelId, sessions[index].modelId != modelId {
            sessions[index].modelId = modelId
            didChange = true
        }
        if let reasoningEffort = reasoningEffort, sessions[index].reasoningEffort != reasoningEffort {
            sessions[index].reasoningEffort = reasoningEffort
            didChange = true
        }

        guard didChange else { return }

        sessions[index].updatedAt = Date()

        // Persist the change
        Task {
            if let store = sessionStore {
                do {
                    try await store.update(sessions[index])
                    if let modelId = modelId {
                        print("[AppState] Updated session model to: \(modelId)")
                    }
                    if let reasoningEffort = reasoningEffort {
                        print("[AppState] Updated session reasoning effort to: \(reasoningEffort.displayName)")
                    }
                } catch {
                    print("[AppState] Failed to update session config: \(error)")
                }
            }
        }
    }

    /// Get the current session
    var currentSession: Session? {
        guard let id = currentSessionId else { return nil }
        return sessions.first { $0.id == id }
    }

    // MARK: - Message Sending

    /// Send a message to the current session
    func sendMessage(_ text: String, isVisible: Bool = true) {
        guard let session = currentSession else {
            currentError = "No active session"
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isVisible {
            // Add user message to session
            let userMessage = Message(role: .user, content: trimmed)
            addMessage(userMessage, to: session.id)
        }

        // Start turn
        processingSessionIds.insert(session.id)
        currentError = nil

        activeTurnTask = Task {
            do {
                // Create assistant message placeholder
                var assistantText = ""
                var assistantThinking = ""
                let assistantMessageId = UUID()

                let stream = orchestrator.executeTurn(
                    prompt: trimmed,
                    session: session,
                    appState: self
                )

                for try await event in stream {
                    switch event {
                    case .thinkingDelta(let delta):
                        assistantThinking += delta.text
                        // Update the assistant message with thinking
                        updateAssistantMessage(
                            id: assistantMessageId,
                            sessionId: session.id,
                            content: assistantText,
                            thinking: assistantThinking
                        )

                    case .assistantDelta(let delta):
                        assistantText += delta.text
                        // Update the assistant message in-place
                        updateAssistantMessage(
                            id: assistantMessageId,
                            sessionId: session.id,
                            content: assistantText,
                            thinking: assistantThinking.isEmpty ? nil : assistantThinking
                        )

                    case .assistantComplete:
                        // Final message is already updated via deltas
                        break

                    case .error(let error):
                        currentError = error.message

                    case .toolCallStarted(let started):
                        // Handle AskUserQuestion tool - route to prompt queue for interactive UI
                        if started.toolName == "AskUserQuestion" {
                            let prompts = self.parseAskUserQuestion(
                                toolCallId: started.toolCallId,
                                input: started.input,
                                timestamp: started.timestamp
                            )
                            for prompt in prompts {
                                self.enqueueToolPrompt(prompt)
                            }
                        }
                        // Route Bash commands to terminal
                        else if started.toolName == "Bash" {
                            let (cmd, isBackground) = extractBashCommand(from: started.input)
                            let prompt = isBackground ? "$ (bg) " : "$ "
                            let displayText = "\(prompt)\(cmd)\n"
                            if let data = displayText.data(using: .utf8) {
                                await terminalManager.writeClaudeOutput(
                                    sessionId: session.id,
                                    output: data,
                                    isBackground: isBackground
                                )
                            }
                        }

                    case .toolCallComplete(let complete):
                        // Route Bash output to terminal
                        if complete.toolName == "Bash" {
                            if let output = complete.output, !output.isEmpty {
                                if let data = output.data(using: .utf8) {
                                    await terminalManager.writeClaudeOutput(
                                        sessionId: session.id,
                                        output: data,
                                        isBackground: false
                                    )
                                }
                            }
                            // Show error if any
                            if let error = complete.error {
                                let errorText = "❌ Error: \(error)\n"
                                if let data = errorText.data(using: .utf8) {
                                    await terminalManager.writeClaudeOutput(
                                        sessionId: session.id,
                                        output: data,
                                        isBackground: false
                                    )
                                }
                            }
                        }

                    default:
                        // Other events handled by orchestrator → AppState.appendEvent
                        break
                    }
                }

                // Persist the final assistant message
                if !assistantText.isEmpty {
                    let finalMessage = Message(
                        id: assistantMessageId,
                        role: .assistant,
                        content: assistantText,
                        thinking: assistantThinking.isEmpty ? nil : assistantThinking
                    )
                    if let store = sessionStore {
                        try? await store.addMessage(finalMessage, sessionId: session.id)
                    }
                }
            } catch {
                currentError = error.localizedDescription
            }

            processingSessionIds.remove(session.id)
        }
    }

    /// Cancel the current turn
    func cancelTurn() {
        activeTurnTask?.cancel()
        Task {
            await orchestrator.cancel()
        }
        // Remove current session from processing
        if let sessionId = currentSessionId {
            processingSessionIds.remove(sessionId)
        }
    }

    // MARK: - Message Management

    private func addMessage(_ message: Message, to sessionId: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            // Use copy-modify-reassign pattern for reliable SwiftUI reactivity
            // (nested mutation like sessions[index].messages.append() doesn't trigger @Published)
            var updated = sessions[index]
            updated.messages.append(message)
            sessions[index] = updated

            // Persist
            if let store = sessionStore {
                Task {
                    try? await store.addMessage(message, sessionId: sessionId)
                }
            }
        }
    }

    private func updateAssistantMessage(id: UUID, sessionId: UUID, content: String, thinking: String? = nil) {
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) {
            // Use copy-modify-reassign pattern for reliable SwiftUI reactivity
            // (nested mutation like sessions[index].messages[i].content = x doesn't trigger @Published)
            var updated = sessions[sessionIndex]

            if let msgIndex = updated.messages.firstIndex(where: { $0.id == id }) {
                // Update existing message
                updated.messages[msgIndex].content = content
                updated.messages[msgIndex].thinking = thinking
            } else {
                // Create new assistant message
                let message = Message(id: id, role: .assistant, content: content, thinking: thinking)
                updated.messages.append(message)
            }

            // Single full element replacement triggers @Published
            sessions[sessionIndex] = updated
        }
    }

    // MARK: - Event Management

    /// Get events for a specific session
    func eventsForSession(_ sessionId: UUID) -> [EventEnvelope] {
        sessionEvents[sessionId] ?? []
    }

    /// Append an event to a session
    func appendEvent(_ event: NormalizedEvent, to sessionId: UUID) {
        let sequence = (sessionEvents[sessionId]?.count ?? 0) + 1
        let envelope = EventEnvelope(sessionId: sessionId, sequence: sequence, event: event)

        if sessionEvents[sessionId] == nil {
            sessionEvents[sessionId] = []
        }
        sessionEvents[sessionId]?.append(envelope)

        // Bug 2 fix: Increment unread count for background sessions
        // Only increment for events that represent visible activity
        let isBackground = sessionId != currentSessionId
        let isVisible = isVisibleEvent(event)
        os_log(.info, log: appStateLog, "appendEvent: sessionId=%{public}@, currentSessionId=%{public}@, isBackground=%{public}d, isVisible=%{public}d, event=%{public}@",
               sessionId.uuidString,
               currentSessionId?.uuidString ?? "nil",
               isBackground ? 1 : 0,
               isVisible ? 1 : 0,
               String(describing: type(of: event)))
        if isBackground && isVisible {
            if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
                // Explicit copy-modify-reassign pattern for reliable SwiftUI reactivity
                var updatedSession = sessions[index]
                updatedSession.unreadCount += 1
                sessions[index] = updatedSession
                updateSessionGrouping()
                os_log(.info, log: appStateLog, "appendEvent: Incremented unreadCount for session %{public}@ to %d",
                       updatedSession.name, updatedSession.unreadCount)
            } else {
                os_log(.error, log: appStateLog, "appendEvent: Session %{public}@ not found in sessions array!", sessionId.uuidString)
            }
        }

        // Track diffs for accept/reject actions
        if case .fileDiffProduced(let diffEvent) = event {
            let fileDiff = FileDiff(filePath: diffEvent.filePath, hunks: diffEvent.hunks)
            addPendingDiff(fileDiff, to: sessionId)
        }
    }

    /// Check if an event represents visible activity for unread badge purposes
    private func isVisibleEvent(_ event: NormalizedEvent) -> Bool {
        switch event {
        // Content events - visible in chat
        case .assistantDelta, .assistantComplete, .thinkingDelta:
            return true
        // Tool events - visible in chat
        case .toolCallStarted, .toolCallComplete:
            return true
        // File events - visible in chat
        case .fileDiffProduced, .fileWritten:
            return true
        // System events - usually not shown as separate items
        case .sessionStarted, .sessionEnded, .tokenUsage:
            return false
        // Errors are visible
        case .error:
            return true
        // Approval events - visible in tool approval UI
        case .toolRequest, .toolDecision, .toolResult:
            return true
        // Subagent events - visible in subagent panel
        case .subagentSpawned, .subagentProgress, .subagentCompleted, .subagentFailed:
            return true
        // File read events - not usually shown separately
        case .fileRead:
            return false
        // Raw events - not shown
        case .raw:
            return false
        // Codex-specific events - visible
        case .turnPlanUpdated, .reasoningDelta, .toolOutputDelta, .fileDiffDelta:
            return true
        // Rate limits - system event, not shown separately
        case .rateLimitsUpdated:
            return false
        // Review mode events - visible in UI
        case .reviewModeEntered, .reviewModeExited:
            return true
        }
    }

    /// Request scrolling to a specific event in the chat timeline
    func scrollToEvent(_ eventId: UUID) {
        scrollToEventId = eventId
    }

    /// Clear the scroll request after it's been handled
    func clearScrollRequest() {
        scrollToEventId = nil
    }

    // MARK: - Diff Management

    /// Get pending diffs for the current session
    var currentSessionDiffs: [FileDiff] {
        guard let sessionId = currentSessionId else { return [] }
        return pendingDiffs[sessionId] ?? []
    }

    /// Add a diff to the pending list
    func addPendingDiff(_ diff: FileDiff, to sessionId: UUID) {
        if pendingDiffs[sessionId] == nil {
            pendingDiffs[sessionId] = []
        }
        pendingDiffs[sessionId]?.append(diff)
    }

    /// Accept a diff and write changes to disk
    func acceptDiff(_ diff: FileDiff) {
        guard let session = currentSession else { return }

        Task {
            do {
                let updatedDiff = try await diffService.acceptDiff(diff, projectPath: session.projectPath ?? FileManager.default.currentDirectoryPath)

                // Update the diff in our pending list
                await MainActor.run {
                    updateDiffDecision(diffId: diff.id, sessionId: session.id, decision: updatedDiff.decision)
                }
            } catch {
                await MainActor.run {
                    currentError = "Failed to accept diff: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Reject a diff and revert changes
    func rejectDiff(_ diff: FileDiff) {
        guard let session = currentSession else { return }

        Task {
            do {
                let updatedDiff = try await diffService.rejectDiff(diff, projectPath: session.projectPath ?? FileManager.default.currentDirectoryPath)

                // Update the diff in our pending list
                await MainActor.run {
                    updateDiffDecision(diffId: diff.id, sessionId: session.id, decision: updatedDiff.decision)
                }
            } catch {
                await MainActor.run {
                    currentError = "Failed to reject diff: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Update a diff's decision in the pending list
    private func updateDiffDecision(diffId: UUID, sessionId: UUID, decision: DiffDecision) {
        if let index = pendingDiffs[sessionId]?.firstIndex(where: { $0.id == diffId }) {
            pendingDiffs[sessionId]?[index].decision = decision
        }
    }

    // MARK: - Tool Prompt Management

    /// Enqueue a new tool prompt (called when tool_use event is received)
    func enqueueToolPrompt(_ prompt: ToolPromptEvent) {
        promptQueue.enqueue(prompt)
        updatePromptState()
    }

    /// Submit response for current tool prompt
    func submitPromptResponse(_ response: ToolPromptResponse) async {
        guard let prompt = currentToolPrompt else { return }

        // Check policy decision
        if case .deny(let reason) = promptPolicyDecision {
            promptQueue.setSubmissionState(.failed(reason), for: prompt.id)
            promptSubmissionState = .failed(reason)
            return
        }

        promptQueue.setSubmissionState(.submitting, for: prompt.id)
        promptSubmissionState = .submitting

        do {
            // Get the adapter and send the tool result
            guard let adapter = engineManager.adapter(for: .claude) as? ClaudeCodeAdapter else {
                throw PromptError.noAdapter
            }

            if prompt.toolName == "AskUserQuestion", !adapter.supportsAskUserQuestionToolResults {
                // Claude CLI headless mode auto-denies AskUserQuestion, so we bridge via a follow-up user message.
                cachePromptResponse(prompt: prompt, response: response)
                await completePromptSubmission(for: prompt)

                if promptQueue.pendingCount > 0 {
                    return
                }

                await waitForTurnToFinish()
                if promptQueue.pendingCount > 0 {
                    return
                }
                let followUp = formatAskUserQuestionFallbackBatch(promptResponseBatch)
                promptResponseBatch.removeAll()
                sendMessage(followUp, isVisible: false)
                return
            }

            let content = toolResultContent(from: response)

            try await adapter.sendToolResult(toolUseId: prompt.toolUseId, content: content)

            // Success - dequeue and update state
            await completePromptSubmission(for: prompt)

        } catch {
            promptQueue.setSubmissionState(.failed(error.localizedDescription), for: prompt.id)
            promptSubmissionState = .failed(error.localizedDescription)
        }
    }

    /// Retry a failed prompt submission
    func retryPromptSubmission(_ response: ToolPromptResponse) async {
        guard let promptId = currentToolPrompt?.id,
              promptQueue.canRetry(promptId: promptId) else { return }
        promptQueue.setSubmissionState(.idle, for: promptId)
        promptSubmissionState = .idle
        await submitPromptResponse(response)
    }

    /// Update published prompt state from queue
    private func updatePromptState() {
        currentToolPrompt = promptQueue.currentPrompt
        pendingPromptCount = promptQueue.pendingCount

        if let prompt = currentToolPrompt {
            promptSubmissionState = promptQueue.submissionState(for: prompt.id)
            promptPolicyDecision = promptPolicyEvaluator.evaluate(prompt)
        } else {
            promptSubmissionState = .idle
            promptPolicyDecision = .allow
        }
    }

    /// Clear all pending prompts (e.g., on session end)
    func clearToolPrompts() {
        promptQueue.clear()
        promptResponseBatch.removeAll()
        updatePromptState()
    }

    /// Parse AskUserQuestion tool input JSON into ToolPromptEvents (one per question).
    func parseAskUserQuestion(toolCallId: String, input: String, timestamp: Date) -> [ToolPromptEvent] {
        // Expected format: {"questions":[{"question":"...","header":"...","options":[{"label":"...","description":"..."}],"multiSelect":false}]}
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let questions = json["questions"] as? [[String: Any]],
              !questions.isEmpty else {
            print("[AppState] Failed to parse AskUserQuestion input: \(input)")
            return []
        }

        var prompts: [ToolPromptEvent] = []
        for (index, question) in questions.enumerated() {
            let questionText = stringValue(question["question"], fallback: "") ?? ""
            let header = stringValue(question["header"], fallback: nil)
            let displayHeader = header ?? (questions.count > 1 ? "Question \(index + 1)" : nil)
            let multiSelect = parseMultiSelect(question: question, root: json)
            let rawOptions = question["options"] as? [[String: Any]] ?? []

            let options: [ToolPromptOption] = rawOptions.enumerated().map { optionIndex, opt in
                let fallbackLabel = "Option \(optionIndex + 1)"
                let label = stringValue(opt["label"], fallback: fallbackLabel) ?? fallbackLabel
                let description = stringValue(opt["description"], fallback: nil)
                let id = stringValue(opt["id"], fallback: label) ?? label
                return ToolPromptOption(id: id, label: label, description: description)
            }

            let promptId = "\(toolCallId)#\(index + 1)"
            let promptIndex = index + 1
            let promptCount = questions.count
            prompts.append(ToolPromptEvent(
                toolUseId: toolCallId,
                toolName: "AskUserQuestion",
                title: displayHeader,
                body: questionText,
                options: options,
                responseType: multiSelect ? .multiSelect : .singleSelect,
                rawInput: input,
                timestamp: timestamp,
                promptId: promptId,
                promptIndex: promptIndex,
                promptCount: promptCount
            ))
        }

        return prompts
    }

    private func toolResultContent(from response: ToolPromptResponse) -> String {
        switch response {
        case .selections(let selections):
            // Format as JSON for Claude to parse
            let ids = selections.map { $0.id }
            return "[\(ids.map { "\"\($0)\"" }.joined(separator: ", "))]"
        case .freeText(let text):
            return text
        }
    }

    private func formatAskUserQuestionFallback(
        prompt: ToolPromptEvent,
        response: ToolPromptResponse
    ) -> String {
        formatAskUserQuestionFallbackBatch([
            PromptResponseRecord(prompt: prompt, response: response)
        ])
    }

    private func cachePromptResponse(prompt: ToolPromptEvent, response: ToolPromptResponse) {
        if let index = promptResponseBatch.firstIndex(where: { $0.prompt.id == prompt.id }) {
            promptResponseBatch[index].response = response
        } else {
            promptResponseBatch.append(PromptResponseRecord(prompt: prompt, response: response))
        }
    }

    private func formatAskUserQuestionFallbackBatch(_ responses: [PromptResponseRecord]) -> String {
        var lines: [String] = []
        lines.append("AskUserQuestion tool is unavailable in this session. Ignore any prior request to use it and do not call it again.")

        for (index, record) in responses.enumerated() {
            if responses.count > 1 {
                lines.append("Prompt \(index + 1):")
            }
            lines.append(contentsOf: formatAskUserQuestionDetails(prompt: record.prompt, response: record.response))
        }

        let summaryLine = responses.count > 1
            ? "Continue directly using the answers above. If you need to present choices, list them inline and ask for a plain-text reply."
            : "Continue directly using the answer above. If you need to present choices, list them inline and ask for a plain-text reply."
        lines.append(summaryLine)
        return lines.joined(separator: "\n")
    }

    private func formatAskUserQuestionDetails(
        prompt: ToolPromptEvent,
        response: ToolPromptResponse
    ) -> [String] {
        let questionParts = [prompt.title, prompt.body]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let question = questionParts.joined(separator: " - ")

        let answer: String
        switch response {
        case .selections(let selections):
            let labels = selections.map { $0.label.isEmpty ? $0.id : $0.label }
            answer = labels.joined(separator: ", ")
        case .freeText(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            answer = trimmed.isEmpty ? "(empty)" : trimmed
        }

        var lines: [String] = []
        if !question.isEmpty {
            lines.append("Question: \(question)")
        }

        if !prompt.options.isEmpty {
            lines.append("Options:")
            for option in prompt.options {
                let desc = option.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if desc.isEmpty {
                    lines.append("- \(option.label)")
                } else {
                    lines.append("- \(option.label): \(desc)")
                }
            }
        }

        lines.append("Answer: \(answer)")
        return lines
    }

    private func completePromptSubmission(for prompt: ToolPromptEvent) async {
        promptQueue.setSubmissionState(.submitted, for: prompt.id)
        promptSubmissionState = .submitted
        promptQueue.dequeue(promptId: prompt.id)

        // Brief delay to show success state, then update to next prompt
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        updatePromptState()
    }

    private func waitForTurnToFinish() async {
        while isProcessing {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func parseMultiSelect(question: [String: Any], root: [String: Any]) -> Bool {
        if let value = parseBool(question["multiSelect"]) { return value }
        if let value = parseBool(question["multi_select"]) { return value }
        if let value = parseBool(root["multiSelect"]) { return value }
        if let value = parseBool(root["multi_select"]) { return value }
        return false
    }

    private func parseBool(_ value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "yes", "1"].contains(trimmed) { return true }
            if ["false", "no", "0"].contains(trimmed) { return false }
            return nil
        default:
            return nil
        }
    }

    private func stringValue(_ value: Any?, fallback: String?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return fallback
        }
    }

    // MARK: - File Tab Management

    /// Get the currently active file tab
    var activeFileTab: FileTab? {
        guard let activeId = activeFileTabId else { return nil }
        return openFileTabs.first { $0.id == activeId }
    }

    /// Open a file in the file viewer
    /// - Parameters:
    ///   - filePath: Path to the file to open
    ///   - asPreview: If true, opens as preview tab (will be replaced by next preview)
    func openFile(_ filePath: String, asPreview: Bool = true) {
        // Check if file is already open
        if let existingTab = openFileTabs.first(where: { $0.filePath == filePath }) {
            // Switch to existing tab
            activeFileTabId = existingTab.id

            // If opening as persistent, convert preview to persistent
            if !asPreview && existingTab.isPreview {
                if let index = openFileTabs.firstIndex(where: { $0.id == existingTab.id }) {
                    openFileTabs[index].isPreview = false
                }
            }
        } else {
            // Close any existing preview tab if opening as preview
            if asPreview {
                openFileTabs.removeAll { $0.isPreview }
            }

            // Create new tab
            let newTab = FileTab(filePath: filePath, isPreview: asPreview)
            openFileTabs.append(newTab)
            activeFileTabId = newTab.id
        }

        // Switch to files mode
        centerPaneMode = .files
    }

    /// Close a file tab
    func closeFileTab(_ tabId: UUID) {
        openFileTabs.removeAll { $0.id == tabId }

        // Clean up EditorSession for this tab
        if let session = editorSessions.removeValue(forKey: tabId) {
            session.detach()
        }

        // If we closed the active tab, select another
        if activeFileTabId == tabId {
            activeFileTabId = openFileTabs.last?.id
        }

        // If no tabs left, switch back to chat
        if openFileTabs.isEmpty {
            centerPaneMode = .chat
        }
    }

    /// Close all file tabs
    func closeAllFileTabs() {
        // Clean up all EditorSessions
        for (_, session) in editorSessions {
            session.detach()
        }
        editorSessions.removeAll()

        openFileTabs.removeAll()
        activeFileTabId = nil
        centerPaneMode = .chat
    }

    /// Get or create an EditorSession for a file tab
    func editorSession(for tab: FileTab) -> EditorSession {
        if let existing = editorSessions[tab.id] {
            return existing
        }

        // Create new session with file URL for language detection
        let fileURL = URL(fileURLWithPath: tab.filePath)
        let session = EditorSession(id: tab.id, fileURL: fileURL)
        editorSessions[tab.id] = session
        return session
    }

    /// Reorder file tabs (for drag and drop)
    func moveFileTab(from source: IndexSet, to destination: Int) {
        openFileTabs.move(fromOffsets: source, toOffset: destination)
    }

    /// Make a preview tab persistent (e.g., after editing)
    func makeTabPersistent(_ tabId: UUID) {
        if let index = openFileTabs.firstIndex(where: { $0.id == tabId }) {
            openFileTabs[index].isPreview = false
        }
    }

    /// Toggle center pane mode
    func toggleCenterPaneMode() {
        centerPaneMode = centerPaneMode == .chat ? .files : .chat
    }

    // MARK: - File Editing

    /// Mark a tab as having unsaved changes
    func markTabDirty(_ tabId: UUID, content: String, originalContent: String?) {
        guard let index = openFileTabs.firstIndex(where: { $0.id == tabId }) else { return }

        // Store original content if not already stored
        if openFileTabs[index].originalContent == nil {
            openFileTabs[index].originalContent = originalContent
        }

        // Performance: compare lengths first (O(1)) before full string comparison
        let original = openFileTabs[index].originalContent ?? ""
        let isDirty: Bool
        if content.count != original.count {
            isDirty = true  // Different lengths = definitely dirty
        } else {
            isDirty = content != original  // Same length, need full comparison
        }

        // Only update state if value changed (avoid unnecessary re-renders)
        if openFileTabs[index].isDirty != isDirty {
            openFileTabs[index].isDirty = isDirty
        }

        // Make tab persistent if it was a preview
        if isDirty && openFileTabs[index].isPreview {
            openFileTabs[index].isPreview = false
        }
    }

    /// Save file content to disk
    func saveFileTab(_ tabId: UUID, content: String) async throws {
        guard let index = openFileTabs.firstIndex(where: { $0.id == tabId }) else {
            throw FileEditorError.tabNotFound
        }

        let filePath = openFileTabs[index].filePath
        let url = URL(fileURLWithPath: filePath)

        try content.write(to: url, atomically: true, encoding: .utf8)

        // Update tab state
        await MainActor.run {
            openFileTabs[index].isDirty = false
            openFileTabs[index].originalContent = content
        }
    }

    /// Check if any tabs have unsaved changes
    var hasUnsavedChanges: Bool {
        openFileTabs.contains { $0.isDirty }
    }

    /// Get all tabs with unsaved changes
    var dirtyTabs: [FileTab] {
        openFileTabs.filter { $0.isDirty }
    }

    /// Close tab with save confirmation if dirty
    /// Returns true if tab was closed, false if user cancelled
    func closeFileTabWithConfirmation(_ tabId: UUID) -> Bool {
        guard let tab = openFileTabs.first(where: { $0.id == tabId }) else {
            return true
        }

        if tab.isDirty {
            // Caller should show confirmation dialog
            return false
        }

        closeFileTab(tabId)
        return true
    }

    // MARK: - Formatting

    /// Format the currently active document
    /// Returns a message describing the result
    @discardableResult
    func formatCurrentDocument() async -> String {
        guard let tab = activeFileTab else {
            return "No file open"
        }

        let session = editorSession(for: tab)
        return await session.formatDocument()
    }

    /// Check if formatting is available for the current file
    var canFormatCurrentDocument: Bool {
        activeFileTab != nil
    }
}

// MARK: - File Editor Error

enum FileEditorError: LocalizedError {
    case tabNotFound
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .tabNotFound:
            return "File tab not found"
        case .saveFailed(let reason):
            return "Failed to save file: \(reason)"
        }
    }
}

// MARK: - Prompt Error

enum PromptError: LocalizedError {
    case noAdapter
    case promptNotFound
    case submissionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAdapter:
            return "No engine adapter available"
        case .promptNotFound:
            return "Tool prompt not found"
        case .submissionFailed(let reason):
            return "Failed to submit response: \(reason)"
        }
    }
}

// MARK: - Bash Command Parser

/// Extract command and background flag from Bash tool input JSON
/// Input format: {"command": "ls -la", "run_in_background": false, ...}
private func extractBashCommand(from jsonInput: String) -> (command: String, isBackground: Bool) {
    guard let data = jsonInput.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return (jsonInput, false)  // Fallback to raw input
    }

    let command = json["command"] as? String ?? jsonInput
    let isBackground = json["run_in_background"] as? Bool ?? false

    return (command, isBackground)
}

// MARK: - Main Content View (handles notifications)

/// Wrapper view that handles global notifications like opening UI Gallery.
struct MainContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        ZStack {
            // Theme-aware background - uses active theme's background color
            // Falls back to Ghostty-style navy if theme has no background set
            ThemeAwareBackground()

            // Main content on top
            ContentView()
        }
        .ignoresSafeArea()
        .background(
            // Configure window for transparency
            WindowAccessor { window in
                configureLiquidGlassWindow(window)
            }
        )
        .task {
            // Register window action for menu commands to use
            // Activation policy now set at Group level in BlazeApp
            WindowActions.shared.openUIGallery = openWindow
            print("[DEBUG] Registered openUIGallery action")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openUIGallery)) { _ in
            print("[DEBUG] Received openUIGallery notification, calling openWindow")
            openWindow(id: "ui-gallery")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            openWindow(id: "settings")
        }
    }
}

/// Theme-aware background that responds to theme changes.
/// Uses the active theme's background color with subtle accent glows.
struct ThemeAwareBackground: View {
    @Environment(\.themeManager) private var themeManager
    @AppStorage("customGlassLevel") private var glassLevel: String = "regular"

    /// Opacity based on glass level setting
    private var backgroundOpacity: Double {
        switch glassLevel {
        case "subtle": return 0.95  // Almost opaque
        case "light": return 0.90
        case "regular": return 0.85
        case "prominent": return 0.75  // Most transparent
        default: return 0.85
        }
    }

    /// Current theme's background color (or fallback)
    private var backgroundColor: Color {
        themeManager?.activeTheme.colors.background ?? AmbientGradientBackground.ghosttyBackground
    }

    /// Current theme's accent color for glows
    private var accentColor: Color {
        themeManager?.activeTheme.colors.accent ?? Color(red: 0.6, green: 0.4, blue: 1.0)
    }

    var body: some View {
        ZStack {
            // Base: Theme background color
            backgroundColor
                .opacity(backgroundOpacity)

            // Subtle accent glow (top-left area) for depth
            // Color derived from theme's accent
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentColor.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 350
                    )
                )
                .frame(width: 700, height: 700)
                .offset(x: -200, y: -150)
                .blur(radius: 120)

            // Subtle secondary glow (bottom-right)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentColor.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: 300, y: 250)
                .blur(radius: 100)
        }
        .ignoresSafeArea()
    }
}

/// Background matching Ghostty terminal aesthetic.
/// Uses the same dark navy blue (#0a1020) with 80% opacity.
struct AmbientGradientBackground: View {
    // Ghostty colors from config
    static let ghosttyBackground = Color(red: 10/255, green: 16/255, blue: 32/255) // #0a1020
    static let ghosttySelection = Color(red: 36/255, green: 58/255, blue: 90/255)  // #243a5a

    var body: some View {
        ZStack {
            // Base: Ghostty's dark navy blue
            Self.ghosttyBackground

            // Subtle blue accent glow (top-left area) for depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.15, green: 0.25, blue: 0.5).opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 350
                    )
                )
                .frame(width: 700, height: 700)
                .offset(x: -200, y: -150)
                .blur(radius: 120)

            // Subtle purple accent glow (bottom-right)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.3, green: 0.15, blue: 0.45).opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: 300, y: 250)
                .blur(radius: 100)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Visual Effect View (NSVisualEffectView wrapper)

import AppKit

/// NSVisualEffectView wrapper for true macOS vibrancy/blur effects.
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Window Accessor (for Liquid Glass transparency)

/// Accesses the underlying NSWindow to configure it for Liquid Glass transparency.
/// This enables the window to be transparent so vibrancy effects blur through to the desktop.
struct WindowAccessor: NSViewRepresentable {
    let onWindowReady: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowAccessorView()
        view.onWindowReady = onWindowReady
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Configuration happens automatically in viewDidMoveToWindow
    }
}

/// Helper view that calls back when added to a window.
class WindowAccessorView: NSView {
    var onWindowReady: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = window {
            onWindowReady?(window)
        }
    }
}

/// Configures an NSWindow for Liquid Glass transparency effect.
/// Call this from WindowAccessor's onWindowReady callback.
func configureLiquidGlassWindow(_ window: NSWindow) {
    // Make window background transparent
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = true

    // Ghostty-style titlebar: transparent and integrated
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden

    // Use unified titlebar/toolbar style for compact look
    window.styleMask.insert(.fullSizeContentView)
    window.toolbar?.isVisible = false

    // Ensure the window's content view is also transparent
    window.contentView?.wantsLayer = true
    window.contentView?.layer?.backgroundColor = .clear

    // Apply saved transparency preference
    let savedTransparency = UserDefaults.standard.double(forKey: "windowTransparency")
    if savedTransparency > 0 {
        // Clamp to valid range (0.8 - 1.0)
        let clampedOpacity = max(0.8, min(1.0, savedTransparency))
        window.alphaValue = clampedOpacity
    }

    // Force window to front
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()

    // Ensure window captures keyboard input after view hierarchy is ready
    // This fixes TextField focus issues with glass windows
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Liquid Glass Background

/// Full-screen Liquid Glass background that blurs the desktop and overlays a subtle gradient tint.
/// This is the foundation for the Liquid Glass aesthetic - desktop shows through with frosted blur.
struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            // Layer 1: Vibrancy blur of desktop content (primary effect)
            VisualEffectBackground(
                material: .hudWindow,
                blendingMode: .behindWindow,
                state: .active
            )

            // Layer 2: Very subtle gradient tint (must be low opacity to see through!)
            AmbientGradientBackground()
                .opacity(0.25)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Focus-Independent Sidebar Background

/// Sidebar background - consistent with other panels for single-canvas appearance.
/// Uses same opacity as center pane to eliminate "floating" effect.
struct FocusIndependentSidebarBackground: View {
    var body: some View {
        // Matches center pane background - single canvas appearance
        Color.ds.surface.opacity(0.15)
    }
}

// MARK: - Glass Panel Background (for panels within the app)

/// Background for individual glass panels within the Liquid Glass UI.
/// Uses .withinWindow blending to blur content behind it within the app.
struct GlassPanelBackground: View {
    var opacity: Double = 0.6
    var cornerRadius: CGFloat = DSRadius.lg

    var body: some View {
        ZStack {
            // Frosted glass effect
            VisualEffectBackground(
                material: .hudWindow,
                blendingMode: .withinWindow,
                state: .active
            )

            // Subtle tint
            Color.ds.bg1.opacity(opacity * 0.3)

            // Top highlight gradient
            LinearGradient(
                colors: [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.04),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
