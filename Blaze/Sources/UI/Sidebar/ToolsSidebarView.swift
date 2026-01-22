import SwiftUI

// MARK: - Tools Sidebar View

/// Enhanced tools sidebar with stats, filtering, and re-run capabilities
struct ToolsSidebarView: View {
    let sessionId: UUID?
    let events: [EventEnvelope]

    @State private var selectedFilter: ToolFilter = .all
    @State private var showStats: Bool = true

    /// Check if session has ended (completed or errored)
    private var sessionHasEnded: Bool {
        events.contains { envelope in
            if case .sessionEnded = envelope.event { return true }
            return false
        }
    }

    private var toolEvents: [EventEnvelope] {
        // Get all tool-related events
        let allToolEvents = events.filter { envelope in
            switch envelope.event {
            case .toolCallStarted, .toolCallComplete, .toolRequest, .toolResult:
                return true
            default:
                return false
            }
        }

        // Build set of tool IDs that have completed
        var completedToolIds = Set<String>()
        for envelope in allToolEvents {
            if case .toolCallComplete(let complete) = envelope.event {
                completedToolIds.insert(complete.toolCallId)
            }
            if case .toolResult(let result) = envelope.event {
                completedToolIds.insert(result.toolCallId)
            }
        }

        // For ended sessions, don't show orphaned tool starts (they were abandoned)
        // For active sessions, show incomplete tool starts as "running"
        return allToolEvents.filter { envelope in
            switch envelope.event {
            case .toolCallStarted(let started):
                // Only show started if there's no corresponding complete
                // AND the session is still active (not ended)
                let hasCompletion = completedToolIds.contains(started.toolCallId)
                return !hasCompletion && !sessionHasEnded
            case .toolCallComplete, .toolResult:
                return true
            case .toolRequest:
                return false  // Don't show requests, wait for result
            default:
                return false
            }
        }
    }

    private var filteredEvents: [EventEnvelope] {
        switch selectedFilter {
        case .all:
            return toolEvents
        case .running:
            return toolEvents.filter { isRunningTool($0) }
        case .succeeded:
            return toolEvents.filter { isSucceededTool($0) }
        case .failed:
            return toolEvents.filter { isFailedTool($0) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stats header (collapsible)
            if !toolEvents.isEmpty {
                if showStats {
                    toolStatsHeader
                } else {
                    // Collapsed state - show expand button
                    collapsedStatsHeader
                }
            }

            // Filter bar
            filterBar

            Divider()

            // Tool list
            if filteredEvents.isEmpty {
                emptyState
            } else {
                toolList
            }
        }
        .clipped()
    }

    // MARK: - Stats Header

    private var toolStatsHeader: some View {
        HStack(spacing: DSSpacing.md) {
            StatBadge(
                label: "Total",
                value: "\(completedToolsCount)",
                color: .ds.secondary
            )

            StatBadge(
                label: "Succeeded",
                value: "\(succeededCount)",
                color: .ds.positive
            )

            StatBadge(
                label: "Failed",
                value: "\(failedCount)",
                color: .ds.negative
            )

            if let avgDuration = averageDuration {
                StatBadge(
                    label: "Avg",
                    value: formatDuration(avgDuration),
                    color: .ds.info
                )
            }

            Spacer()

            Button {
                withAnimation {
                    showStats.toggle()
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.ds.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(Color.ds.surface.opacity(0.3))
    }

    // MARK: - Collapsed Stats Header

    private var collapsedStatsHeader: some View {
        Button {
            withAnimation {
                showStats = true
            }
        } label: {
            HStack {
                Text("\(completedToolsCount) tools")
                    .dsTextStyle(.caption, color: .ds.secondary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.ds.tertiary)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(Color.ds.surface.opacity(0.2))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: DSSpacing.xs) {
            // Row 1: All, Running (centered)
            HStack(spacing: DSSpacing.xs) {
                FilterChip(
                    label: ToolFilter.all.rawValue,
                    isSelected: selectedFilter == .all,
                    count: countForFilter(.all)
                ) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedFilter = .all
                    }
                }
                FilterChip(
                    label: ToolFilter.running.rawValue,
                    isSelected: selectedFilter == .running,
                    count: countForFilter(.running)
                ) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedFilter = .running
                    }
                }
            }
            // Row 2: Succeeded, Failed (centered)
            HStack(spacing: DSSpacing.xs) {
                FilterChip(
                    label: ToolFilter.succeeded.rawValue,
                    isSelected: selectedFilter == .succeeded,
                    count: countForFilter(.succeeded)
                ) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedFilter = .succeeded
                    }
                }
                FilterChip(
                    label: ToolFilter.failed.rawValue,
                    isSelected: selectedFilter == .failed,
                    count: countForFilter(.failed)
                ) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedFilter = .failed
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Tool List

    private var toolList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.xs) {
                ForEach(filteredEvents) { envelope in
                    EnhancedToolEventRow(envelope: envelope)
                }
            }
            .padding(DSSpacing.sm)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: selectedFilter == .all ? "wrench.and.screwdriver" : "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Color.ds.tertiary)

            Text(selectedFilter == .all ? "No Tool Calls" : "No Matching Tools")
                .dsTextStyle(.subtitle)

            Text(selectedFilter == .all
                 ? "Tool calls will appear here as they execute"
                 : "Try a different filter")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)

            if selectedFilter != .all {
                Button("Show All") {
                    selectedFilter = .all
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Stats

    private var completedToolsCount: Int {
        toolEvents.filter { isCompletedTool($0) }.count
    }

    private var succeededCount: Int {
        toolEvents.filter { isSucceededTool($0) }.count
    }

    private var failedCount: Int {
        toolEvents.filter { isFailedTool($0) }.count
    }

    private var averageDuration: TimeInterval? {
        let durations = toolEvents.compactMap { envelope -> TimeInterval? in
            if case .toolCallComplete(let complete) = envelope.event {
                return complete.duration
            }
            return nil
        }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    private func countForFilter(_ filter: ToolFilter) -> Int {
        switch filter {
        case .all: return toolEvents.count
        case .running: return toolEvents.filter { isRunningTool($0) }.count
        case .succeeded: return succeededCount
        case .failed: return failedCount
        }
    }

    // MARK: - Helper Functions

    private func isCompletedTool(_ envelope: EventEnvelope) -> Bool {
        if case .toolCallComplete = envelope.event { return true }
        if case .toolResult = envelope.event { return true }
        return false
    }

    private func isRunningTool(_ envelope: EventEnvelope) -> Bool {
        if case .toolCallStarted = envelope.event { return true }
        return false
    }

    private func isSucceededTool(_ envelope: EventEnvelope) -> Bool {
        if case .toolCallComplete(let complete) = envelope.event {
            return complete.succeeded
        }
        if case .toolResult(let result) = envelope.event {
            return result.succeeded
        }
        return false
    }

    private func isFailedTool(_ envelope: EventEnvelope) -> Bool {
        if case .toolCallComplete(let complete) = envelope.event {
            return !complete.succeeded
        }
        if case .toolResult(let result) = envelope.event {
            return !result.succeeded
        }
        return false
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else {
            return String(format: "%.1fs", duration)
        }
    }
}

// MARK: - Tool Filter

enum ToolFilter: String, CaseIterable {
    case all = "All"
    case running = "Running"
    case succeeded = "Succeeded"
    case failed = "Failed"
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xxs) {
                Text(label)
                    .font(.system(size: 11))
                    .lineLimit(1)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            isSelected
                                ? Color.ds.foreground.opacity(0.2)
                                : Color.ds.surface.opacity(0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)
            .foregroundStyle(isSelected ? Color.ds.foreground : Color.ds.secondary)
            .background(
                isSelected
                    ? Color.ds.accent.opacity(0.2)
                    : Color.ds.surface.opacity(0.3)
            )
            .clipShape(Capsule())
            .fixedSize(horizontal: true, vertical: false)  // Fixed width, flexible height
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color.ds.tertiary)
        }
    }
}

// MARK: - Enhanced Tool Event Row

struct EnhancedToolEventRow: View {
    let envelope: EventEnvelope
    @State private var isExpanded: Bool = false
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DSSpacing.sm) {
                    statusIcon
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(toolName)
                            .dsTextStyle(.monoSmall, weight: .medium)

                        if let duration = envelope.event.duration {
                            Text(formatDuration(duration))
                                .dsTextStyle(.micro, color: .ds.tertiary)
                        }
                    }

                    Spacer()

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                expandedDetails
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.bottom, DSSpacing.sm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .background(
            isHovered
                ? Color.ds.surface.opacity(0.3)
                : Color.ds.surface.opacity(0.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
        }
        .onHover { isHovered = $0 }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch envelope.event {
        case .toolCallStarted:
            ProgressView()
                .scaleEffect(0.5)
        case .toolCallComplete(let complete):
            Image(systemName: complete.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(complete.succeeded ? Color.ds.positive : Color.ds.negative)
                .font(.system(size: 12))
        case .toolResult(let result):
            Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.succeeded ? Color.ds.positive : Color.ds.negative)
                .font(.system(size: 12))
        default:
            Image(systemName: "questionmark.circle")
                .foregroundStyle(Color.ds.tertiary)
                .font(.system(size: 12))
        }
    }

    // MARK: - Expanded Details

    @ViewBuilder
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Divider()

            // Input section
            if let input = toolInput {
                DetailSection(title: "Input", content: input)
            }

            // Output section
            if let output = toolOutput {
                DetailSection(title: "Output", content: output)
            }

            // Error section
            if let error = toolError {
                DetailSection(title: "Error", content: error, isError: true)
            }
        }
    }

    // MARK: - Helpers

    private var toolName: String {
        switch envelope.event {
        case .toolCallStarted(let started): return started.toolName
        case .toolCallComplete(let complete): return complete.toolName
        case .toolRequest(let request): return request.toolName
        case .toolResult(let result): return result.toolName
        default: return "Unknown"
        }
    }

    private var toolInput: String? {
        switch envelope.event {
        case .toolCallStarted(let started): return started.input
        case .toolRequest(let request): return request.input
        default: return nil
        }
    }

    private var toolOutput: String? {
        switch envelope.event {
        case .toolCallComplete(let complete): return complete.output
        case .toolResult(let result): return result.output
        default: return nil
        }
    }

    private var toolError: String? {
        switch envelope.event {
        case .toolCallComplete(let complete): return complete.error
        case .toolResult(let result): return result.error
        default: return nil
        }
    }

    private var statusColor: Color {
        switch envelope.event {
        case .toolCallStarted:
            return Color.ds.info
        case .toolCallComplete(let complete):
            return complete.succeeded ? Color.ds.positive : Color.ds.negative
        case .toolResult(let result):
            return result.succeeded ? Color.ds.positive : Color.ds.negative
        default:
            return Color.ds.secondary
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Detail Section

struct DetailSection: View {
    let title: String
    let content: String
    var isError: Bool = false

    @State private var isCopied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            HStack {
                Text(title)
                    .dsTextStyle(.micro, color: isError ? .ds.negative : .ds.secondary)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isCopied = false
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(isCopied ? Color.ds.positive : Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isError ? Color.ds.negative : Color.ds.foreground)
                    .textSelection(.enabled)
                    .lineLimit(5)
            }
            .padding(DSSpacing.xs)
            .background(Color.ds.surface.opacity(isError ? 0.3 : 0.5))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        }
    }
}

// MARK: - Previews

#Preview("Tools Sidebar") {
    let events = [
        EventEnvelope(
            sessionId: UUID(),
            sequence: 1,
            event: .toolCallStarted(ToolCallStarted(
                toolCallId: "1",
                toolName: "Read",
                input: "/path/to/file.swift",
                timestamp: Date()
            ))
        ),
        EventEnvelope(
            sessionId: UUID(),
            sequence: 2,
            event: .toolCallComplete(ToolCallComplete(
                toolCallId: "1",
                toolName: "Read",
                output: "file contents here...",
                error: nil,
                duration: 0.234,
                timestamp: Date()
            ))
        ),
        EventEnvelope(
            sessionId: UUID(),
            sequence: 3,
            event: .toolCallComplete(ToolCallComplete(
                toolCallId: "2",
                toolName: "Write",
                output: nil,
                error: "Permission denied",
                duration: 0.05,
                timestamp: Date()
            ))
        ),
    ]

    ToolsSidebarView(sessionId: UUID(), events: events)
        .frame(width: 280, height: 500)
        .background(Color.ds.bg0)
}

#Preview("Filter Chips") {
    HStack {
        FilterChip(label: "All", isSelected: true, count: 12, action: {})
        FilterChip(label: "Running", isSelected: false, count: 2, action: {})
        FilterChip(label: "Failed", isSelected: false, count: 1, action: {})
    }
    .padding()
    .background(Color.ds.bg0)
}
