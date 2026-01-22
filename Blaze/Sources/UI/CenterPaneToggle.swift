import SwiftUI

// MARK: - Center Pane Toggle

/// Segmented toggle control for switching between Chat and Files views
struct CenterPaneToggle: View {
    @Binding var mode: CenterPaneMode
    let hasOpenFiles: Bool

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            // Chat toggle button
            ToggleButton(
                icon: "bubble.left.and.bubble.right",
                label: "Chat",
                isSelected: mode == .chat,
                shortcut: "1"
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    mode = .chat
                }
            }

            // Files toggle button
            ToggleButton(
                icon: "doc.text",
                label: "Files",
                isSelected: mode == .files,
                shortcut: "2",
                badge: hasOpenFiles ? nil : nil // Could add file count badge here
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    mode = .files
                }
            }
        }
        .padding(2)
        .background(Color.ds.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md + 2, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.md + 2, style: .continuous)
                .stroke(Color.ds.border.opacity(0.3), lineWidth: 0.5)
        }
    }
}

// MARK: - Toggle Button

/// Individual button within the center pane toggle
private struct ToggleButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let shortcut: String
    var badge: Int?
    let action: () -> Void

    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))

                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.ds.accent.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .foregroundStyle(isSelected ? Color.ds.foreground : Color.ds.secondary)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                            .fill(Color.ds.surface)
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                            .fill(Color.ds.surface.opacity(0.3))
                    }
                }
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .help("\(label) (Cmd+\(shortcut))")
    }
}

// MARK: - Compact Toggle Variant

/// Minimal icon-only toggle for tight spaces
struct CenterPaneToggleCompact: View {
    @Binding var mode: CenterPaneMode

    var body: some View {
        HStack(spacing: 0) {
            CompactToggleButton(
                icon: "bubble.left.and.bubble.right",
                isSelected: mode == .chat,
                accessibilityLabel: "Chat View"
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    mode = .chat
                }
            }

            CompactToggleButton(
                icon: "rectangle.split.2x1",
                isSelected: mode == .split,
                accessibilityLabel: "Split View"
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    mode = .split
                }
            }

            CompactToggleButton(
                icon: "doc.text",
                isSelected: mode == .files,
                accessibilityLabel: "Files View"
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    mode = .files
                }
            }
        }
        .padding(2)
        .background(Color.ds.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm + 2, style: .continuous))
    }
}

/// Compact icon button for minimal toggle
private struct CompactToggleButton: View {
    let icon: String
    let isSelected: Bool
    let accessibilityLabel: String
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.ds.foreground : Color.ds.tertiary)
                .frame(width: DSSize.md, height: DSSize.md)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                                .fill(Color.ds.surface)
                        } else if isHovered {
                            RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                                .fill(Color.ds.surface.opacity(0.3))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Previews

#Preview("Center Pane Toggle") {
    struct PreviewWrapper: View {
        @State private var mode: CenterPaneMode = .chat

        var body: some View {
            VStack(spacing: DSSpacing.lg) {
                Text("Current Mode: \(mode.rawValue)")
                    .dsTextStyle(.body)

                CenterPaneToggle(mode: $mode, hasOpenFiles: true)

                CenterPaneToggle(mode: $mode, hasOpenFiles: false)

                CenterPaneToggleCompact(mode: $mode)
            }
            .padding(DSSpacing.xl)
            .frame(width: 400, height: 300)
            .background(AmbientGradientBackground.ghosttyBackground)
        }
    }

    return PreviewWrapper()
}

#Preview("Toggle States") {
    VStack(spacing: DSSpacing.md) {
        // Chat selected
        CenterPaneToggle(
            mode: .constant(.chat),
            hasOpenFiles: true
        )

        // Files selected
        CenterPaneToggle(
            mode: .constant(.files),
            hasOpenFiles: true
        )

        // Files selected, no open files
        CenterPaneToggle(
            mode: .constant(.files),
            hasOpenFiles: false
        )
    }
    .padding(DSSpacing.xl)
    .background(Color.ds.bg0)
}
