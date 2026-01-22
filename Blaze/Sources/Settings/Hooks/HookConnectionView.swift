import SwiftUI

// MARK: - Hook Connection View

/// A visual representation of a connection between two hook nodes using a bezier curve.
/// Supports hover interaction and deletion.
public struct HookConnectionView: View {
    // MARK: - Properties

    let connection: HookConnection
    let sourcePosition: CGPoint
    let targetPosition: CGPoint
    let isHovered: Bool
    let onDelete: () -> Void

    // MARK: - Private State

    @State private var hovering = false

    // MARK: - Computed Properties

    /// Calculate the horizontal offset for bezier control points.
    /// Creates smooth S-curves based on the distance between points.
    private var horizontalOffset: CGFloat {
        min(100, abs(targetPosition.x - sourcePosition.x) * 0.4)
    }

    /// Source control point for the bezier curve.
    private var sourceControlPoint: CGPoint {
        CGPoint(
            x: sourcePosition.x + horizontalOffset,
            y: sourcePosition.y
        )
    }

    /// Target control point for the bezier curve.
    private var targetControlPoint: CGPoint {
        CGPoint(
            x: targetPosition.x - horizontalOffset,
            y: targetPosition.y
        )
    }

    /// The path for the bezier curve.
    private var curvePath: Path {
        Path { path in
            path.move(to: sourcePosition)
            path.addCurve(
                to: targetPosition,
                control1: sourceControlPoint,
                control2: targetControlPoint
            )
        }
    }

    /// The stroke color based on hover state.
    private var strokeColor: Color {
        (isHovered || hovering) ? Color.ds.accent : Color.ds.secondary
    }

    /// The stroke width based on hover state.
    private var strokeWidth: CGFloat {
        (isHovered || hovering) ? 3 : 2
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Invisible wide hit target for better tap detection
            curvePath
                .stroke(Color.clear, lineWidth: 12)
                .contentShape(curvePath.strokedPath(.init(lineWidth: 12)))
                .onTapGesture {
                    onDelete()
                }
                .onHover { hovering in
                    self.hovering = hovering
                }

            // Visible curve
            curvePath
                .stroke(strokeColor, lineWidth: strokeWidth)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .animation(.easeInOut(duration: 0.15), value: hovering)
                .animation(.easeInOut(duration: 0.2), value: sourcePosition)
                .animation(.easeInOut(duration: 0.2), value: targetPosition)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Hook Connection") {
    ZStack {
        Color.ds.bg0
            .ignoresSafeArea()

        VStack(spacing: 40) {
            // Short horizontal connection
            HookConnectionView(
                connection: HookConnection(
                    sourceNodeId: UUID(),
                    targetNodeId: UUID()
                ),
                sourcePosition: CGPoint(x: 100, y: 50),
                targetPosition: CGPoint(x: 300, y: 50),
                isHovered: false,
                onDelete: {}
            )

            // Vertical connection with S-curve
            HookConnectionView(
                connection: HookConnection(
                    sourceNodeId: UUID(),
                    targetNodeId: UUID()
                ),
                sourcePosition: CGPoint(x: 100, y: 150),
                targetPosition: CGPoint(x: 300, y: 250),
                isHovered: false,
                onDelete: {}
            )

            // Long horizontal connection
            HookConnectionView(
                connection: HookConnection(
                    sourceNodeId: UUID(),
                    targetNodeId: UUID()
                ),
                sourcePosition: CGPoint(x: 50, y: 350),
                targetPosition: CGPoint(x: 450, y: 350),
                isHovered: false,
                onDelete: {}
            )

            // Hovered state
            HookConnectionView(
                connection: HookConnection(
                    sourceNodeId: UUID(),
                    targetNodeId: UUID()
                ),
                sourcePosition: CGPoint(x: 100, y: 450),
                targetPosition: CGPoint(x: 300, y: 550),
                isHovered: true,
                onDelete: {}
            )
        }
        .frame(width: 500, height: 600)
    }
}
#endif
