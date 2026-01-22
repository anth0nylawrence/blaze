import SwiftUI

// MARK: - Sidebar Container

/// Main sidebar container with collapsible category groups
/// Supports 20 tabs across 5 categories with keyboard navigation (Cmd+1-9)
struct SidebarContainer: View {
    let sessionId: UUID?
    let events: [EventEnvelope]
    var onEventTapped: ((UUID) -> Void)?

    @State private var selectedTab: SidebarTab = .timeline
    @State private var expandedCategories: Set<SidebarCategory> = Set(SidebarCategory.allCases)
    @State private var searchText: String = ""
    @State private var categoryListHeight: CGFloat = 200
    @State private var isDraggingDivider: Bool = false

    private let minCategoryHeight: CGFloat = 80
    private let maxCategoryHeight: CGFloat = 600  // Allow much lower

    var body: some View {
        VStack(spacing: 0) {
            // Fixed spacer to clear title bar buttons (doesn't scroll)
            Spacer()
                .frame(height: 40)

            // Search bar (optional)
            if showSearch {
                searchBar
            }

            // Category groups with tabs (resizable height)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(SidebarCategory.allCases) { category in
                        SidebarCategoryView(
                            category: category,
                            isExpanded: expandedCategories.contains(category),
                            selectedTab: $selectedTab,
                            onToggle: {
                                toggleCategory(category)
                            }
                        )
                    }
                }
                .padding(.vertical, DSSpacing.xs)
            }
            .frame(height: categoryListHeight)

            // Resizable horizontal divider
            ResizableHorizontalDivider(
                isDragging: $isDraggingDivider,
                onDrag: { delta in
                    let newHeight = categoryListHeight + delta
                    categoryListHeight = min(max(newHeight, minCategoryHeight), maxCategoryHeight)
                }
            )

            // Selected tab content
            selectedTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .background(Color.clear)
        .clipped()
        // Keyboard shortcuts for quick tab switching
        .onKeyPress(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]) { keyPress in
            if keyPress.modifiers.contains(.command) {
                if let index = Int(keyPress.characters), index > 0, index <= SidebarTab.allCases.count {
                    selectedTab = SidebarTab.allCases[index - 1]
                    return .handled
                }
            }
            return .ignored
        }
    }

    // MARK: - Search Bar

    private var showSearch: Bool {
        selectedTab == .search
    }

    private var searchBar: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Color.ds.tertiary)

            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(Color.ds.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        // Activity category
        case .timeline:
            TimelineSidebarView(
                sessionId: sessionId,
                events: events,
                onEventTapped: onEventTapped
            )
        case .tools:
            ToolsSidebarView(sessionId: sessionId, events: events)
        case .tasks:
            TasksSidebarView(sessionId: sessionId, events: events)

        // Files & Code category
        case .files:
            FilesSidebarView(
                sessionId: sessionId,
                events: events
            )
        case .git:
            GitSidebarView(sessionId: sessionId)
        case .search:
            SearchSidebarView(
                sessionId: sessionId,
                events: events
            )
        case .bookmarks:
            BookmarksSidebarView(
                sessionId: sessionId,
                events: events
            )

        // Context category
        case .tokens:
            TokensSidebarView(sessionId: sessionId, events: events)
        case .mcp:
            MCPSidebarView(sessionId: sessionId)
        case .hooks:
            HooksSidebarView(sessionId: sessionId)
        case .policies:
            PlaceholderSidebarView(
                icon: "shield",
                title: "Policies",
                description: "Security and approval policies"
            )

        // System category
        case .engines:
            PlaceholderSidebarView(
                icon: "cpu",
                title: "Engines",
                description: "Available AI engines"
            )
        case .logs:
            LogsSidebarView(sessionId: sessionId)
        case .performance:
            PlaceholderSidebarView(
                icon: "gauge",
                title: "Performance",
                description: "Performance metrics"
            )

        // Nav category
        case .sessions:
            SessionsSidebarView(sessionId: sessionId)
        case .prompts:
            PromptsSidebarView(sessionId: sessionId)
        case .agents:
            AgentsSidebarView(sessionId: sessionId)
        case .approvals:
            ApprovalsSidebarView(sessionId: sessionId)
        case .contextWindow:
            EnhancedContextSidebarView(sessionId: sessionId, events: events)
        case .settings:
            SettingsSidebarView(sessionId: sessionId)
        }
    }

    // MARK: - Helpers

    private func toggleCategory(_ category: SidebarCategory) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedCategories.contains(category) {
                expandedCategories.remove(category)
            } else {
                expandedCategories.insert(category)
            }
        }
    }
}

// MARK: - Sidebar Categories

/// Categories for grouping sidebar tabs
enum SidebarCategory: String, CaseIterable, Identifiable {
    case activity = "Activity"
    case filesCode = "Files & Code"
    case context = "Context"
    case system = "System"
    case nav = "Nav"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .activity: return "waveform"
        case .filesCode: return "folder"
        case .context: return "brain"
        case .system: return "gearshape.2"
        case .nav: return "sidebar.squares.left"
        }
    }

    var tabs: [SidebarTab] {
        switch self {
        case .activity:
            return [.timeline, .tools, .tasks]
        case .filesCode:
            return [.files, .git, .search, .bookmarks]
        case .context:
            return [.tokens, .mcp, .hooks, .policies]
        case .system:
            return [.engines, .logs, .performance]
        case .nav:
            return [.sessions, .prompts, .agents, .approvals, .contextWindow, .settings]
        }
    }
}

// MARK: - Sidebar Tabs

/// All available sidebar tabs (20 total across 5 categories)
enum SidebarTab: String, CaseIterable, Identifiable {
    // Activity (3)
    case timeline = "Timeline"
    case tools = "Tools"
    case tasks = "Tasks"

    // Files & Code (4)
    case files = "Files"
    case git = "Git"
    case search = "Search"
    case bookmarks = "Bookmarks"

    // Context (4)
    case tokens = "Tokens"
    case mcp = "MCP"
    case hooks = "Hooks"
    case policies = "Policies"

    // System (3)
    case engines = "Engines"
    case logs = "Logs"
    case performance = "Performance"

    // Nav (6)
    case sessions = "Sessions"
    case prompts = "Prompts"
    case agents = "Agents"
    case approvals = "Approvals"
    case contextWindow = "Context"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .timeline: return "timeline.selection"
        case .tools: return "wrench.and.screwdriver"
        case .tasks: return "checklist"
        case .files: return "doc.text"
        case .git: return "arrow.triangle.branch"
        case .search: return "magnifyingglass"
        case .bookmarks: return "bookmark"
        case .tokens: return "chart.bar.fill"
        case .mcp: return "server.rack"
        case .hooks: return "gearshape.2.fill"
        case .policies: return "shield"
        case .engines: return "cpu"
        case .logs: return "doc.text.fill"
        case .performance: return "gauge"
        case .sessions: return "rectangle.stack.fill"
        case .prompts: return "text.quote"
        case .agents: return "person.3.fill"
        case .approvals: return "checkmark.shield.fill"
        case .contextWindow: return "doc.text.magnifyingglass"
        case .settings: return "gearshape.fill"
        }
    }

    /// Keyboard shortcut number (1-9 for first 9 tabs)
    var shortcutNumber: Int? {
        guard let index = SidebarTab.allCases.firstIndex(of: self), index < 9 else {
            return nil
        }
        return index + 1
    }
}

// MARK: - Placeholder Sidebar View

/// Placeholder view for tabs not yet implemented
struct PlaceholderSidebarView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(Color.ds.tertiary)

            Text(title)
                .dsTextStyle(.subtitle)

            Text(description)
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)

            Text("Coming Soon")
                .dsTextStyle(.micro, color: .ds.tertiary)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xxs)
                .background(Color.ds.surface.opacity(0.5))
                .clipShape(Capsule())
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ContextSidebarView (moved from ContentView)

/// Context sidebar showing token usage and session metadata
struct ContextSidebarView: View {
    let sessionId: UUID?
    let events: [EventEnvelope]

    private var latestTokenUsage: TokenUsage? {
        for envelope in events.reversed() {
            if case .tokenUsage(let usage) = envelope.event {
                return usage
            }
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                // Token usage section
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Label("Token Usage", systemImage: "number")
                        .dsTextStyle(.caption, color: .ds.secondary)

                    if let usage = latestTokenUsage {
                        TokenUsageRow(label: "Input", value: usage.inputTokens)
                        TokenUsageRow(label: "Output", value: usage.outputTokens)
                        if let cacheRead = usage.cacheReadTokens {
                            TokenUsageRow(label: "Cache Read", value: cacheRead)
                        }
                        Divider()
                        TokenUsageRow(label: "Total", value: usage.totalTokens, bold: true)
                    } else {
                        Text("No usage data")
                            .dsTextStyle(.caption, color: .ds.tertiary)
                    }
                }
                .padding(DSSpacing.md)
                .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.lg, elevation: .low)

                Spacer()
            }
            .padding(DSSpacing.md)
        }
    }
}

/// Row showing a token count
struct TokenUsageRow: View {
    let label: String
    let value: Int
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .dsTextStyle(bold ? .body : .caption, color: bold ? .ds.foreground : .ds.secondary)
            Spacer()
            Text(formatTokens(value))
                .dsTextStyle(.monoSmall, color: bold ? .ds.foreground : .ds.secondary)
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Resizable Horizontal Divider

/// Draggable horizontal divider for resizing vertical sections
struct ResizableHorizontalDivider: View {
    @Binding var isDragging: Bool
    let onDrag: (CGFloat) -> Void

    @State private var isHovered = false
    @State private var lastDragY: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Divider line
            Rectangle()
                .fill(Color(.separatorColor).opacity(0.5))
                .frame(height: 1)

            // Grab handle area
            ZStack {
                // Background
                Color.clear

                // Visual grab indicator (three horizontal lines)
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(isHovered || isDragging ? Color.accentColor : Color(.separatorColor).opacity(0.6))
                            .frame(width: 16, height: 2)
                    }
                }
            }
            .frame(height: 10)
        }
        .frame(height: 11)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.resizeUpDown.push()
            } else if !isDragging {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        lastDragY = value.location.y
                    } else {
                        let delta = value.location.y - lastDragY
                        lastDragY = value.location.y
                        onDrag(delta)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    lastDragY = 0
                    if !isHovered {
                        NSCursor.pop()
                    }
                }
        )
    }
}

// MARK: - Previews

#Preview("Sidebar Container") {
    SidebarContainer(
        sessionId: UUID(),
        events: []
    )
    .frame(width: 300, height: 600)
    .background(Color.ds.bg0)
}

#Preview("Placeholder Tab") {
    PlaceholderSidebarView(
        icon: "arrow.triangle.branch",
        title: "Git",
        description: "Branch and commit information will appear here"
    )
    .frame(width: 280, height: 300)
    .background(Color.ds.bg0)
}
