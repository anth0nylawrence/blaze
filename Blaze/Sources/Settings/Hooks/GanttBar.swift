import SwiftUI

// MARK: - Gantt Bar View

/// A colored bar representing a hook execution on the Gantt timeline.
/// Visual appearance reflects the event's category (color) and status (fill style).
struct GanttBar: View {
    let event: HookTimelineEvent
    let width: CGFloat

    // MARK: - Constants

    private static let cornerRadius: CGFloat = 4
    private static let barHeight: CGFloat = 20
    private static let minimumWidth: CGFloat = 4

    // MARK: - Body

    var body: some View {
        ZStack {
            // Base bar
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(fillStyle)
                .frame(width: effectiveWidth, height: Self.barHeight)

            // Failed status: add red border
            if event.status == .failed {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .strokeBorder(Color.red, lineWidth: 2)
                    .frame(width: effectiveWidth, height: Self.barHeight)
            }
        }
        .opacity(opacityForStatus)
        .modifier(PulsingModifier(isActive: event.status == .running))
    }

    // MARK: - Computed Properties

    /// Ensures minimum width for very short durations
    private var effectiveWidth: CGFloat {
        max(width, Self.minimumWidth)
    }

    /// Category-based bar color
    private var categoryColor: Color {
        switch event.category {
        case .session:
            return .blue
        case .turn:
            return .purple
        case .tool:
            return .orange
        case .file:
            return .green
        case .git:
            return .cyan
        }
    }

    /// Fill style based on status
    private var fillStyle: some ShapeStyle {
        categoryColor
    }

    /// Opacity for status indication
    private var opacityForStatus: Double {
        switch event.status {
        case .completed, .failed:
            return 1.0
        case .running:
            return 0.9
        case .pending:
            return 0.4
        case .cancelled:
            return 0.5
        }
    }
}

// MARK: - Pulsing Animation Modifier

/// Applies a pulsing animation for running status
private struct PulsingModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isActive && isPulsing ? 0.6 : 1.0)
            .animation(
                isActive
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear {
                if isActive {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                isPulsing = newValue
            }
    }
}

// MARK: - Preview

#Preview("GanttBar - All Categories") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(HookTimelineCategory.allCases, id: \.self) { category in
            HStack {
                Text(category.displayName)
                    .frame(width: 60, alignment: .leading)
                    .font(.caption)
                GanttBar(
                    event: HookTimelineEvent(
                        name: "Test Hook",
                        category: category,
                        status: .completed
                    ),
                    width: 120
                )
            }
        }
    }
    .padding()
}

#Preview("GanttBar - All Statuses") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(HookTimelineStatus.allCases, id: \.self) { status in
            HStack {
                Text(status.displayName)
                    .frame(width: 80, alignment: .leading)
                    .font(.caption)
                GanttBar(
                    event: HookTimelineEvent(
                        name: "Test Hook",
                        category: .tool,
                        status: status
                    ),
                    width: 120
                )
            }
        }
    }
    .padding()
}

#Preview("GanttBar - Variable Widths") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach([2, 4, 20, 60, 120, 200], id: \.self) { width in
            HStack {
                Text("\(width)pt")
                    .frame(width: 50, alignment: .leading)
                    .font(.caption)
                GanttBar(
                    event: HookTimelineEvent(
                        name: "Test Hook",
                        category: .session,
                        status: .completed
                    ),
                    width: CGFloat(width)
                )
            }
        }
    }
    .padding()
}
