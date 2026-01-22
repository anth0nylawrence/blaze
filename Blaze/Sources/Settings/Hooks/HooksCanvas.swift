import SwiftUI

// MARK: - Pending Connection

/// Tracks a connection being drawn from a source port.
private struct PendingConnection {
    let sourceNodeId: UUID
    let sourcePort: PortType
    var currentPoint: CGPoint
}

// MARK: - Hooks Canvas

/// Visual drag-drop canvas for the Hooks Builder.
/// Provides pan, zoom, node positioning, and connection drawing.
public struct HooksCanvas: View {
    // MARK: - Properties

    @Binding var pipeline: HooksPipeline
    @Binding var selectedNodeId: UUID?
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    // MARK: - Canvas State

    @State private var pendingConnection: PendingConnection?
    @State private var hoveredConnectionId: UUID?

    // MARK: - Drag State

    @State private var draggingNodeId: UUID?
    @State private var dragStartPosition: CGPoint?
    @State private var panStartOffset: CGSize?

    // MARK: - Constants

    public static let minScale: CGFloat = 0.25
    public static let maxScale: CGFloat = 2.0

    private let canvasSize: CGFloat = 2000
    private let gridSpacing: CGFloat = 20
    private let nodeWidth: CGFloat = 200

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid background
                gridBackground

                // Canvas content (nodes + connections)
                // Scale first around top-left, then offset - this matches fitToNodes() calculation
                canvasContent
                    .scaleEffect(scale, anchor: .topLeading)
                    .offset(offset)

                // Pending connection being drawn
                if let pending = pendingConnection {
                    pendingConnectionLine(from: pending)
                }

                // Onboarding hint when empty
                if pipeline.nodes.isEmpty {
                    emptyCanvasHint
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ds.bg0)
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = scale * value
                        scale = min(max(newScale, Self.minScale), Self.maxScale)
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        // Pan gesture (when not dragging a node)
                        if draggingNodeId == nil {
                            // Track start offset on first change
                            if panStartOffset == nil {
                                panStartOffset = offset
                            }
                            // Offset is in screen space (applied after scale), so use direct translation
                            if let startOffset = panStartOffset {
                                offset = CGSize(
                                    width: startOffset.width + value.translation.width,
                                    height: startOffset.height + value.translation.height
                                )
                            }
                        }
                    }
                    .onEnded { _ in
                        panStartOffset = nil
                    }
            )
            .onTapGesture {
                // Deselect node when clicking canvas
                selectedNodeId = nil
            }
        }
    }

    // MARK: - Grid Background

    @ViewBuilder
    private var gridBackground: some View {
        Canvas { context, size in
            let gridColor = Color.ds.gridLine.opacity(0.3)

            // Vertical lines
            var x: CGFloat = offset.width.truncatingRemainder(dividingBy: gridSpacing * scale)
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
                x += gridSpacing * scale
            }

            // Horizontal lines
            var y: CGFloat = offset.height.truncatingRemainder(dividingBy: gridSpacing * scale)
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
                y += gridSpacing * scale
            }
        }
    }

    // MARK: - Empty Canvas Hint

    @ViewBuilder
    private var emptyCanvasHint: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.secondary.opacity(0.5))

            Text("Start Building Your Hook")
                .font(.headline)
                .foregroundStyle(Color.ds.foreground)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                hintRow(number: "1", text: "Click a node from the palette on the left")
                hintRow(number: "2", text: "Drag from output port (right) to input port (left)")
                hintRow(number: "3", text: "Select a node to configure it in the inspector")
            }
            .padding(DSSpacing.md)
            .background(Color.ds.surface.opacity(0.5))
            .cornerRadius(DSRadius.md)

            Text("Tip: Hover over ports to see connection hints")
                .font(.caption)
                .foregroundStyle(Color.ds.tertiary)
        }
        .frame(maxWidth: 350)
        .padding(DSSpacing.xl)
    }

    @ViewBuilder
    private func hintRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(Color.ds.accent)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.ds.accent.opacity(0.2)))

            Text(text)
                .font(.caption)
                .foregroundStyle(Color.ds.secondary)
        }
    }

    // MARK: - Canvas Content

    @ViewBuilder
    private var canvasContent: some View {
        ZStack(alignment: .topLeading) {
            // Render all connections first (behind nodes)
            ForEach(pipeline.connections) { connection in
                if let sourceNode = pipeline.nodes.first(where: { $0.id == connection.sourceNodeId }),
                   let targetNode = pipeline.nodes.first(where: { $0.id == connection.targetNodeId }) {
                    HookConnectionView(
                        connection: connection,
                        sourcePosition: outputPortPosition(for: sourceNode),
                        targetPosition: inputPortPosition(for: targetNode),
                        isHovered: hoveredConnectionId == connection.id,
                        onDelete: {
                            deleteConnection(connection.id)
                        }
                    )
                    .onHover { hovering in
                        hoveredConnectionId = hovering ? connection.id : nil
                    }
                }
            }

            // Render all nodes
            ForEach(pipeline.nodes) { node in
                HookNodeView(
                    node: node,
                    isSelected: selectedNodeId == node.id,
                    onPortDragStart: { nodeId, _ in
                        startConnection(from: nodeId)
                    },
                    onPortDragUpdate: { position in
                        updatePendingConnection(to: position)
                    },
                    onPortDragEnd: { position in
                        tryCompleteConnection(at: position)
                    }
                )
                .position(node.position)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleNodeDrag(nodeId: node.id, value: value)
                        }
                        .onEnded { _ in
                            draggingNodeId = nil
                            dragStartPosition = nil
                        }
                )
                .onTapGesture {
                    selectedNodeId = node.id
                }
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .coordinateSpace(name: "hooksCanvas")
    }

    // MARK: - Pending Connection Line

    @ViewBuilder
    private func pendingConnectionLine(from pending: PendingConnection) -> some View {
        if let sourceNode = pipeline.nodes.first(where: { $0.id == pending.sourceNodeId }) {
            let sourcePos = outputPortPosition(for: sourceNode)
            let transformedSourcePos = transformPoint(sourcePos)
            let currentPos = pending.currentPoint

            Path { path in
                path.move(to: transformedSourcePos)
                path.addLine(to: currentPos)
            }
            .stroke(Color.ds.accent.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
        }
    }

    // MARK: - Port Position Helpers

    /// Calculate the absolute output port position for a node
    private func outputPortPosition(for node: HookNode) -> CGPoint {
        CGPoint(
            x: node.position.x + nodeWidth / 2 + 6,
            y: node.position.y
        )
    }

    /// Calculate the absolute input port position for a node
    private func inputPortPosition(for node: HookNode) -> CGPoint {
        CGPoint(
            x: node.position.x - nodeWidth / 2 - 6,
            y: node.position.y
        )
    }

    /// Transform a canvas point to screen coordinates (with offset and scale)
    private func transformPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * scale + offset.width,
            y: point.y * scale + offset.height
        )
    }

    // MARK: - Node Dragging

    private func handleNodeDrag(nodeId: UUID, value: DragGesture.Value) {
        if draggingNodeId == nil {
            draggingNodeId = nodeId
            if let node = pipeline.nodes.first(where: { $0.id == nodeId }) {
                dragStartPosition = node.position
            }
        }

        guard let startPos = dragStartPosition else { return }

        let newPosition = CGPoint(
            x: startPos.x + value.translation.width / scale,
            y: startPos.y + value.translation.height / scale
        )

        // Update node position in pipeline
        if let index = pipeline.nodes.firstIndex(where: { $0.id == nodeId }) {
            var updatedNode = pipeline.nodes[index]
            updatedNode.position = newPosition
            pipeline.nodes[index] = updatedNode
        }
    }

    // MARK: - Connection Management

    private func startConnection(from nodeId: UUID) {
        if let node = pipeline.nodes.first(where: { $0.id == nodeId }) {
            let sourcePos = outputPortPosition(for: node)
            pendingConnection = PendingConnection(
                sourceNodeId: nodeId,
                sourcePort: .output,
                currentPoint: transformPoint(sourcePos)
            )
        }
    }

    private func updatePendingConnection(to position: CGPoint) {
        pendingConnection?.currentPoint = position
    }

    private func tryCompleteConnection(at position: CGPoint) {
        guard let pending = pendingConnection else {
            pendingConnection = nil
            return
        }

        // Hit-test against all input ports
        let hitRadius: CGFloat = 25 // Generous hit target

        for node in pipeline.nodes {
            // Skip self-connections
            guard node.id != pending.sourceNodeId else { continue }

            // Calculate input port position in screen space
            let inputPos = inputPortPosition(for: node)
            let screenInputPos = transformPoint(inputPos)

            // Check distance
            let distance = hypot(position.x - screenInputPos.x, position.y - screenInputPos.y)

            if distance < hitRadius {
                // Found a target - create connection
                let newConnection = HookConnection(
                    sourceNodeId: pending.sourceNodeId,
                    targetNodeId: node.id
                )

                // Check if connection already exists
                let connectionExists = pipeline.connections.contains { conn in
                    conn.sourceNodeId == newConnection.sourceNodeId &&
                    conn.targetNodeId == newConnection.targetNodeId
                }

                if !connectionExists {
                    pipeline.connections.append(newConnection)
                }

                pendingConnection = nil
                return
            }
        }

        // No target found - cancel pending connection
        pendingConnection = nil
    }

    private func deleteConnection(_ connectionId: UUID) {
        pipeline.connections.removeAll { $0.id == connectionId }
    }
}

// MARK: - Preview

#if DEBUG
struct HooksCanvasPreview: View {
    @State private var pipeline = HooksPipeline(
        nodes: [
            HookNode(
                type: .postToolUse,
                eventType: "PostToolUse",
                config: ["matcher": AnyCodable(["*.swift"])],
                position: CGPoint(x: 200, y: 200)
            ),
            HookNode(
                type: .command,
                config: ["command": AnyCodable("test.sh")],
                position: CGPoint(x: 500, y: 200)
            ),
            HookNode(
                type: .logger,
                position: CGPoint(x: 800, y: 200)
            )
        ],
        connections: []
    )
    @State private var selectedNodeId: UUID?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        HooksCanvas(
            pipeline: $pipeline,
            selectedNodeId: $selectedNodeId,
            scale: $scale,
            offset: $offset
        )
        .frame(width: 800, height: 600)
    }
}

#Preview("Hooks Canvas") {
    HooksCanvasPreview()
}
#endif
