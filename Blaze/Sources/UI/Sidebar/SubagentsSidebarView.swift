import SwiftUI

// MARK: - Subagents Sidebar View

/// Tab for Subagent management: Running/Queued subagents with drag-drop queue reordering
///
/// **Atoms Implemented:**
/// - E002-F003-S001-T003-A001: Create SubagentsSidebarView with running/queued sections
/// - E002-F003-S001-T004-A001: Add drag-drop queue reordering
///
/// **Features:**
/// - Running agents section (shows N/maxConcurrent)
/// - Queued agents section (drag-drop reordering)
/// - Visual status indicators (queued/running/completed/failed/cancelled)
/// - Token usage progress bars
/// - Subagent type icons
struct SubagentsSidebarView: View {
    let sessionId: UUID?
    let maxConcurrent: Int

    @EnvironmentObject var appState: AppState
    @State private var runningAgents: [SubagentCorrelation] = []
    @State private var queuedAgents: [SubagentCorrelation] = []
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            if isLoading {
                loadingView
            } else if runningAgents.isEmpty && queuedAgents.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .task {
            await loadSubagents()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Label("Subagents", systemImage: "cpu.fill")
                .dsTextStyle(.caption, color: .ds.secondary)

            Spacer()

            // Running count indicator
            if !runningAgents.isEmpty {
                HStack(spacing: DSSpacing.xxs) {
                    Circle()
                        .fill(Color.ds.positive)
                        .frame(width: 6, height: 6)
                    Text("\(runningAgents.count)/\(maxConcurrent)")
                        .dsTextStyle(.micro, color: .ds.positive)
                }
            }

            // Refresh button
            Button {
                Task {
                    await loadSubagents()
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

            Text("Loading subagents...")
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "cpu")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("No Active Subagents")
                .dsTextStyle(.subtitle)

            Text("Subagents will appear here when spawned by the main agent")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                // Running section
                if !runningAgents.isEmpty {
                    runningSectionView
                }

                if !runningAgents.isEmpty && !queuedAgents.isEmpty {
                    Divider()
                        .padding(.vertical, DSSpacing.xs)
                }

                // Queued section (draggable)
                if !queuedAgents.isEmpty {
                    queuedSectionView
                }
            }
            .padding(DSSpacing.sm)
        }
    }

    // MARK: - Running Section

    private var runningSectionView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // Section header
            Text("Running (\(runningAgents.count)/\(maxConcurrent))")
                .dsTextStyle(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.ds.secondary)

            // Running agents list
            ForEach(runningAgents, id: \.internalId) { agent in
                SubagentCard(correlation: agent)
            }
        }
    }

    // MARK: - Queued Section

    private var queuedSectionView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // Section header with drag hint
            HStack {
                Text("Queued (\(queuedAgents.count))")
                    .dsTextStyle(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.ds.secondary)

                Spacer()

                Text("Drag to reorder")
                    .dsTextStyle(.micro, color: .ds.tertiary)
            }

            // Queued agents list (draggable)
            ForEach(queuedAgents, id: \.internalId) { agent in
                SubagentCard(correlation: agent)
                    .draggable(agent.internalId.uuidString)
            }
            .onMove(perform: moveQueuedAgents)
        }
    }

    // MARK: - Actions

    private func loadSubagents() async {
        isLoading = true
        defer { isLoading = false }

        // TODO: Load from SubagentRegistry via appState
        // For now, generate demo data
        let demo = generateDemoSubagents()
        runningAgents = demo.filter { $0.status == .running }
        queuedAgents = demo.filter { $0.status == .queued }
            .sorted { ($0.queuePosition ?? Int.max) < ($1.queuePosition ?? Int.max) }
    }

    private func moveQueuedAgents(from source: IndexSet, to destination: Int) {
        queuedAgents.move(fromOffsets: source, toOffset: destination)

        // Update queue positions
        for (index, _) in queuedAgents.enumerated() {
            queuedAgents[index].queuePosition = index + 1
        }

        // TODO: Call SubagentPool.reorderQueue for each moved agent
        // Task {
        //     for (index, agent) in queuedAgents.enumerated() {
        //         await appState.subagentPool?.reorderQueue(agent.internalId, position: index)
        //     }
        // }
    }

    private func generateDemoSubagents() -> [SubagentCorrelation] {
        [
            SubagentCorrelation(
                toolUseId: "tool_001",
                internalId: UUID(),
                parentSessionId: sessionId ?? UUID(),
                subagentType: "Explore",
                description: "Exploring authentication patterns in codebase",
                prompt: "Find all authentication implementations",
                status: .running,
                tokenUsage: SubagentTokenUsage(
                    inputTokens: 12000,
                    outputTokens: 3500,
                    totalTokens: 15500
                ),
                startedAt: Date().addingTimeInterval(-120)
            ),
            SubagentCorrelation(
                toolUseId: "tool_002",
                internalId: UUID(),
                parentSessionId: sessionId ?? UUID(),
                subagentType: "Plan",
                description: "Creating implementation plan for OAuth2",
                prompt: "Plan OAuth2 integration",
                status: .running,
                tokenUsage: SubagentTokenUsage(
                    inputTokens: 8000,
                    outputTokens: 2000,
                    totalTokens: 10000
                ),
                startedAt: Date().addingTimeInterval(-60)
            ),
            SubagentCorrelation(
                toolUseId: "tool_003",
                internalId: UUID(),
                parentSessionId: sessionId ?? UUID(),
                subagentType: "Implement",
                description: "Database migration for user sessions",
                prompt: "Create migration for sessions table",
                status: .queued,
                queuePosition: 1,
                priority: 5
            ),
            SubagentCorrelation(
                toolUseId: "tool_004",
                internalId: UUID(),
                parentSessionId: sessionId ?? UUID(),
                subagentType: "Validate",
                description: "Review security best practices",
                prompt: "Validate security implementation",
                status: .queued,
                queuePosition: 2,
                priority: 3
            ),
            SubagentCorrelation(
                toolUseId: "tool_005",
                internalId: UUID(),
                parentSessionId: sessionId ?? UUID(),
                subagentType: "Research",
                description: "Research PKCE flow for mobile apps",
                prompt: "Research OAuth PKCE flow",
                status: .queued,
                queuePosition: 3,
                priority: 1
            )
        ]
    }
}

// MARK: - Subagent Card

struct SubagentCard: View {
    let correlation: SubagentCorrelation

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // Header row: icon + type + position
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: subagentIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(statusColor)
                    .frame(width: 16)

                Text(correlation.subagentType)
                    .dsTextStyle(.caption)
                    .fontWeight(.medium)

                Spacer()

                // Queue position badge
                if let position = correlation.queuePosition {
                    Text("#\(position)")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                        .padding(.horizontal, DSSpacing.xxs)
                        .padding(.vertical, 2)
                        .background(Color.ds.surface.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                }
            }

            // Description
            Text(correlation.description)
                .dsTextStyle(.caption, color: .ds.secondary)
                .lineLimit(2)

            // Token usage progress (if available)
            if let tokens = correlation.tokenUsage {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: Double(tokens.totalTokens), total: 100000)
                        .progressViewStyle(.linear)
                        .tint(statusColor)

                    Text("\(formatTokenCount(tokens.totalTokens)) tokens")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                }
            }

            // Status indicator
            HStack(spacing: DSSpacing.xxs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                Text(correlation.status.rawValue.capitalized)
                    .dsTextStyle(.micro, color: statusColor)

                // Duration (if running)
                if let startedAt = correlation.startedAt {
                    Text("•")
                        .dsTextStyle(.micro, color: .ds.tertiary)

                    Text(formatDuration(Date().timeIntervalSince(startedAt)))
                        .dsTextStyle(.micro, color: .ds.tertiary)
                }
            }
        }
        .padding(DSSpacing.sm)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .strokeBorder(isHovered ? statusColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

    // MARK: - Helpers

    private var subagentIcon: String {
        switch correlation.subagentType {
        case "Explore": return "magnifyingglass"
        case "Plan": return "list.bullet.clipboard"
        case "Implement": return "hammer.fill"
        case "Validate": return "checkmark.shield.fill"
        case "Research": return "book.fill"
        default: return "cpu"
        }
    }

    private var statusColor: Color {
        switch correlation.status {
        case .running: return .ds.positive
        case .queued: return .ds.tertiary
        case .completed: return .ds.info
        case .failed: return .ds.negative
        case .cancelled: return .ds.warning
        }
    }

    private var cardBackground: Color {
        switch correlation.status {
        case .running: return .ds.positive.opacity(0.05)
        case .queued: return .ds.surface.opacity(0.3)
        case .completed: return .ds.info.opacity(0.05)
        case .failed: return .ds.negative.opacity(0.05)
        case .cancelled: return .ds.warning.opacity(0.05)
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

// MARK: - Previews

#if DEBUG
struct SubagentsSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SubagentsSidebarView(sessionId: UUID(), maxConcurrent: 3)
                .environmentObject(AppState())
                .frame(width: 280, height: 600)
                .background(Color.ds.bg0)
                .previewDisplayName("Subagents Sidebar - Active")

            SubagentsSidebarView(sessionId: nil, maxConcurrent: 3)
                .environmentObject(AppState())
                .frame(width: 280, height: 400)
                .background(Color.ds.bg0)
                .previewDisplayName("Subagents Sidebar - Empty")
        }
    }
}
#endif
