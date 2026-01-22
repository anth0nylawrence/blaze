import SwiftUI

// MARK: - Timeline Sidebar View

/// Sidebar view showing a filterable timeline of events for the current session
struct TimelineSidebarView: View {
    let sessionId: UUID?
    let events: [EventEnvelope]
    var onEventTapped: ((UUID) -> Void)?

    @State private var selectedFilters: Set<EventCategory> = Set(EventCategory.allCases)
    @State private var showHistogram: Bool = false
    @State private var selectedEventForDetail: EventEnvelope?

    var body: some View {
        VStack(spacing: 0) {
            // Header with counts
            eventCountBadges

            Divider()

            // Filter controls
            filterControls

            Divider()

            // Event list
            if filteredEvents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredEvents) { envelope in
                            TimelineEventRow(envelope: envelope) {
                                selectedEventForDetail = envelope
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }

            // Optional histogram toggle
            if !filteredEvents.isEmpty {
                Divider()
                histogramSection
            }
        }
        .sheet(item: $selectedEventForDetail) { envelope in
            EventDetailSheet(envelope: envelope)
        }
    }

    // MARK: - Filtered Events

    private var filteredEvents: [EventEnvelope] {
        events.filter { envelope in
            selectedFilters.contains(envelope.event.category)
        }
    }

    // MARK: - Event Count Badges

    private var eventCountBadges: some View {
        HStack(spacing: 8) {
            ForEach(EventCategory.allCases, id: \.self) { category in
                let count = events.filter { $0.event.category == category }.count
                if count > 0 {
                    EventCountBadge(
                        category: category,
                        count: count,
                        isSelected: selectedFilters.contains(category)
                    )
                    .onTapGesture {
                        toggleFilter(category)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Filter Controls

    private var filterControls: some View {
        HStack {
            Text("Filter:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("All") {
                selectedFilters = Set(EventCategory.allCases)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(selectedFilters.count == EventCategory.allCases.count ? .blue : .secondary)

            Button("None") {
                selectedFilters = []
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(selectedFilters.isEmpty ? .blue : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "timeline.selection")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text(events.isEmpty ? "No events yet" : "No matching events")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !events.isEmpty {
                Button("Clear filters") {
                    selectedFilters = Set(EventCategory.allCases)
                }
                .font(.caption)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Histogram Section

    private var histogramSection: some View {
        VStack(spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHistogram.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                    Text("Duration Histogram")
                        .font(.caption)
                    Spacer()
                    Image(systemName: showHistogram ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if showHistogram {
                DurationHistogram(events: filteredEvents)
                    .frame(height: 80)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }

    // MARK: - Helpers

    private func toggleFilter(_ category: EventCategory) {
        if selectedFilters.contains(category) {
            selectedFilters.remove(category)
        } else {
            selectedFilters.insert(category)
        }
    }
}

// MARK: - Event Category

/// Categories for filtering events in the timeline
enum EventCategory: String, CaseIterable, Identifiable {
    case content = "Content"
    case tool = "Tools"
    case file = "Files"
    case system = "System"
    case error = "Errors"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .content: return "text.bubble"
        case .tool: return "wrench.and.screwdriver"
        case .file: return "doc"
        case .system: return "gearshape"
        case .error: return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .content: return .blue
        case .tool: return .purple
        case .file: return .green
        case .system: return .gray
        case .error: return .red
        }
    }
}

// MARK: - NormalizedEvent Category Extension

extension NormalizedEvent {
    var category: EventCategory {
        switch self {
        case .assistantDelta, .assistantComplete, .thinkingDelta:
            return .content
        case .toolCallStarted, .toolCallComplete, .toolRequest, .toolDecision, .toolResult, .subagentSpawned, .subagentProgress, .subagentCompleted, .subagentFailed:
            return .tool
        case .fileDiffProduced, .fileWritten, .fileRead:
            return .file
        case .sessionStarted, .sessionEnded, .tokenUsage:
            return .system
        case .error:
            return .error
        case .raw:
            return .system
        case .turnPlanUpdated, .rateLimitsUpdated, .reasoningDelta, .toolOutputDelta, .fileDiffDelta:
            return .system
        case .reviewModeEntered, .reviewModeExited:
            return .system
        }
    }

    /// Brief description for timeline display
    var timelineDescription: String {
        switch self {
        case .thinkingDelta(let delta):
            let preview = String(delta.text.prefix(50))
            return "💭 " + preview + (delta.text.count > 50 ? "..." : "")
        case .assistantDelta(let delta):
            let preview = String(delta.text.prefix(50))
            return preview + (delta.text.count > 50 ? "..." : "")
        case .assistantComplete:
            return "Response complete"
        case .toolCallStarted(let started):
            return started.toolName
        case .toolCallComplete(let complete):
            return "\(complete.toolName) \(complete.succeeded ? "✓" : "✗")"
        case .toolRequest(let request):
            return "⏳ \(request.toolName) requested"
        case .toolDecision(let decision):
            return "🔐 \(decision.decision.rawValue)"
        case .toolResult(let result):
            return "\(result.toolName) \(result.succeeded ? "✓" : "✗")"
        case .subagentSpawned(let spawned):
            return "🤖 \(spawned.subagentType) spawned"
        case .subagentProgress(let progress):
            return "🤖 \(progress.message)"
        case .subagentCompleted(let completed):
            return "🤖 completed: \(completed.result.prefix(50))"
        case .subagentFailed(let failed):
            return "🤖 failed: \(failed.error.prefix(50))"
        case .fileDiffProduced(let diff):
            return URL(fileURLWithPath: diff.filePath).lastPathComponent
        case .fileWritten(let written):
            return URL(fileURLWithPath: written.filePath).lastPathComponent
        case .fileRead(let read):
            return URL(fileURLWithPath: read.filePath).lastPathComponent
        case .sessionStarted:
            return "Session started"
        case .sessionEnded(let ended):
            return "Session ended: \(ended.reason)"
        case .tokenUsage(let usage):
            return "\(usage.totalTokens) tokens"
        case .error(let error):
            return error.message
        case .raw(let raw):
            return raw.type
        case .turnPlanUpdated(let plan):
            return "Plan: \(plan.steps.count) steps"
        case .rateLimitsUpdated(let limits):
            let remaining = limits.primary?.remaining ?? limits.secondary?.remaining ?? 0
            return "Rate limits: \(remaining) remaining"
        case .reasoningDelta(let delta):
            let preview = String((delta.summaryDelta ?? delta.contentDelta ?? "").prefix(50))
            return "Reasoning: \(preview)"
        case .toolOutputDelta(let delta):
            let preview = String(delta.delta.prefix(50))
            return "Output: \(preview)"
        case .fileDiffDelta(let delta):
            let preview = String(delta.delta.prefix(50))
            return "Diff: \(preview)"
        case .reviewModeEntered(let entered):
            return "Review Mode: \(entered.pendingChanges.count) changes"
        case .reviewModeExited(let exited):
            return "Review \(exited.result.rawValue)"
        }
    }

    /// Timestamp of the event (alias for eventTimestamp for UI compatibility)
    var timestamp: Date {
        eventTimestamp
    }

    /// Duration if applicable (for tool calls)
    var duration: TimeInterval? {
        switch self {
        case .toolCallComplete(let complete):
            return complete.duration
        default:
            return nil
        }
    }
}

// MARK: - Event Count Badge

/// Small badge showing count of events in a category
struct EventCountBadge: View {
    let category: EventCategory
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.system(size: 10))
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            isSelected
                ? category.color.opacity(0.15)
                : Color(.separatorColor).opacity(0.3)
        )
        .foregroundStyle(isSelected ? category.color : .secondary)
        .clipShape(Capsule())
    }
}

// MARK: - Timeline Event Row

/// Single row in the timeline showing an event
struct TimelineEventRow: View {
    let envelope: EventEnvelope
    var onTap: (() -> Void)?

    @State private var isHovered: Bool = false

    private var category: EventCategory {
        envelope.event.category
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 8) {
                // Category indicator
                Circle()
                    .fill(category.color)
                    .frame(width: 6, height: 6)

                // Icon
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(category.color)
                    .frame(width: 16)

                // Description
                VStack(alignment: .leading, spacing: 2) {
                    Text(envelope.event.timelineDescription)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    // Duration for tools, or timestamp
                    HStack(spacing: 4) {
                        Text(envelope.timestamp, style: .time)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)

                        if let duration = envelope.event.duration {
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Text(formatDuration(duration))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Jump indicator on hover
                if isHovered {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color(.selectedContentBackgroundColor).opacity(0.3) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
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

// MARK: - Duration Histogram

/// Visual histogram showing distribution of tool execution durations
struct DurationHistogram: View {
    let events: [EventEnvelope]

    // Duration buckets: <100ms, 100-500ms, 500ms-1s, 1-5s, 5-30s, >30s
    private let bucketLabels = ["<100ms", "100-500ms", "0.5-1s", "1-5s", "5-30s", ">30s"]

    private var buckets: [Int] {
        var counts = Array(repeating: 0, count: 6)

        for envelope in events {
            if let duration = envelope.event.duration {
                let index: Int
                switch duration {
                case ..<0.1: index = 0
                case 0.1..<0.5: index = 1
                case 0.5..<1: index = 2
                case 1..<5: index = 3
                case 5..<30: index = 4
                default: index = 5
                }
                counts[index] += 1
            }
        }

        return counts
    }

    private var maxCount: Int {
        buckets.max() ?? 1
    }

    private var hasData: Bool {
        buckets.contains { $0 > 0 }
    }

    var body: some View {
        if hasData {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(buckets.enumerated()), id: \.offset) { index, count in
                    VStack(spacing: 2) {
                        // Bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.purple.opacity(0.6))
                            .frame(height: count > 0 ? max(4, CGFloat(count) / CGFloat(maxCount) * 50) : 0)

                        // Label
                        Text(bucketLabels[index])
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        // Count
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        } else {
            VStack {
                Text("No duration data")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Previews

#Preview("Timeline Sidebar") {
    let events = [
        EventEnvelope(
            sessionId: UUID(),
            sequence: 1,
            event: .sessionStarted(SessionStartedEvent(sessionId: "test", engineType: "claude", timestamp: Date()))
        ),
        EventEnvelope(
            sessionId: UUID(),
            sequence: 2,
            event: .assistantDelta(AssistantDelta(text: "Hello! I can help you with that.", timestamp: Date()))
        ),
        EventEnvelope(
            sessionId: UUID(),
            sequence: 3,
            event: .toolCallStarted(ToolCallStarted(toolCallId: "1", toolName: "Read", input: "/path/to/file.swift", timestamp: Date()))
        ),
        EventEnvelope(
            sessionId: UUID(),
            sequence: 4,
            event: .toolCallComplete(ToolCallComplete(toolCallId: "1", toolName: "Read", output: "file contents", error: nil, duration: 0.234, timestamp: Date()))
        ),
        EventEnvelope(
            sessionId: UUID(),
            sequence: 5,
            event: .fileDiffProduced(FileDiffProduced(filePath: "/src/main.swift", diff: "+line", hunks: [], timestamp: Date()))
        ),
        EventEnvelope(
            sessionId: UUID(),
            sequence: 6,
            event: .error(ErrorEvent(code: "E001", message: "Permission denied", isRecoverable: true, timestamp: Date()))
        ),
    ]

    return TimelineSidebarView(sessionId: UUID(), events: events)
        .frame(width: 300, height: 500)
}

#Preview("Event Count Badges") {
    HStack {
        EventCountBadge(category: .tool, count: 12, isSelected: true)
        EventCountBadge(category: .file, count: 5, isSelected: false)
        EventCountBadge(category: .error, count: 2, isSelected: true)
    }
    .padding()
}

#Preview("Duration Histogram") {
    let events = (0..<20).map { i in
        EventEnvelope(
            sessionId: UUID(),
            sequence: i,
            event: .toolCallComplete(ToolCallComplete(
                toolCallId: "\(i)",
                toolName: "Test",
                output: nil,
                error: nil,
                duration: Double.random(in: 0.05...35),
                timestamp: Date()
            ))
        )
    }

    return DurationHistogram(events: events)
        .frame(width: 280, height: 80)
        .padding()
}

// MARK: - Event Detail Sheet

/// Sheet showing full details of a selected event
struct EventDetailSheet: View {
    let envelope: EventEnvelope
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: envelope.event.category.icon)
                    .font(.title2)
                    .foregroundStyle(envelope.event.category.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(eventTitle)
                        .font(.headline)
                    Text(envelope.timestamp, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    + Text(" at ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    + Text(envelope.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    eventContent
                }
                .padding()
            }
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: 600)
        .frame(minHeight: 300, idealHeight: 400, maxHeight: 600)
    }

    private var eventTitle: String {
        switch envelope.event {
        case .assistantDelta:
            return "Assistant Message"
        case .assistantComplete:
            return "Response Complete"
        case .thinkingDelta:
            return "Thinking"
        case .toolCallStarted(let started):
            return "Tool: \(started.toolName)"
        case .toolCallComplete(let complete):
            return "Tool Complete: \(complete.toolName)"
        case .toolRequest(let request):
            return "Tool Request: \(request.toolName)"
        case .toolDecision(let decision):
            return "Tool Decision: \(decision.decision.rawValue)"
        case .toolResult(let result):
            return "Tool Result: \(result.toolName)"
        case .subagentSpawned(let spawned):
            return "Subagent: \(spawned.subagentType)"
        case .subagentProgress:
            return "Subagent Progress"
        case .subagentCompleted:
            return "Subagent Completed"
        case .subagentFailed:
            return "Subagent Failed"
        case .fileDiffProduced(let diff):
            return "File Changed: \(URL(fileURLWithPath: diff.filePath).lastPathComponent)"
        case .fileWritten(let written):
            return "File Written: \(URL(fileURLWithPath: written.filePath).lastPathComponent)"
        case .fileRead(let read):
            return "File Read: \(URL(fileURLWithPath: read.filePath).lastPathComponent)"
        case .sessionStarted:
            return "Session Started"
        case .sessionEnded:
            return "Session Ended"
        case .tokenUsage:
            return "Token Usage"
        case .error(let error):
            return "Error: \(error.code)"
        case .raw(let raw):
            return "Raw: \(raw.type)"
        case .turnPlanUpdated(let plan):
            return "Turn Plan: \(plan.steps.count) steps"
        case .rateLimitsUpdated:
            return "Rate Limits Updated"
        case .reasoningDelta:
            return "Reasoning"
        case .toolOutputDelta:
            return "Tool Output"
        case .fileDiffDelta:
            return "File Diff"
        case .reviewModeEntered(let entered):
            return "Review Mode: \(entered.pendingChanges.count) changes"
        case .reviewModeExited(let exited):
            return "Review: \(exited.result.rawValue)"
        }
    }

    @ViewBuilder
    private var eventContent: some View {
        switch envelope.event {
        case .assistantDelta(let delta):
            DetailRow(label: "Text", value: delta.text, isCode: false)

        case .assistantComplete(let complete):
            DetailRow(label: "Full Text", value: complete.fullText, isCode: false)
            if let reason = complete.stopReason {
                DetailRow(label: "Stop Reason", value: reason.rawValue)
            }

        case .thinkingDelta(let delta):
            DetailRow(label: "Thinking", value: delta.text, isCode: false)

        case .toolCallStarted(let started):
            DetailRow(label: "Tool ID", value: started.toolCallId)
            DetailRow(label: "Tool Name", value: started.toolName)
            DetailRow(label: "Input", value: started.input, isCode: true)

        case .toolCallComplete(let complete):
            DetailRow(label: "Tool ID", value: complete.toolCallId)
            DetailRow(label: "Tool Name", value: complete.toolName)
            DetailRow(label: "Duration", value: formatDuration(complete.duration))
            DetailRow(label: "Succeeded", value: complete.succeeded ? "Yes" : "No")
            if let output = complete.output {
                DetailRow(label: "Output", value: output, isCode: true)
            }
            if let error = complete.error {
                DetailRow(label: "Error", value: error, isCode: true, isError: true)
            }

        case .toolRequest(let request):
            DetailRow(label: "Tool ID", value: request.toolCallId)
            DetailRow(label: "Tool Name", value: request.toolName)
            DetailRow(label: "Risk Level", value: request.riskLevel.rawValue)
            DetailRow(label: "Input", value: request.input, isCode: true)

        case .toolDecision(let decision):
            DetailRow(label: "Decision", value: decision.decision.rawValue)
            DetailRow(label: "Decided By", value: decision.decidedBy)
            if let rationale = decision.rationale {
                DetailRow(label: "Rationale", value: rationale)
            }

        case .toolResult(let result):
            DetailRow(label: "Tool ID", value: result.toolCallId)
            DetailRow(label: "Tool Name", value: result.toolName)
            DetailRow(label: "Duration", value: "\(result.durationMs)ms")
            DetailRow(label: "Succeeded", value: result.succeeded ? "Yes" : "No")
            if let output = result.output {
                DetailRow(label: "Output", value: output, isCode: true)
            }
            if let error = result.error {
                DetailRow(label: "Error", value: error, isCode: true, isError: true)
            }

        case .subagentSpawned(let spawned):
            DetailRow(label: "Tool Use ID", value: spawned.toolUseId)
            DetailRow(label: "Type", value: spawned.subagentType)
            DetailRow(label: "Description", value: spawned.description)
            DetailRow(label: "Prompt", value: spawned.prompt, isCode: false)

        case .subagentProgress(let progress):
            DetailRow(label: "Tool Use ID", value: progress.toolUseId)
            DetailRow(label: "Message", value: progress.message)

        case .subagentCompleted(let completed):
            DetailRow(label: "Tool Use ID", value: completed.toolUseId)
            DetailRow(label: "Result", value: completed.result, isCode: false)

        case .subagentFailed(let failed):
            DetailRow(label: "Tool Use ID", value: failed.toolUseId)
            DetailRow(label: "Error", value: failed.error, isCode: false, isError: true)

        case .fileDiffProduced(let diff):
            DetailRow(label: "File Path", value: diff.filePath)
            DetailRow(label: "Diff", value: diff.diff, isCode: true)

        case .fileWritten(let written):
            DetailRow(label: "File Path", value: written.filePath)
            DetailRow(label: "Bytes Written", value: "\(written.bytesWritten)")

        case .fileRead(let read):
            DetailRow(label: "File Path", value: read.filePath)
            DetailRow(label: "Bytes Read", value: "\(read.bytesRead)")

        case .sessionStarted(let started):
            DetailRow(label: "Session ID", value: started.sessionId)
            DetailRow(label: "Engine Type", value: started.engineType)

        case .sessionEnded(let ended):
            DetailRow(label: "Session ID", value: ended.sessionId)
            DetailRow(label: "Reason", value: ended.reason)

        case .tokenUsage(let usage):
            DetailRow(label: "Input Tokens", value: "\(usage.inputTokens)")
            DetailRow(label: "Output Tokens", value: "\(usage.outputTokens)")
            if let cacheRead = usage.cacheReadTokens {
                DetailRow(label: "Cache Read", value: "\(cacheRead)")
            }
            if let cacheWrite = usage.cacheWriteTokens {
                DetailRow(label: "Cache Write", value: "\(cacheWrite)")
            }
            DetailRow(label: "Total", value: "\(usage.totalTokens)")

        case .error(let error):
            DetailRow(label: "Code", value: error.code)
            DetailRow(label: "Message", value: error.message, isError: true)
            DetailRow(label: "Recoverable", value: error.isRecoverable ? "Yes" : "No")

        case .raw(let raw):
            DetailRow(label: "Type", value: raw.type)
            if !raw.payload.isEmpty, let str = String(data: raw.payload, encoding: .utf8) {
                DetailRow(label: "Payload", value: str, isCode: true)
            }

        case .turnPlanUpdated(let plan):
            DetailRow(label: "Turn ID", value: plan.turnId)
            DetailRow(label: "Explanation", value: plan.explanation)
            ForEach(plan.steps) { step in
                DetailRow(label: "Step: \(step.id)", value: "\(step.status.rawValue) - \(step.description)")
            }

        case .rateLimitsUpdated(let limits):
            if let primary = limits.primary {
                DetailRow(label: "Primary Model", value: primary.model)
                DetailRow(label: "Remaining", value: "\(primary.remaining)")
            }
            if let secondary = limits.secondary {
                DetailRow(label: "Secondary Model", value: secondary.model)
                DetailRow(label: "Remaining", value: "\(secondary.remaining)")
            }

        case .reasoningDelta(let delta):
            DetailRow(label: "Item ID", value: delta.itemId)
            if let summary = delta.summaryDelta {
                DetailRow(label: "Summary", value: summary)
            }
            if let content = delta.contentDelta {
                DetailRow(label: "Content", value: content)
            }

        case .toolOutputDelta(let delta):
            DetailRow(label: "Item ID", value: delta.itemId)
            DetailRow(label: "Delta", value: delta.delta, isCode: true)

        case .fileDiffDelta(let delta):
            DetailRow(label: "Item ID", value: delta.itemId)
            DetailRow(label: "Diff Delta", value: delta.delta, isCode: true)

        case .reviewModeEntered(let entered):
            DetailRow(label: "Review ID", value: entered.reviewId)
            DetailRow(label: "Reason", value: entered.reason)
            DetailRow(label: "Pending Changes", value: "\(entered.pendingChanges.count) files")
            ForEach(Array(entered.pendingChanges.enumerated()), id: \.offset) { index, change in
                DetailRow(label: "  \(index + 1). \(change.changeType)", value: change.filePath)
            }

        case .reviewModeExited(let exited):
            DetailRow(label: "Review ID", value: exited.reviewId)
            DetailRow(label: "Result", value: exited.result.rawValue)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.2fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    var isCode: Bool = false
    var isError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if isCode {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(value)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(isError ? Color.red : Color.primary)
                        .textSelection(.enabled)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.textBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(isError ? Color.red : Color.primary)
                    .textSelection(.enabled)
            }
        }
    }
}
