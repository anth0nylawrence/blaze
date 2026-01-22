import SwiftUI

// MARK: - Hook Gantt View

/// Main coordinator view for the Gantt timeline visualization.
/// Orchestrates time axis, rows, and synchronized scrolling.
public struct HookGanttView: View {
    @Bindable var viewModel: HookGanttViewModel

    // MARK: - Constants

    private let nameColumnWidth: CGFloat = 200
    private let rowHeight: CGFloat = 32
    private let timeAxisHeight: CGFloat = 28
    private let timeMarkerCount: Int = 8

    // MARK: - State

    @State private var timelineScrollOffset: CGFloat = 0
    @State private var hoveredRowId: UUID?

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar: view mode picker, expand/collapse buttons
            toolbar

            Divider()

            // Main content area
            if viewModel.flattenedEvents.isEmpty {
                emptyState
            } else {
                timelineContent
            }
        }
        .background(Color.ds.bg0)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: DSSpacing.md) {
            // View mode picker
            Picker("View", selection: $viewModel.viewMode) {
                ForEach(GanttViewMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Spacer()

            // Expand/collapse buttons
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.expandAll()
                }
            } label: {
                Label("Expand All", systemImage: "arrow.down.right.and.arrow.up.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ds.secondary)
            .help("Expand all rows")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.collapseAll()
                }
            } label: {
                Label("Collapse All", systemImage: "arrow.up.left.and.arrow.down.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ds.secondary)
            .help("Collapse all rows")
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(Color.ds.bg1)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(Color.ds.secondary.opacity(0.5))

            Text("No hook executions to display")
                .dsTextStyle(.body, weight: .medium)
                .foregroundStyle(Color.ds.secondary)

            Text("Hook timeline will appear here when hooks run")
                .dsTextStyle(.caption, weight: .regular)
                .foregroundStyle(Color.ds.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DSSpacing.xl)
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        VStack(spacing: 0) {
            // Time axis header
            timeAxisHeader

            Divider()
                .opacity(0.5)

            // Scrollable rows
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.flattenedEvents) { event in
                        ganttRowView(for: event)
                            .background(rowBackground(for: event))

                        Divider()
                            .opacity(0.2)
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            // Tooltip popover
            if let hoveredEvent = viewModel.hoveredEvent {
                tooltipOverlay(for: hoveredEvent)
            }
        }
    }

    // MARK: - Time Axis Header

    private var timeAxisHeader: some View {
        HStack(spacing: 0) {
            // Empty space above name column
            Text("Event")
                .dsTextStyle(.caption, weight: .medium)
                .foregroundStyle(Color.ds.secondary)
                .frame(width: nameColumnWidth, alignment: .leading)
                .padding(.leading, DSSpacing.md)

            // Time markers
            GeometryReader { geometry in
                timeMarkersView(width: geometry.size.width)
            }
            .padding(.trailing, DSSpacing.sm)
        }
        .frame(height: timeAxisHeight)
        .background(Color.ds.bg1.opacity(0.5))
    }

    // MARK: - Time Markers

    private func timeMarkersView(width: CGFloat) -> some View {
        let totalDuration = viewModel.totalDuration
        guard totalDuration > 0 else {
            return AnyView(EmptyView())
        }

        return AnyView(
            ZStack(alignment: .leading) {
                // Grid lines (background)
                ForEach(0..<timeMarkerCount, id: \.self) { index in
                    let fraction = CGFloat(index) / CGFloat(timeMarkerCount - 1)
                    let x = fraction * width

                    Rectangle()
                        .fill(Color.ds.secondary.opacity(0.15))
                        .frame(width: 1)
                        .offset(x: x)
                }

                // Time labels
                ForEach(0..<timeMarkerCount, id: \.self) { index in
                    let fraction = CGFloat(index) / CGFloat(timeMarkerCount - 1)
                    let x = fraction * width
                    let time = viewModel.timelineStart.addingTimeInterval(Double(fraction) * totalDuration)

                    Text(formatTimeMarker(time))
                        .dsTextStyle(.micro, weight: .regular)
                        .foregroundStyle(Color.ds.secondary)
                        .offset(x: max(0, min(x - 20, width - 50)))
                }
            }
        )
    }

    // MARK: - Gantt Row

    private func ganttRowView(for event: HookTimelineEvent) -> some View {
        GanttRow(
            event: event,
            timelineStart: viewModel.timelineStart,
            timelineEnd: viewModel.timelineEnd,
            isExpanded: viewModel.expandedEventIds.contains(event.id),
            onToggleExpand: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.toggleExpanded(event.id)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectEvent(event.id)
        }
        .onHover { isHovering in
            hoveredRowId = isHovering ? event.id : nil
            viewModel.hoveredEventId = isHovering ? event.id : nil
        }
    }

    // MARK: - Row Background

    private func rowBackground(for event: HookTimelineEvent) -> some View {
        Group {
            if viewModel.selectedEventId == event.id {
                Color.ds.accent.opacity(0.15)
            } else if hoveredRowId == event.id {
                Color.ds.secondary.opacity(0.08)
            } else if event.depth % 2 == 1 {
                Color.ds.secondary.opacity(0.03)
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Tooltip Overlay

    @ViewBuilder
    private func tooltipOverlay(for event: HookTimelineEvent) -> some View {
        HookTooltip(event: event)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.easeOut(duration: 0.15), value: viewModel.hoveredEventId)
            .padding(.leading, nameColumnWidth + DSSpacing.md)
            .padding(.top, DSSpacing.lg)
    }

    // MARK: - Helpers

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private func formatTimeMarker(_ date: Date) -> String {
        // For short durations, show milliseconds
        if viewModel.totalDuration < 10 {
            let formatter = DateFormatter()
            formatter.dateFormat = "ss.SSS"
            return formatter.string(from: date)
        } else if viewModel.totalDuration < 60 {
            let formatter = DateFormatter()
            formatter.dateFormat = "mm:ss"
            return formatter.string(from: date)
        } else {
            return Self.timeFormatter.string(from: date)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("HookGanttView - Basic") {
    let viewModel = HookGanttViewModel()
    let now = Date()

    // Create sample events
    let child1 = HookTimelineEvent(
        name: "File Validation",
        category: .file,
        startTime: now.addingTimeInterval(0.3),
        endTime: now.addingTimeInterval(0.8),
        depth: 2,
        status: .completed
    )

    let child2 = HookTimelineEvent(
        name: "Git Check",
        category: .git,
        startTime: now.addingTimeInterval(1.0),
        endTime: now.addingTimeInterval(1.5),
        depth: 2,
        status: .completed
    )

    // Note: Sample events created above demonstrate hierarchy structure
    // The viewModel.loadTimeline() call below populates actual data
    _ = (child1, child2) // Silence unused warnings in preview

    return HookGanttView(viewModel: viewModel)
        .onAppear {
            // Load mock data
            viewModel.loadTimeline(
                from: [],
                hooks: [],
                turnStart: now,
                turnEnd: now.addingTimeInterval(3.0)
            )
        }
        .frame(width: 700, height: 400)
}

#Preview("HookGanttView - Empty") {
    HookGanttView(viewModel: HookGanttViewModel())
        .frame(width: 700, height: 300)
}

#Preview("HookGanttView - Running") {
    let viewModel = HookGanttViewModel()

    return HookGanttView(viewModel: viewModel)
        .frame(width: 700, height: 350)
}
#endif
