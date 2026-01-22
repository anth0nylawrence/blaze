import SwiftUI

// MARK: - Duration Formatting

extension TimeInterval {
    /// Formats a time interval into a human-readable duration string.
    /// Examples: "230ms", "1.2s", "2m 15s", "1h 5m"
    var formattedDuration: String {
        if self < 1 {
            // Less than 1 second: show milliseconds
            let ms = Int(self * 1000)
            return "\(ms)ms"
        } else if self < 60 {
            // Less than 1 minute: show seconds with decimal
            if self < 10 {
                return String(format: "%.1fs", self)
            } else {
                return "\(Int(self))s"
            }
        } else if self < 3600 {
            // Less than 1 hour: show minutes and seconds
            let minutes = Int(self) / 60
            let seconds = Int(self) % 60
            if seconds > 0 {
                return "\(minutes)m \(seconds)s"
            } else {
                return "\(minutes)m"
            }
        } else {
            // 1 hour or more: show hours and minutes
            let hours = Int(self) / 3600
            let minutes = (Int(self) % 3600) / 60
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        }
    }
}

// MARK: - Hook Tooltip View

/// A tooltip view that displays hook execution details on hover.
/// Shows name, category, status, timing, and duration information.
struct HookTooltip: View {
    let event: HookTimelineEvent

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Hook name (bold)
            Text(event.name)
                .font(.headline)
                .foregroundStyle(.primary)

            // Category badge
            categoryBadge

            Divider()

            // Status with icon
            statusRow

            // Timing information
            VStack(alignment: .leading, spacing: 4) {
                // Start time
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Start:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Self.timeFormatter.string(from: event.startTime))
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                }

                // End time (if completed)
                if let endTime = event.endTime {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("End:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Self.timeFormatter.string(from: endTime))
                            .font(.caption.monospaced())
                            .foregroundStyle(.primary)
                    }
                }

                // Duration
                if let duration = event.duration {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Duration:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(duration.formattedDuration)
                            .font(.caption.monospaced())
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                } else if event.status == .running {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Duration:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Running...")
                            .font(.caption.italic())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 280, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    // MARK: - Subviews

    private var categoryBadge: some View {
        Text(event.category.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(categoryColor.opacity(0.2))
            .foregroundStyle(categoryColor)
            .clipShape(Capsule())
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.body)

            Text(event.status.displayName)
                .font(.subheadline)
                .foregroundStyle(statusColor)
        }
    }

    // MARK: - Colors

    private var categoryColor: Color {
        switch event.category {
        case .session: return .blue
        case .turn: return .purple
        case .tool: return .orange
        case .file: return .green
        case .git: return .cyan
        }
    }

    private var statusColor: Color {
        switch event.status {
        case .pending: return .secondary
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }

    private var statusIcon: String {
        switch event.status {
        case .pending: return "clock"
        case .running: return "hourglass"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "slash.circle"
        }
    }
}

// MARK: - Preview

#Preview("Completed Hook") {
    HookTooltip(event: HookTimelineEvent(
        name: "pre-commit-lint",
        category: .git,
        startTime: Date().addingTimeInterval(-2.3),
        endTime: Date(),
        status: .completed
    ))
    .padding()
}

#Preview("Running Hook") {
    HookTooltip(event: HookTimelineEvent(
        name: "session-start-continuity",
        category: .session,
        startTime: Date().addingTimeInterval(-0.5),
        status: .running
    ))
    .padding()
}

#Preview("Failed Hook") {
    HookTooltip(event: HookTimelineEvent(
        name: "post-file-write-validator",
        category: .file,
        startTime: Date().addingTimeInterval(-1.234),
        endTime: Date(),
        status: .failed
    ))
    .padding()
}
