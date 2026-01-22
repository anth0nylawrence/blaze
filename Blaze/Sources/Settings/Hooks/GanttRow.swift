import SwiftUI

// MARK: - Gantt Row View

/// A single row in the Gantt timeline visualization.
/// Displays a hook event with indentation, expand/collapse chevron, and timeline bar.
public struct GanttRow: View {
    let event: HookTimelineEvent
    let timelineStart: Date
    let timelineEnd: Date
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    // MARK: - Constants

    private let rowHeight: CGFloat = 32
    private let indentPerLevel: CGFloat = 16
    private let nameColumnWidth: CGFloat = 200
    private let chevronSize: CGFloat = 12
    private let barHeight: CGFloat = 18
    private let barCornerRadius: CGFloat = 4

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            // Left side: Name column with indentation and chevron
            nameColumn
                .frame(width: nameColumnWidth, alignment: .leading)

            // Right side: Timeline bar
            timelineBarArea
        }
        .frame(height: rowHeight)
        .contentShape(Rectangle())
    }

    // MARK: - Name Column

    @ViewBuilder
    private var nameColumn: some View {
        HStack(spacing: DSSpacing.xs) {
            // Indentation spacer
            if event.depth > 0 {
                Spacer()
                    .frame(width: CGFloat(event.depth) * indentPerLevel)
            }

            // Expand/collapse chevron (only if has children)
            if !event.children.isEmpty {
                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: chevronSize, weight: .medium))
                        .foregroundStyle(Color.ds.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.15), value: isExpanded)
                }
                .buttonStyle(.plain)
                .frame(width: chevronSize + 4, height: chevronSize + 4)
            } else {
                // Placeholder for alignment when no children
                Spacer()
                    .frame(width: chevronSize + 4)
            }

            // Category icon
            Image(systemName: categoryIcon)
                .font(.system(size: 10))
                .foregroundStyle(categoryColor)

            // Hook name
            Text(event.name)
                .dsTextStyle(.body, weight: .regular)
                .foregroundStyle(Color.ds.foreground)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.leading, DSSpacing.sm)
    }

    // MARK: - Timeline Bar Area

    @ViewBuilder
    private var timelineBarArea: some View {
        GeometryReader { geometry in
            let totalDuration = timelineEnd.timeIntervalSince(timelineStart)
            guard totalDuration > 0 else {
                return AnyView(EmptyView())
            }

            let startOffset = event.startTime.timeIntervalSince(timelineStart)
            let eventEnd = event.endTime ?? Date()
            let eventDuration = eventEnd.timeIntervalSince(event.startTime)

            // Calculate bar position and width
            let startFraction = max(0, min(1, startOffset / totalDuration))
            let durationFraction = max(0.01, min(1 - startFraction, eventDuration / totalDuration))

            let barX = startFraction * geometry.size.width
            let barWidth = durationFraction * geometry.size.width

            return AnyView(
                ZStack(alignment: .leading) {
                    // The colored bar
                    RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                        .fill(barGradient)
                        .frame(width: max(4, barWidth), height: barHeight)
                        .overlay {
                            // Subtle inner stroke for depth
                            RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        }
                        .overlay {
                            // Running pulse animation
                            if event.status == .running {
                                RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: max(4, barWidth), height: barHeight)
                                    .opacity(0.5)
                                    .animation(
                                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                        value: event.status
                                    )
                            }
                        }
                        .offset(x: barX)

                    // Duration label (if bar is wide enough)
                    if barWidth > 40, let duration = event.duration {
                        Text(formatDuration(duration))
                            .dsTextStyle(.micro, weight: .medium)
                            .foregroundStyle(Color.white.opacity(0.9))
                            .offset(x: barX + 6)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        }
        .padding(.trailing, DSSpacing.sm)
    }

    // MARK: - Bar Gradient

    private var barGradient: LinearGradient {
        let baseColor = categoryColor
        return LinearGradient(
            colors: [
                baseColor.opacity(statusOpacity),
                baseColor.opacity(statusOpacity * 0.7)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var statusOpacity: Double {
        switch event.status {
        case .pending: return 0.4
        case .running: return 0.9
        case .completed: return 0.8
        case .failed: return 0.9
        case .cancelled: return 0.5
        }
    }

    // MARK: - Category Styling

    private var categoryColor: Color {
        switch event.category {
        case .session: return .blue
        case .turn: return .purple
        case .tool: return .orange
        case .file: return .green
        case .git: return .cyan
        }
    }

    private var categoryIcon: String {
        switch event.category {
        case .session: return "play.circle"
        case .turn: return "arrow.turn.right.down"
        case .tool: return "hammer"
        case .file: return "doc"
        case .git: return "arrow.triangle.branch"
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ interval: TimeInterval) -> String {
        if interval < 1 {
            return String(format: "%.0fms", interval * 1000)
        } else if interval < 60 {
            return String(format: "%.1fs", interval)
        } else {
            let minutes = Int(interval / 60)
            let seconds = Int(interval.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("GanttRow - Basic") {
    let now = Date()
    let event = HookTimelineEvent(
        name: "PostToolUse: Bash",
        category: .tool,
        startTime: now,
        endTime: now.addingTimeInterval(2.5),
        depth: 0,
        status: .completed
    )

    GanttRow(
        event: event,
        timelineStart: now.addingTimeInterval(-1),
        timelineEnd: now.addingTimeInterval(5),
        isExpanded: false,
        onToggleExpand: {}
    )
    .padding()
    .background(Color.ds.bg0)
}

#Preview("GanttRow - With Children") {
    let now = Date()
    let child = HookTimelineEvent(
        name: "File Write",
        category: .file,
        startTime: now.addingTimeInterval(0.5),
        endTime: now.addingTimeInterval(1.5),
        depth: 1,
        status: .completed
    )
    let event = HookTimelineEvent(
        name: "Session Handler",
        category: .session,
        startTime: now,
        endTime: now.addingTimeInterval(3),
        depth: 0,
        children: [child],
        status: .completed
    )

    VStack(spacing: 0) {
        GanttRow(
            event: event,
            timelineStart: now.addingTimeInterval(-1),
            timelineEnd: now.addingTimeInterval(5),
            isExpanded: true,
            onToggleExpand: {}
        )
        GanttRow(
            event: child,
            timelineStart: now.addingTimeInterval(-1),
            timelineEnd: now.addingTimeInterval(5),
            isExpanded: false,
            onToggleExpand: {}
        )
    }
    .padding()
    .background(Color.ds.bg0)
}

#Preview("GanttRow - Running") {
    let now = Date()
    let event = HookTimelineEvent(
        name: "Long Running Hook",
        category: .turn,
        startTime: now.addingTimeInterval(-2),
        endTime: nil,
        depth: 0,
        status: .running
    )

    GanttRow(
        event: event,
        timelineStart: now.addingTimeInterval(-3),
        timelineEnd: now.addingTimeInterval(2),
        isExpanded: false,
        onToggleExpand: {}
    )
    .padding()
    .background(Color.ds.bg0)
}

#Preview("GanttRow - All Categories") {
    let now = Date()
    let events: [HookTimelineEvent] = [
        HookTimelineEvent(name: "Session Start", category: .session, startTime: now, endTime: now.addingTimeInterval(4), status: .completed),
        HookTimelineEvent(name: "Turn Begin", category: .turn, startTime: now.addingTimeInterval(0.5), endTime: now.addingTimeInterval(3.5), depth: 1, status: .completed),
        HookTimelineEvent(name: "Tool Call", category: .tool, startTime: now.addingTimeInterval(1), endTime: now.addingTimeInterval(2), depth: 2, status: .completed),
        HookTimelineEvent(name: "File Write", category: .file, startTime: now.addingTimeInterval(1.2), endTime: now.addingTimeInterval(1.8), depth: 3, status: .completed),
        HookTimelineEvent(name: "Git Commit", category: .git, startTime: now.addingTimeInterval(3), endTime: now.addingTimeInterval(3.5), depth: 1, status: .failed),
    ]

    VStack(spacing: 0) {
        ForEach(events) { event in
            GanttRow(
                event: event,
                timelineStart: now.addingTimeInterval(-0.5),
                timelineEnd: now.addingTimeInterval(5),
                isExpanded: true,
                onToggleExpand: {}
            )
            Divider()
                .opacity(0.3)
        }
    }
    .padding()
    .background(Color.ds.bg0)
}
#endif
