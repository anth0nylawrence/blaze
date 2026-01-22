import SwiftUI

// MARK: - Agents Sidebar View

/// Tab 14: Background/spawned agents sidebar.
///
/// **Phase 2 Spec:**
/// - List background/spawned agents
/// - Show: Agent ID, task description, status (running/complete/failed)
/// - Actions: View output, Cancel, Retry
/// - Show parent-child relationships for nested agents
struct AgentsSidebarView: View {
    let sessionId: UUID?

    @EnvironmentObject var appState: AppState
    @State private var correlations: [SubagentCorrelation] = []
    @State private var isLoading: Bool = false
    @State private var expandedAgents: Set<UUID> = []
    @State private var selectedAgentId: UUID?
    @State private var showOutputSheet: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Agent list
            if isLoading {
                loadingView
            } else if correlations.isEmpty {
                emptyView
            } else {
                agentListView
            }
        }
        .task {
            await loadAgents()
        }
        .sheet(isPresented: $showOutputSheet) {
            if let agentId = selectedAgentId,
               let correlation = correlations.first(where: { $0.internalId == agentId }) {
                SubagentOutputSheet(correlation: correlation) {
                    showOutputSheet = false
                }
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Label("Agents", systemImage: "cpu.fill")
                .dsTextStyle(.caption, color: .ds.secondary)

            Spacer()

            // Status summary
            if !correlations.isEmpty {
                let runningCount = correlations.filter { $0.status == .running }.count
                if runningCount > 0 {
                    HStack(spacing: DSSpacing.xxs) {
                        Circle()
                            .fill(Color.ds.positive)
                            .frame(width: 6, height: 6)
                        Text("\(runningCount) running")
                            .dsTextStyle(.micro, color: .ds.positive)
                    }
                }
            }

            // Refresh button
            Button {
                Task {
                    await loadAgents()
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

            Text("Loading agents...")
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "person.3")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("No Active Agents")
                .dsTextStyle(.subtitle)

            Text("Background agents will appear here when spawned during complex tasks")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Agent List View

    private var agentListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Sort by startedAt (most recent first), then by status
                let sorted = correlations.sorted { a, b in
                    let aTime = a.startedAt ?? .distantPast
                    let bTime = b.startedAt ?? .distantPast
                    return aTime > bTime
                }

                ForEach(sorted, id: \.internalId) { correlation in
                    SubagentRowView(
                        correlation: correlation,
                        onViewOutput: { viewOutput(correlation) },
                        onCancel: { cancelAgent(correlation) },
                        onRetry: { retryAgent(correlation) }
                    )
                }
            }
            .padding(.vertical, DSSpacing.xs)
        }
    }

    // MARK: - Actions

    private func loadAgents() async {
        isLoading = true
        defer { isLoading = false }

        guard let sessionId = sessionId else {
            correlations = []
            return
        }

        // Load from registry via AppState
        correlations = await appState.getSubagents(for: sessionId)
    }

    private func viewOutput(_ correlation: SubagentCorrelation) {
        selectedAgentId = correlation.internalId
        showOutputSheet = true
    }

    private func cancelAgent(_ correlation: SubagentCorrelation) {
        // TODO: Send cancel signal to SubagentPool
        // For now, just update local state
        if let index = correlations.firstIndex(where: { $0.internalId == correlation.internalId }) {
            correlations[index].status = .cancelled
            correlations[index].completedAt = Date()
        }
    }

    private func retryAgent(_ correlation: SubagentCorrelation) {
        // TODO: Re-enqueue in SubagentPool
        // For now, just update local state
        if let index = correlations.firstIndex(where: { $0.internalId == correlation.internalId }) {
            correlations[index].status = .running
            correlations[index].completedAt = nil
            correlations[index].error = nil
        }
    }
}

// MARK: - Subagent Row View

/// Row view for a single subagent correlation
struct SubagentRowView: View {
    let correlation: SubagentCorrelation
    let onViewOutput: () -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onViewOutput) {
            HStack(spacing: DSSpacing.sm) {
                // Status icon
                statusIcon

                // Agent info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DSSpacing.xs) {
                        Text(correlation.subagentType)
                            .dsTextStyle(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor)

                        Text(correlation.description)
                            .dsTextStyle(.caption)
                            .lineLimit(1)
                    }

                    HStack(spacing: DSSpacing.sm) {
                        // Duration
                        if let startedAt = correlation.startedAt {
                            let duration = (correlation.completedAt ?? Date()).timeIntervalSince(startedAt)
                            Text(formatDuration(duration))
                                .dsTextStyle(.micro, color: .ds.tertiary)
                        }

                        // Token usage
                        if let tokens = correlation.tokenUsage {
                            Text("\(formatTokens(tokens.totalTokens)) tokens")
                                .dsTextStyle(.micro, color: .ds.tertiary)
                        }

                        // Error snippet (if failed)
                        if let error = correlation.error {
                            Text(String(error.prefix(30)) + "...")
                                .dsTextStyle(.micro, color: .ds.negative)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Action buttons (visible on hover)
                if isHovered {
                    actionButtons
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.ds.surface.opacity(0.3) : Color.clear)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if correlation.status == .running {
            ZStack {
                Circle()
                    .fill(Color.ds.positive.opacity(0.3))
                    .frame(width: 16, height: 16)

                Circle()
                    .fill(Color.ds.positive)
                    .frame(width: 8, height: 8)
            }
        } else {
            Image(systemName: statusIconName)
                .font(.system(size: 12))
                .foregroundStyle(statusColor)
                .frame(width: 16)
        }
    }

    private var statusIconName: String {
        switch correlation.status {
        case .queued: return "circle.dashed"
        case .running: return "circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "slash.circle.fill"
        }
    }

    private var statusColor: Color {
        switch correlation.status {
        case .queued: return .ds.tertiary
        case .running: return .ds.positive
        case .completed: return .ds.info
        case .failed: return .ds.negative
        case .cancelled: return .ds.warning
        }
    }

    private var actionButtons: some View {
        HStack(spacing: DSSpacing.xxs) {
            Button(action: onViewOutput) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.ds.tertiary)
            }
            .buttonStyle(.plain)
            .help("View output")

            if correlation.status == .running {
                Button(action: onCancel) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.ds.warning)
                }
                .buttonStyle(.plain)
                .help("Cancel")
            }

            if correlation.status == .failed {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.ds.info)
                }
                .buttonStyle(.plain)
                .help("Retry")
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: duration) ?? ""
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - Subagent Output Sheet

struct SubagentOutputSheet: View {
    let correlation: SubagentCorrelation
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            // Header
            HStack {
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: subagentIcon)
                        .foregroundStyle(statusColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(correlation.subagentType)
                            .dsTextStyle(.subtitle)
                            .fontWeight(.semibold)

                        Text(correlation.description)
                            .dsTextStyle(.caption, color: .ds.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Status info
            HStack(spacing: DSSpacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                    Text(correlation.status.rawValue.capitalized)
                        .dsTextStyle(.caption, color: statusColor)
                }

                if let startedAt = correlation.startedAt {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Started")
                            .dsTextStyle(.micro, color: .ds.tertiary)
                        Text(formatTime(startedAt))
                            .dsTextStyle(.caption)
                    }
                }

                if let completed = correlation.completedAt {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Completed")
                            .dsTextStyle(.micro, color: .ds.tertiary)
                        Text(formatTime(completed))
                            .dsTextStyle(.caption)
                    }
                }

                if let tokens = correlation.tokenUsage {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tokens")
                            .dsTextStyle(.micro, color: .ds.tertiary)
                        Text("\(tokens.totalTokens)")
                            .dsTextStyle(.caption)
                    }
                }

                Spacer()
            }

            Divider()

            // Prompt content
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Prompt")
                        .dsTextStyle(.caption, color: .ds.secondary)

                    Text(correlation.prompt)
                        .dsTextStyle(.monoSmall)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DSSpacing.sm)
                        .background(Color.ds.surface.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))

                    if let error = correlation.error {
                        Text("Error")
                            .dsTextStyle(.caption, color: .ds.negative)

                        Text(error)
                            .dsTextStyle(.monoSmall, color: .ds.negative)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DSSpacing.sm)
                            .background(Color.ds.negative.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                    }
                }
            }

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Close", action: onDismiss)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(DSSpacing.lg)
        .frame(width: 500, height: 450)
    }

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
        case .queued: return .ds.tertiary
        case .running: return .ds.positive
        case .completed: return .ds.info
        case .failed: return .ds.negative
        case .cancelled: return .ds.warning
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Previews

#Preview("Agents Sidebar") {
    AgentsSidebarView(sessionId: UUID())
        .environmentObject(AppState())
        .frame(width: 280, height: 600)
        .background(Color.ds.bg0)
}

#Preview("Agents Sidebar - Empty") {
    AgentsSidebarView(sessionId: nil)
        .environmentObject(AppState())
        .frame(width: 280, height: 400)
        .background(Color.ds.bg0)
}
