import SwiftUI

/// Collapsible block showing subagent in chat timeline
struct SubagentBlockView: View {
    let correlation: SubagentCorrelation
    let events: [NormalizedEvent]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: always visible
            HStack {
                Image(systemName: subagentIcon)
                Text(correlation.subagentType)
                    .font(.headline)
                Text("- \(correlation.description)")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                StatusBadge(status: correlation.status)
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)

            // Collapsible content
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                        SubagentEventRow(event: event)
                            .padding(.leading, 24)
                    }
                }
            }

            // Result summary (always visible if completed)
            if correlation.status == .completed, let tokens = correlation.tokenUsage {
                HStack {
                    Text("Result: \(tokens.totalTokens) tokens")
                    if let duration = tokens.durationMs {
                        Text("• \(duration)ms")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }

    var subagentIcon: String {
        switch correlation.subagentType {
        case "Explore": return "magnifyingglass"
        case "Plan": return "list.bullet.clipboard"
        default: return "cpu"
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: SubagentStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }

    var backgroundColor: Color {
        switch status {
        case .running: return .blue
        case .queued: return .gray
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

// MARK: - Subagent Event Row

struct SubagentEventRow: View {
    let event: NormalizedEvent

    var body: some View {
        HStack {
            Circle().fill(Color.secondary).frame(width: 6, height: 6)
            Text(eventDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var eventDescription: String {
        switch event {
        case .subagentProgress(let p): return p.message
        case .toolCallStarted(let t): return "Tool: \(t.toolName)"
        default: return event.eventType.rawValue
        }
    }
}
