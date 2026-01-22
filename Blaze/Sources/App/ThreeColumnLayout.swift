import SwiftUI

// MARK: - Three Column Layout

/// Custom three-column layout that replaces NavigationSplitView to avoid
/// macOS sidebar vibrancy. Provides full control over backgrounds.
struct ThreeColumnLayout<Left: View, Center: View, Right: View>: View {
    @Binding var leftWidth: CGFloat
    @Binding var rightWidth: CGFloat
    @Binding var leftVisible: Bool
    @Binding var rightVisible: Bool

    let minLeftWidth: CGFloat
    let maxLeftWidth: CGFloat
    let minRightWidth: CGFloat
    let maxRightWidth: CGFloat
    let minCenterWidth: CGFloat

    @ViewBuilder let left: () -> Left
    @ViewBuilder let center: () -> Center
    @ViewBuilder let right: () -> Right

    @State private var isDraggingLeft = false
    @State private var isDraggingRight = false

    init(
        leftWidth: Binding<CGFloat>,
        rightWidth: Binding<CGFloat>,
        leftVisible: Binding<Bool> = .constant(true),
        rightVisible: Binding<Bool> = .constant(true),
        minLeftWidth: CGFloat = 200,
        maxLeftWidth: CGFloat = 350,
        minRightWidth: CGFloat = 250,
        maxRightWidth: CGFloat = 400,
        minCenterWidth: CGFloat = 400,
        @ViewBuilder left: @escaping () -> Left,
        @ViewBuilder center: @escaping () -> Center,
        @ViewBuilder right: @escaping () -> Right
    ) {
        self._leftWidth = leftWidth
        self._rightWidth = rightWidth
        self._leftVisible = leftVisible
        self._rightVisible = rightVisible
        self.minLeftWidth = minLeftWidth
        self.maxLeftWidth = maxLeftWidth
        self.minRightWidth = minRightWidth
        self.maxRightWidth = maxRightWidth
        self.minCenterWidth = minCenterWidth
        self.left = left
        self.center = center
        self.right = right
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left column
                if leftVisible {
                    left()
                        .frame(width: leftWidth)

                    // Left divider
                    ResizableDivider(
                        isDragging: $isDraggingLeft,
                        onDrag: { delta in
                            let newWidth = leftWidth + delta
                            leftWidth = min(max(newWidth, minLeftWidth), maxLeftWidth)
                        }
                    )
                }

                // Center column (flexible)
                center()
                    .frame(minWidth: minCenterWidth, maxWidth: .infinity)

                // Right column
                if rightVisible {
                    // Right divider
                    ResizableDivider(
                        isDragging: $isDraggingRight,
                        onDrag: { delta in
                            let newWidth = rightWidth - delta  // Invert for right side
                            rightWidth = min(max(newWidth, minRightWidth), maxRightWidth)
                        }
                    )

                    right()
                        .frame(width: rightWidth)
                }
            }
        }
        .background(.clear)  // No implicit materials!
    }
}

// MARK: - Resizable Divider

/// Draggable divider between columns
struct ResizableDivider: View {
    @Binding var isDragging: Bool
    let onDrag: (CGFloat) -> Void

    @State private var isHovered = false
    @State private var lastDragX: CGFloat = 0

    var body: some View {
        // Use fixed frame for reliable hit testing
        Color.clear
            .frame(width: 8)
            .contentShape(Rectangle())
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(isHovered || isDragging ? Color.accentColor : Color(.separatorColor).opacity(0.5))
                    .frame(width: isHovered || isDragging ? 4 : 1)
            }
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else if !isDragging {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            lastDragX = value.location.x
                        } else {
                            let delta = value.location.x - lastDragX
                            lastDragX = value.location.x
                            onDrag(delta)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastDragX = 0
                        if !isHovered {
                            NSCursor.pop()
                        }
                    }
            )
    }
}

// MARK: - Preview

#Preview("Three Column Layout") {
    struct PreviewWrapper: View {
        @State private var leftWidth: CGFloat = 280
        @State private var rightWidth: CGFloat = 300
        @State private var leftVisible = true
        @State private var rightVisible = true

        var body: some View {
            ThreeColumnLayout(
                leftWidth: $leftWidth,
                rightWidth: $rightWidth,
                leftVisible: $leftVisible,
                rightVisible: $rightVisible
            ) {
                // Left
                VStack {
                    Text("Left Panel")
                    Text("Width: \(Int(leftWidth))")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ds.surface.opacity(0.15))
            } center: {
                // Center
                VStack {
                    Text("Center Panel")
                    Button("Toggle Left") { leftVisible.toggle() }
                    Button("Toggle Right") { rightVisible.toggle() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ds.surface.opacity(0.15))
            } right: {
                // Right
                VStack {
                    Text("Right Panel")
                    Text("Width: \(Int(rightWidth))")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ds.surface.opacity(0.15))
            }
            .frame(width: 1000, height: 600)
            .background(Color.ds.bg0)
        }
    }

    return PreviewWrapper()
}
