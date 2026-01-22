import SwiftUI

/// Main three-pane layout using custom ThreeColumnLayout (replaces NavigationSplitView)
/// This avoids macOS sidebar vibrancy that caused opacity mismatch.
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var selectedSessionId: UUID?
    @State private var terminalViewModel: TerminalPanelViewModel?

    // File tree view model - owned here, shared with ProjectListView and ChatInputView
    @State private var fileTreeViewModel: FileTreeViewModel?

    // Column sizing and visibility
    @State private var leftColumnWidth: CGFloat = 280
    @State private var rightColumnWidth: CGFloat = 300
    @State private var leftColumnVisible: Bool = true
    @State private var rightColumnVisible: Bool = true

    private var selectedSession: Session? {
        guard let id = selectedSessionId else { return nil }
        return appState.sessions.first { $0.id == id }
    }

    /// Current session's working directory (for observing worktree path changes)
    private var currentSessionWorkingDirectory: String? {
        selectedSession?.effectiveWorkingDirectory
    }

    var body: some View {
        ThreeColumnLayout(
            leftWidth: $leftColumnWidth,
            rightWidth: $rightColumnWidth,
            leftVisible: $leftColumnVisible,
            rightVisible: $rightColumnVisible,
            minLeftWidth: 200,
            maxLeftWidth: 500,   // Allow wider left panel
            minRightWidth: 250,
            maxRightWidth: 500,  // Allow wider right panel
            minCenterWidth: 350
        ) {
            // Left pane: Project-grouped session list
            ProjectListView(selectedSessionId: $selectedSessionId, fileTreeViewModel: $fileTreeViewModel)
                .background(Color.ds.surface.opacity(0.15))
        } center: {
            // Center pane: Chat/Files with toggle + Terminal panel
            // Inject FileTreeViewModel as EnvironmentObject for ChatInputView @ mentions
            // Use .id() to force view recreation when ViewModel changes
            centerPaneContent
                .environmentObject(fileTreeViewModel ?? FileTreeViewModel.empty)
                .id(fileTreeViewModel?.sessionId ?? UUID())
                .background(Color.ds.surface.opacity(0.15))
                .overlay(alignment: .top) {
                    // View mode toggle - centered at top, aligned with traffic lights
                    CenterPaneToggleCompact(mode: $appState.centerPaneMode)
                        .padding(.top, 4)  // Align vertically with traffic lights
                }
        } right: {
            // Right pane: Sidebar (20 tabs across 5 categories)
            SidebarContainer(
                sessionId: selectedSessionId,
                events: selectedSessionId.flatMap { appState.eventsForSession($0) } ?? [],
                onEventTapped: { eventId in
                    appState.scrollToEvent(eventId)
                }
            )
            .background(Color.ds.surface.opacity(0.15))
        }
        .background(.clear)
        .overlay(alignment: .topLeading) {
            // Left title bar buttons - next to traffic lights
            HStack(spacing: 12) {
                Menu {
                    Button("New Session with Directory...") {
                        appState.showNewSessionModal = true
                    }
                    Button("Quick Session (Home Directory)") {
                        appState.createQuickSession()
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ds.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("New Session")
            }
            .padding(.top, 9)      // Align vertically with traffic lights
            .padding(.leading, 78) // Clear traffic light buttons (~70px + margin)
        }
        .overlay(alignment: .topTrailing) {
            // Title bar buttons - parallel to traffic lights, RIGHT side
            HStack(spacing: 20) {
                // Community Links
                HStack(spacing: 12) {
                    Link(destination: URL(string: "https://github.com/cogit0/blaze")!) {
                        GitHubLogo()
                            .fill(Color.ds.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help("View on GitHub")

                    Link(destination: URL(string: "https://discord.gg/CPeRTcGXm6")!) {
                        DiscordLogo()
                            .fill(Color.ds.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help("Join Discord")
                }
                .padding(.trailing, 8)

                // Column visibility toggles
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            leftColumnVisible.toggle()
                        }
                    } label: {
                        Image(systemName: leftColumnVisible ? "sidebar.left" : "sidebar.left")
                            .font(.system(size: 13))
                            .foregroundStyle(leftColumnVisible ? Color.ds.foreground : Color.ds.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(leftColumnVisible ? "Hide sidebar" : "Show sidebar")

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            rightColumnVisible.toggle()
                        }
                    } label: {
                        Image(systemName: rightColumnVisible ? "sidebar.right" : "sidebar.right")
                            .font(.system(size: 13))
                            .foregroundStyle(rightColumnVisible ? Color.ds.foreground : Color.ds.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(rightColumnVisible ? "Hide inspector" : "Show inspector")
                }

                // Search and Settings buttons
                HStack(spacing: 12) {
                    Button {
                        // TODO: Universal search action
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.ds.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Search (⌘K)")

                    Button {
                        openWindow(id: "settings")
                    } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.ds.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
            }
            .padding(.top, 6)  // Align with traffic lights
            .padding(.trailing, 12)
        }
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: selectedSessionId) { _, newValue in
            appState.currentSessionId = newValue
            updateTerminalViewModel(for: newValue)
            updateFileTreeViewModel(for: newValue)
        }
        .onChange(of: currentSessionWorkingDirectory) { _, _ in
            // Re-check file tree when worktree path changes (e.g., after worktree creation)
            updateFileTreeViewModel(for: selectedSessionId)
        }
        .onAppear {
            // Select first session if available
            if selectedSessionId == nil, let first = appState.sessions.first {
                selectedSessionId = first.id
            }
            updateTerminalViewModel(for: selectedSessionId)
            updateFileTreeViewModel(for: selectedSessionId)
        }
    }

    // MARK: - File Tree ViewModel Management

    private func updateFileTreeViewModel(for sessionId: UUID?) {
        guard let sessionId,
              let session = appState.sessions.first(where: { $0.id == sessionId }),
              let workingDir = session.effectiveWorkingDirectory else {
            fileTreeViewModel = nil
            return
        }

        // Create new view model if session changed, we don't have one, or rootURL changed
        let currentRootPath = fileTreeViewModel?.rootURL.path
        if fileTreeViewModel?.sessionId != sessionId || currentRootPath != workingDir {
            let rootURL = URL(fileURLWithPath: workingDir)
            let vm = FileTreeViewModel(sessionId: sessionId, rootURL: rootURL)
            fileTreeViewModel = vm

            // Load the tree asynchronously
            Task {
                await vm.loadTree()
            }
        }
    }

    // MARK: - Center Pane Content

    @ViewBuilder
    private var centerPaneContent: some View {
        if let terminalVM = terminalViewModel {
            TerminalPanelContainer(terminalViewModel: terminalVM) {
                chatAndFilesContent
            }
        } else {
            chatAndFilesContent
        }
    }

    @ViewBuilder
    private var chatAndFilesContent: some View {
        VStack(spacing: 0) {
            // Toggle bar at top - DEBUG: red border
            CenterPaneHeader(
                mode: $appState.centerPaneMode,
                hasOpenFiles: !appState.openFileTabs.isEmpty,
                sessionName: selectedSession?.name
            )

            // Content based on mode
            Group {
                if let session = selectedSession, let ftvm = fileTreeViewModel {
                    switch appState.centerPaneMode {
                    case .chat:
                        ChatTimelineView(session: session)
                            .environmentObject(ftvm)
                            .clipped()

                    case .files:
                        FileViewerView()

                    case .split:
                        // Split view: Chat on left, Files on right
                        HSplitView {
                            ChatTimelineView(session: session)
                                .environmentObject(ftvm)
                                .frame(minWidth: 300)
                                .clipped()  // Hard boundary - prevents text bleeding
                                .contentShape(Rectangle())  // Clip interaction area too

                            FileViewerView()
                                .frame(minWidth: 300)
                        }
                    }
                } else if selectedSession != nil {
                    // Session selected but FileTreeViewModel not ready yet - show loading state
                    // IMPORTANT: Don't pass empty FileTreeViewModel to ChatTimelineView!
                    // This causes a race condition where file clicks fail during the brief window
                    // before the real FileTreeViewModel is created.
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading project...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptySessionView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    // MARK: - Terminal ViewModel Management

    private func updateTerminalViewModel(for sessionId: UUID?) {
        guard let sessionId,
              let session = appState.sessions.first(where: { $0.id == sessionId }) else {
            terminalViewModel = nil
            return
        }

        // Create new view model if nil or session changed (old VM keeps stale workingDirectory)
        if terminalViewModel == nil || terminalViewModel?.sessionId != sessionId {
            let workingDir = URL(fileURLWithPath: session.effectiveWorkingDirectory ?? NSHomeDirectory())
            let vm = TerminalPanelViewModel(
                terminalManager: appState.terminalManager,
                sessionId: sessionId,
                workingDirectory: workingDir
            )
            vm.show()  // Show terminal panel by default

            // Create an initial terminal tab so the panel isn't empty
            Task {
                await vm.createNewTerminal()
            }
            terminalViewModel = vm
        }
    }
}

// MARK: - Center Pane Header

/// Header bar for the center pane with breadcrumb (toggle moved to title bar)
struct CenterPaneHeader: View {
    @Binding var mode: CenterPaneMode
    let hasOpenFiles: Bool
    let sessionName: String?

    var body: some View {
        HStack(spacing: 12) {
            // Session/file name (toggle is now in title bar overlay)
            if let name = sessionName {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.ds.foreground)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 32)
        .background(Color.clear)  // Unified with side panels (background applied at panel level)
    }
}

// MARK: - Session List Views

struct SessionListView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedSessionId: UUID?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSessionId) {
                Section("Sessions") {
                    ForEach(appState.sessions.sorted { $0.createdAt > $1.createdAt }) { session in
                        SessionRowView(session: session)
                            .tag(session.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(.clear)

            // Bottom toolbar with icons
            HStack(spacing: DSSpacing.md) {
                Button {
                    openWindow(id: "settings")
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ds.secondary)
                .help("Settings")

                Button {
                    // Toggle sidebar visibility or other action
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ds.secondary)
                .help("Toggle Sidebar")

                Button {
                    // Help action
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ds.secondary)
                .help("Help")

                Spacer()
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .background(Color.ds.border.opacity(0.1))
        }
        .toolbar {
            ToolbarItem {
                Button(action: { appState.createNewSession() }) {
                    Image(systemName: "plus")
                }
                .help("New Session")
            }
        }
    }
}

// SessionRowView is defined in UI/ProjectListView.swift

// MARK: - Empty State

struct EmptySessionView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        EmptyState(
            icon: "bubble.left.and.bubble.right",
            title: "No Session Selected",
            description: "Select a session from the sidebar or create a new one",
            actionTitle: "New Session"
        ) {
            appState.createNewSession()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // Transparent background to show Liquid Glass gradient
            Color.clear
        )
    }
}

struct SidebarView: View {
    let sessionId: UUID?
    var onScrollToEvent: ((UUID) -> Void)?
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SidebarTab = .timeline

    enum SidebarTab: String, CaseIterable {
        case timeline = "Timeline"
        case tools = "Tools"
        case context = "Context"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DSSpacing.md)
            .padding(.top, 40)  // Title bar clearance
            .padding(.bottom, DSSpacing.sm)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .timeline:
                    TimelineSidebarView(
                        sessionId: sessionId,
                        events: sessionEvents,
                        onEventTapped: { eventId in
                            onScrollToEvent?(eventId)
                        }
                    )
                case .tools:
                    ToolsSidebarView(sessionId: sessionId, events: sessionEvents)
                case .context:
                    ContextSidebarView(sessionId: sessionId, events: sessionEvents)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.clear)  // Background applied at ContentView level
    }

    private var sessionEvents: [EventEnvelope] {
        guard let sessionId else { return [] }
        return appState.eventsForSession(sessionId)
    }
}

// ToolsSidebarView, ToolEventRow, ContextSidebarView, and TokenUsageRow
// are defined in UI/Sidebar/ directory

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            EngineSettingsView()
                .tabItem {
                    Label("Engines", systemImage: "cpu")
                }

            PolicySettingsView()
                .tabItem {
                    Label("Policies", systemImage: "shield")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("defaultProjectPath") private var defaultProjectPath: String = ""
    @AppStorage("autoCreateSession") private var autoCreateSession: Bool = true

    var body: some View {
        Form {
            Section("Project") {
                TextField("Default Project Path", text: $defaultProjectPath)
                    .textFieldStyle(.roundedBorder)
                Toggle("Create session on launch", isOn: $autoCreateSession)
            }

            Section("Appearance") {
                Text("Theme settings coming in future update")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct EngineSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Available Engines") {
                ForEach(EngineType.allCases, id: \.self) { engine in
                    EngineRow(
                        engine: engine,
                        info: appState.engineManager.availableEngines[engine]
                    )
                }
            }

            Section {
                Button("Refresh Engine Status") {
                    Task {
                        await appState.engineManager.validateAll()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct EngineRow: View {
    let engine: EngineType
    let info: CLIInfo?

    var body: some View {
        HStack {
            Image(systemName: engine.icon)
                .frame(width: 24)
                .foregroundStyle(info != nil ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(engine.rawValue)
                    .fontWeight(.medium)

                if let info {
                    Text("v\(info.version) • \(info.path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not installed")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if info != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PolicySettingsView: View {
    @AppStorage("trustMode") private var trustMode: String = TrustMode.review.rawValue

    var body: some View {
        Form {
            Section("Trust Mode") {
                Picker("Mode", selection: $trustMode) {
                    ForEach(TrustMode.allCases, id: \.rawValue) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Tool Permissions") {
                Text("Fine-grained tool permissions coming in future update")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
