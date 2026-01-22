import SwiftUI

// MARK: - Hooks Sidebar View

/// Tab 10: Hooks sidebar showing registered automation hooks and their status.
///
/// **Phase 2 Spec:**
/// - List hooks from settings
/// - Show: Event type (PreToolUse, PostToolUse, etc.), matcher pattern, last run status
/// - Actions: Enable/Disable toggle, View last output
/// - Status: Success (green) / Failed (red) / Never run (gray)
struct HooksSidebarView: View {
    let sessionId: UUID?

    @EnvironmentObject var appState: AppState
    @State private var hooks: [HookInfo] = []
    @State private var isLoading: Bool = false
    @State private var error: String?
    @State private var expandedHooks: Set<UUID> = []

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Hook list
            if isLoading {
                loadingView
            } else if let error {
                errorView(error)
            } else if hooks.isEmpty {
                emptyView
            } else {
                hookListView
            }
        }
        .task {
            await loadHooks()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Label("Automation Hooks", systemImage: "gearshape.2.fill")
                .dsTextStyle(.caption, color: .ds.secondary)

            Spacer()

            // Status summary
            if !hooks.isEmpty {
                let activeCount = hooks.filter { $0.isEnabled }.count
                Text("\(activeCount) active")
                    .dsTextStyle(.micro, color: .ds.tertiary)
            }

            // Refresh button
            Button {
                Task {
                    await loadHooks()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ds.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Loading hooks...")
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.warning)

            Text("Failed to Load")
                .dsTextStyle(.subtitle)

            Text(message)
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await loadHooks()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("No Hooks Configured")
                .dsTextStyle(.subtitle)

            Text("Add hooks to settings.json to automate actions on events like PreToolUse, PostToolUse, etc.")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)

            Button {
                // Open hooks documentation
                if let url = URL(string: "https://docs.anthropic.com/en/docs/claude-code/hooks") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Learn More", systemImage: "book")
            }
            .buttonStyle(.bordered)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hook List View

    private var hookListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Group by event type
                ForEach(SidebarHookEventType.allCases, id: \.self) { eventType in
                    let eventHooks = hooks.filter { $0.eventType == eventType }
                    if !eventHooks.isEmpty {
                        hookSection(for: eventType, hooks: eventHooks)
                    }
                }
            }
            .padding(.vertical, DSSpacing.xs)
        }
    }

    private func hookSection(for eventType: SidebarHookEventType, hooks: [HookInfo]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: eventType.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(eventType.color)

                Text(eventType.rawValue)
                    .dsTextStyle(.caption, color: .ds.secondary)
                    .fontWeight(.medium)

                Text("(\(hooks.count))")
                    .dsTextStyle(.micro, color: .ds.tertiary)

                Spacer()
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(Color.ds.surface.opacity(0.2))

            // Hooks in this section
            ForEach(hooks) { hook in
                HookRow(
                    hook: hook,
                    isExpanded: expandedHooks.contains(hook.id),
                    onToggle: {
                        toggleHook(hook.id)
                    },
                    onEnableToggle: {
                        toggleHookEnabled(hook.id)
                    },
                    onViewOutput: {
                        viewHookOutput(hook.id)
                    }
                )

                if hook.id != hooks.last?.id {
                    Divider()
                        .padding(.leading, DSSpacing.lg + DSSpacing.sm)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleHook(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedHooks.contains(id) {
                expandedHooks.remove(id)
            } else {
                expandedHooks.insert(id)
            }
        }
    }

    private func toggleHookEnabled(_ id: UUID) {
        if let index = hooks.firstIndex(where: { $0.id == id }) {
            hooks[index].isEnabled.toggle()
        }
    }

    private func viewHookOutput(_ id: UUID) {
        // TODO: Show last output in a sheet or popover
        print("[Hooks] View output for hook: \(id)")
    }

    // MARK: - Load Hooks

    private func loadHooks() async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        // Try to read hooks from settings.json
        guard let session = appState.sessions.first(where: { $0.id == sessionId }),
              let projectPath = session.effectiveWorkingDirectory else {
            // No project path, show empty state
            hooks = []
            return
        }

        let settingsPath = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")

        // Check if settings.json exists
        guard FileManager.default.fileExists(atPath: settingsPath.path) else {
            // No settings file, generate demo data
            hooks = generateDemoHooks()
            return
        }

        do {
            let data = try Data(contentsOf: settingsPath)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let hooksConfig = json["hooks"] as? [String: Any] {
                hooks = await parseHooks(from: hooksConfig)
            } else {
                hooks = []
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func parseHooks(from config: [String: Any]) async -> [HookInfo] {
        var result: [HookInfo] = []

        for (eventName, eventConfig) in config {
            guard let eventType = SidebarHookEventType(rawValue: eventName),
                  let hookArray = eventConfig as? [[String: Any]] else {
                continue
            }

            for hookConfig in hookArray {
                let matcher = hookConfig["matcher"] as? [String] ?? []
                let hooksList = hookConfig["hooks"] as? [[String: Any]] ?? []

                for hook in hooksList {
                    let command = hook["command"] as? String ?? "unknown"

                    // Create hook ID from command (normalized path)
                    let hookId = normalizeHookId(command: command)

                    // Fetch execution history if available
                    var lastRunStatus: SidebarHookRunStatus = .neverRun
                    var lastRunOutput: String?
                    var lastRunTime: Date?

                    if let store = appState.hookExecutionStore,
                       let currentSessionId = sessionId {
                        if let execution = try? await store.getLatestExecution(
                            hookId: hookId,
                            sessionId: currentSessionId
                        ) {
                            // Map execution status to sidebar status
                            lastRunStatus = mapStatus(execution.status)
                            lastRunOutput = execution.stdout ?? execution.stderr
                            lastRunTime = execution.endedAt ?? execution.startedAt
                        }
                    }

                    result.append(HookInfo(
                        eventType: eventType,
                        matcher: matcher,
                        command: command,
                        isEnabled: true,
                        lastRunStatus: lastRunStatus,
                        lastRunOutput: lastRunOutput,
                        lastRunTime: lastRunTime
                    ))
                }
            }
        }

        return result
    }

    /// Normalize hook command to create a stable hook ID
    private func normalizeHookId(command: String) -> String {
        // Extract filename from path for stable ID
        let filename = (command as NSString).lastPathComponent
        return filename
    }

    /// Map HookExecutionStatus to SidebarHookRunStatus
    private func mapStatus(_ status: HookExecutionStatus) -> SidebarHookRunStatus {
        switch status {
        case .success: return .success
        case .failed, .timeout: return .failed
        case .running: return .success // Treat running as success for now
        }
    }

    private func generateDemoHooks() -> [HookInfo] {
        [
            HookInfo(
                eventType: .sessionStart,
                matcher: [],
                command: "$CLAUDE_PROJECT_DIR/.claude/hooks/session-start-continuity.sh",
                isEnabled: true,
                lastRunStatus: .success,
                lastRunOutput: "Loaded continuity ledger from CONTINUITY_CLAUDE-main.md",
                lastRunTime: Date().addingTimeInterval(-300)
            ),
            HookInfo(
                eventType: .preToolUse,
                matcher: ["Write", "Edit"],
                command: "$CLAUDE_PROJECT_DIR/.claude/hooks/pre-write-guard.sh",
                isEnabled: true,
                lastRunStatus: .success,
                lastRunOutput: nil,
                lastRunTime: Date().addingTimeInterval(-120)
            ),
            HookInfo(
                eventType: .postToolUse,
                matcher: ["Write"],
                command: "$CLAUDE_PROJECT_DIR/.claude/hooks/post-write-index.sh",
                isEnabled: false,
                lastRunStatus: .failed,
                lastRunOutput: "Error: Index database not found",
                lastRunTime: Date().addingTimeInterval(-3600)
            ),
            HookInfo(
                eventType: .stop,
                matcher: [],
                command: "$CLAUDE_PROJECT_DIR/.claude/hooks/session-end.sh",
                isEnabled: true,
                lastRunStatus: .neverRun,
                lastRunOutput: nil,
                lastRunTime: nil
            )
        ]
    }
}

// MARK: - Hook Info

struct HookInfo: Identifiable {
    let id = UUID()
    let eventType: SidebarHookEventType
    let matcher: [String]
    let command: String
    var isEnabled: Bool
    var lastRunStatus: SidebarHookRunStatus
    var lastRunOutput: String?
    var lastRunTime: Date?
}

/// Hook event types for sidebar display (distinct from HookStore.HookEventType)
enum SidebarHookEventType: String, CaseIterable {
    case sessionStart = "SessionStart"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case userPromptSubmit = "UserPromptSubmit"
    case preCompact = "PreCompact"
    case stop = "Stop"

    var icon: String {
        switch self {
        case .sessionStart: return "play.circle"
        case .preToolUse: return "arrow.right.to.line"
        case .postToolUse: return "arrow.left.to.line"
        case .userPromptSubmit: return "text.bubble"
        case .preCompact: return "arrow.down.right.and.arrow.up.left"
        case .stop: return "stop.circle"
        }
    }

    var color: Color {
        switch self {
        case .sessionStart: return .ds.positive
        case .preToolUse: return .ds.info
        case .postToolUse: return .ds.accent
        case .userPromptSubmit: return .ds.warning
        case .preCompact: return .purple
        case .stop: return .ds.negative
        }
    }
}

/// Hook run status for sidebar display
enum SidebarHookRunStatus {
    case success
    case failed
    case neverRun

    var color: Color {
        switch self {
        case .success: return .ds.positive
        case .failed: return .ds.negative
        case .neverRun: return .ds.tertiary
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .neverRun: return "circle"
        }
    }

    var label: String {
        switch self {
        case .success: return "Success"
        case .failed: return "Failed"
        case .neverRun: return "Never run"
        }
    }
}

// MARK: - Hook Row

struct HookRow: View {
    let hook: HookInfo
    let isExpanded: Bool
    let onToggle: () -> Void
    let onEnableToggle: () -> Void
    let onViewOutput: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button(action: onToggle) {
                HStack(spacing: DSSpacing.sm) {
                    // Enable toggle
                    Toggle("", isOn: Binding(
                        get: { hook.isEnabled },
                        set: { _ in onEnableToggle() }
                    ))
                    .toggleStyle(.switch)
                    .scaleEffect(0.6)
                    .frame(width: 32)

                    // Status indicator
                    Image(systemName: hook.lastRunStatus.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(hook.lastRunStatus.color)
                        .frame(width: 16)

                    // Hook info
                    VStack(alignment: .leading, spacing: 2) {
                        // Command (abbreviated)
                        Text(abbreviatedCommand)
                            .dsTextStyle(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        // Matcher
                        if !hook.matcher.isEmpty {
                            Text("Matches: \(hook.matcher.joined(separator: ", "))")
                                .dsTextStyle(.micro, color: .ds.tertiary)
                        }
                    }

                    Spacer()

                    // Last run time
                    if let lastRun = hook.lastRunTime {
                        Text(formatRelativeTime(lastRun))
                            .dsTextStyle(.micro, color: .ds.tertiary)
                    }

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
            }
            .buttonStyle(.plain)
            .background(isHovered ? Color.ds.surface.opacity(0.3) : Color.clear)
            .onHover { isHovered = $0 }

            // Expanded details
            if isExpanded {
                expandedContent
            }
        }
    }

    private var abbreviatedCommand: String {
        let command = hook.command
        if command.contains("/") {
            return (command as NSString).lastPathComponent
        }
        return command
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            // Full command
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("Command")
                    .dsTextStyle(.micro, color: .ds.tertiary)

                Text(hook.command)
                    .dsTextStyle(.monoSmall)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }

            // Last run output (if available)
            if let output = hook.lastRunOutput {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    HStack {
                        Text("Last Output")
                            .dsTextStyle(.micro, color: .ds.tertiary)

                        Spacer()

                        Button {
                            onViewOutput()
                        } label: {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.ds.tertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(output)
                        .dsTextStyle(.monoSmall, color: hook.lastRunStatus == .failed ? .ds.negative : .ds.foreground)
                        .lineLimit(4)
                        .padding(DSSpacing.xs)
                        .background(Color.ds.surface.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                }
            }

            // Status badge
            HStack(spacing: DSSpacing.xs) {
                Circle()
                    .fill(hook.lastRunStatus.color)
                    .frame(width: 6, height: 6)

                Text(hook.lastRunStatus.label)
                    .dsTextStyle(.micro, color: hook.lastRunStatus.color)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.leading, DSSpacing.lg)
        .padding(.bottom, DSSpacing.sm)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        ))
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Previews

#Preview("Hooks Sidebar") {
    HooksSidebarView(sessionId: UUID())
        .environmentObject(AppState())
        .frame(width: 280, height: 600)
        .background(Color.ds.bg0)
}

#Preview("Hooks Sidebar - Empty") {
    HooksSidebarView(sessionId: nil)
        .environmentObject(AppState())
        .frame(width: 280, height: 400)
        .background(Color.ds.bg0)
}
