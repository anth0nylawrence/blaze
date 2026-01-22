import SwiftUI

// MARK: - Port Type

/// Port connection type for visual hook nodes
public enum PortType {
    case input
    case output
}

// MARK: - Hook Node View

/// Visual node card for the Hooks Builder pipeline editor.
/// Displays a glass-styled card with category-based accent colors,
/// input/output ports, and configuration summary.
public struct HookNodeView: View {
    let node: HookNode
    let isSelected: Bool
    let onPortDragStart: (UUID, PortType) -> Void
    let onPortDragUpdate: (CGPoint) -> Void
    let onPortDragEnd: (CGPoint) -> Void

    // MARK: - State

    @State private var isDraggingFromOutput = false

    // MARK: - Constants

    private let nodeWidth: CGFloat = 200
    private let portSize: CGFloat = 12
    private let portOffset: CGFloat = 6

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .center) {
            // Glass card background
            glassCard

            // Input port (left edge)
            inputPort

            // Output port (right edge)
            outputPort
        }
        .frame(width: nodeWidth)
    }

    // MARK: - Glass Card

    @ViewBuilder
    private var glassCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // Header: Icon + Title
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: node.type.icon)
                    .font(.system(size: DSSize.sm))
                    .foregroundStyle(categoryAccent)

                Text(node.type.displayName)
                    .dsTextStyle(.subtitle, weight: .medium)
                    .foregroundStyle(Color.ds.foreground)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            // Category badge
            categoryBadge

            // Config summary
            configSummary
        }
        .padding(DSSpacing.md)
        .frame(width: nodeWidth)
        .dsGlassPanel(
            level: .regular,
            cornerRadius: DSRadius.lg,
            elevation: isSelected ? .high : .medium,
            border: isSelected ? .layered : .standard,
            isInteractive: false
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(categoryAccent.opacity(0.6), lineWidth: 2)
            }
        }
    }

    // MARK: - Category Badge

    @ViewBuilder
    private var categoryBadge: some View {
        Text(node.type.category.rawValue.capitalized)
            .dsTextStyle(.micro, weight: .medium)
            .foregroundStyle(categoryAccent)
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, DSSpacing.xxs)
            .background(
                Capsule()
                    .fill(categoryAccent.opacity(0.15))
            )
    }

    // MARK: - Config Summary

    @ViewBuilder
    private var configSummary: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            if node.config.isEmpty {
                Text("Not configured")
                    .dsTextStyle(.caption, color: .ds.tertiary)
                    .italic()
            } else {
                ForEach(Array(node.config.keys.prefix(3)), id: \.self) { key in
                    if let value = node.config[key] {
                        configItem(key: key, value: value)
                    }
                }

                if node.config.count > 3 {
                    Text("+ \(node.config.count - 3) more...")
                        .dsTextStyle(.caption, color: .ds.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func configItem(key: String, value: AnyCodable) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.xxs) {
            Text("\(key):")
                .dsTextStyle(.caption, color: .ds.secondary, weight: .medium)

            Text(formatConfigValue(value))
                .dsTextStyle(.caption, color: .ds.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Ports

    @ViewBuilder
    private var inputPort: some View {
        Circle()
            .fill(categoryAccent)
            .frame(width: portSize, height: portSize)
            .overlay {
                Circle()
                    .stroke(Color.ds.bg0, lineWidth: 2)
            }
            .offset(x: -nodeWidth / 2 - portOffset)
            .help("Input: Drag a connection here from another node's output")
    }

    @ViewBuilder
    private var outputPort: some View {
        Circle()
            .fill(categoryAccent)
            .frame(width: portSize, height: portSize)
            .overlay {
                Circle()
                    .stroke(Color.ds.bg0, lineWidth: 2)
            }
            .offset(x: nodeWidth / 2 + portOffset)
            .help("Output: Drag from here to connect to another node")
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .named("hooksCanvas"))
                    .onChanged { value in
                        if !isDraggingFromOutput {
                            onPortDragStart(node.id, .output)
                            isDraggingFromOutput = true
                        }
                        onPortDragUpdate(value.location)
                    }
                    .onEnded { value in
                        onPortDragEnd(value.location)
                        isDraggingFromOutput = false
                    }
            )
    }

    // MARK: - Category Accent Color

    private var categoryAccent: Color {
        switch node.type.category {
        case .event:
            return .green
        case .action:
            return .blue
        case .filter:
            return .yellow
        case .control:
            return .purple
        case .transform:
            return .orange
        case .utility:
            return .gray
        }
    }

    // MARK: - Helpers

    /// Format config value for display
    private func formatConfigValue(_ value: AnyCodable) -> String {
        if let stringValue = value.value as? String {
            return stringValue
        } else if let arrayValue = value.value as? [Any] {
            return "[\(arrayValue.count) items]"
        } else if let dictValue = value.value as? [String: Any] {
            return "{\(dictValue.count) keys}"
        } else {
            return "\(value.value)"
        }
    }
}

// MARK: - Note
// AnyCodable is defined in Engine/NDJSONParser.swift and is reused here for config values

// MARK: - Previews

#if DEBUG
#Preview("Hook Node - Event") {
    let node = HookNode(
        type: .postToolUse,
        eventType: "PostToolUse",
        config: [
            "matcher": AnyCodable(["*.swift", "*.ts"]),
            "enabled": AnyCodable(true)
        ]
    )

    HookNodeView(
        node: node,
        isSelected: false,
        onPortDragStart: { _, _ in },
        onPortDragUpdate: { _ in },
        onPortDragEnd: { _ in }
    )
    .padding(DSSpacing.xl)
    .background(
        LinearGradient(
            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Hook Node - Action (Selected)") {
    let node = HookNode(
        type: .command,
        config: [
            "command": AnyCodable("bash .claude/hooks/test.sh"),
            "timeout": AnyCodable(30)
        ]
    )

    HookNodeView(
        node: node,
        isSelected: true,
        onPortDragStart: { _, _ in },
        onPortDragUpdate: { _ in },
        onPortDragEnd: { _ in }
    )
    .padding(DSSpacing.xl)
    .background(
        LinearGradient(
            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Hook Node - Not Configured") {
    let node = HookNode(
        type: .logger,
        config: [:]
    )

    HookNodeView(
        node: node,
        isSelected: false,
        onPortDragStart: { _, _ in },
        onPortDragUpdate: { _ in },
        onPortDragEnd: { _ in }
    )
    .padding(DSSpacing.xl)
    .background(
        LinearGradient(
            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("All Categories") {
    ScrollView {
        VStack(spacing: DSSpacing.lg) {
            ForEach([
                HookNode(type: .postToolUse, eventType: "PostToolUse"),
                HookNode(type: .command, config: ["command": AnyCodable("test.sh")]),
                HookNode(type: .matcher, config: ["pattern": AnyCodable("*.swift")]),
                HookNode(type: .decisionAllowDenyAsk),
                HookNode(type: .additionalContext),
                HookNode(type: .logger)
            ], id: \.id) { node in
                HookNodeView(
                    node: node,
                    isSelected: false,
                    onPortDragStart: { _, _ in },
                    onPortDragUpdate: { _ in },
                    onPortDragEnd: { _ in }
                )
            }
        }
        .padding(DSSpacing.xl)
    }
    .background(
        LinearGradient(
            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
#endif
