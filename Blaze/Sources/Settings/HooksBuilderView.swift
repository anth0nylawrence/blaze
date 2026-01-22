import SwiftUI

struct HooksBuilderView: View {
    @State private var installedHooks: [InstalledHookSummary] = []
    @State private var filterEvent: String = "all"
    @State private var showCanvasEditor = false
    @State private var editingPipeline: HooksPipeline = HooksPipeline()
    @State private var selectedNodeId: UUID?
    @State private var isLoading = false

    // Canvas zoom/pan state
    @State private var canvasScale: CGFloat = 1.0
    @State private var canvasOffset: CGSize = .zero

    // Test results
    @State private var showTestResults = false
    @State private var testResults: HookTestResult?
    @State private var isTesting = false

    var body: some View {
        if showCanvasEditor {
            // Canvas editor mode
            canvasEditorView
        } else {
            // List mode
            listView
        }
    }

    // MARK: - List View

    @ViewBuilder
    private var listView: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                // Filter and Create button row
                HStack {
                    Picker("Filter", selection: $filterEvent) {
                        Text("All Events").tag("all")
                        Text("PreToolUse").tag("PreToolUse")
                        Text("PostToolUse").tag("PostToolUse")
                        Text("SessionStart").tag("SessionStart")
                    }
                    .pickerStyle(.menu)

                    Spacer()

                    Button("Create Hook") {
                        // Create a new empty pipeline and show editor
                        editingPipeline = HooksPipeline()
                        selectedNodeId = nil
                        showCanvasEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                if installedHooks.isEmpty && !isLoading {
                    // Empty state
                    VStack(spacing: DSSpacing.md) {
                        Image(systemName: "gearshape.2")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.ds.secondary)
                        Text("No hooks configured")
                            .font(.headline)
                        Text("Create one to automate actions")
                            .foregroundStyle(Color.ds.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DSSpacing.xxl)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(DSSpacing.xxl)
                } else {
                    FormSection(title: "Configured Hooks") {
                        ForEach(installedHooks) { hook in
                            Button {
                                openHookInEditor(hook)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                        Text(hook.eventName)
                                            .foregroundStyle(Color.ds.foreground)
                                        if let description = hook.description, !description.isEmpty {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundStyle(Color.ds.secondary)
                                                .lineLimit(2)
                                        } else if !hook.matcher.isEmpty {
                                            Text(hook.matcher.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundStyle(Color.ds.tertiary)
                                        }
                                    }
                                    Spacer()
                                    Text(hook.scope.rawValue.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, DSSpacing.xs)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.ds.accent.opacity(0.2)))
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Color.ds.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Click a hook to view its workflow")
                        .font(.caption)
                        .foregroundStyle(Color.ds.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, DSSpacing.sm)
                }
            }
            .padding(DSSpacing.lg)
        }
        .task {
            await loadHooks()
        }
    }

    // MARK: - Canvas Editor View

    @ViewBuilder
    private var canvasEditorView: some View {
        HStack(spacing: 0) {
            // Left: Node palette
            nodePalette
                .frame(width: 200)

            Divider()

            // Center: Canvas
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button {
                        showCanvasEditor = false
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }

                    Spacer()

                    Text("Hook Workflow Builder")
                        .font(.headline)

                    Spacer()

                    // Zoom controls
                    HStack(spacing: DSSpacing.xs) {
                        Button {
                            zoomOut()
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        .buttonStyle(.borderless)
                        .help("Zoom Out (⌘-)")

                        Text("\(Int(canvasScale * 100))%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 44)

                        Button {
                            zoomIn()
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        .buttonStyle(.borderless)
                        .help("Zoom In (⌘+)")

                        Divider()
                            .frame(height: 16)

                        Button {
                            fitToNodes()
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                        }
                        .buttonStyle(.borderless)
                        .help("Fit to Nodes")
                    }
                    .padding(.horizontal, DSSpacing.sm)

                    Button {
                        Task {
                            await testHook()
                        }
                    } label: {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Test", systemImage: "play.circle")
                        }
                    }
                    .disabled(isTesting || editingPipeline.nodes.isEmpty)
                    .help("Test this hook workflow")

                    Button("Save") {
                        Task {
                            await saveHook()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(DSSpacing.sm)
                .background(Color.ds.bg1)

                // Canvas
                HooksCanvas(
                    pipeline: $editingPipeline,
                    selectedNodeId: $selectedNodeId,
                    scale: $canvasScale,
                    offset: $canvasOffset
                )
            }
            .onAppear {
                // Reset canvas state when opening editor
                canvasScale = 1.0
                canvasOffset = .zero
            }

            Divider()

            // Right: Inspector
            inspectorPanel
                .frame(width: 300)
        }
        .sheet(isPresented: $showTestResults) {
            if let results = testResults {
                HookTestResultsView(results: results)
            }
        }
    }

    // MARK: - Node Palette

    @ViewBuilder
    private var nodePalette: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text("Nodes")
                    .font(.headline)
                    .padding(.horizontal, DSSpacing.sm)

                ForEach(HookNodeCategory.allCases, id: \.self) { category in
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        Text(category.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(Color.ds.secondary)
                            .padding(.horizontal, DSSpacing.sm)

                        ForEach(nodesForCategory(category), id: \.self) { nodeType in
                            paletteItem(for: nodeType)
                        }
                    }
                }
            }
            .padding(DSSpacing.sm)
        }
        .background(Color.ds.bg1)
    }

    private func nodesForCategory(_ category: HookNodeCategory) -> [HookNodeType] {
        HookNodeType.allCases.filter { $0.category == category }
    }

    @ViewBuilder
    private func paletteItem(for nodeType: HookNodeType) -> some View {
        Button {
            addNode(type: nodeType)
        } label: {
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: nodeType.icon)
                    .frame(width: 20)
                Text(nodeType.displayName)
                    .lineLimit(1)
                Spacer()
            }
            .padding(DSSpacing.xs)
            .background(Color.ds.surface.opacity(0.5))
            .cornerRadius(DSRadius.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inspector Panel

    @ViewBuilder
    private var inspectorPanel: some View {
        HookInspectorView(
            node: Binding(
                get: {
                    guard let id = selectedNodeId else { return nil }
                    return editingPipeline.nodes.first { $0.id == id }
                },
                set: { newNode in
                    guard let newNode = newNode,
                          let index = editingPipeline.nodes.firstIndex(where: { $0.id == newNode.id }) else { return }
                    editingPipeline.nodes[index] = newNode
                }
            ),
            onDelete: { nodeId in
                deleteNode(nodeId)
            }
        )
        .background(Color.ds.bg1)
    }

    // MARK: - Actions

    private func openHookInEditor(_ hook: InstalledHookSummary) {
        // Convert the installed hook back to a pipeline for visual editing
        editingPipeline = hook.toPipeline()
        selectedNodeId = nil
        canvasScale = 1.0
        canvasOffset = .zero
        showCanvasEditor = true

        // Auto-fit after a small delay to let the view layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            fitToNodes()
        }
    }

    private func addNode(type: HookNodeType) {
        let newNode = HookNode(
            type: type,
            eventType: type.category == .event ? type.rawValue : nil,
            position: CGPoint(
                x: 400 + CGFloat.random(in: -50...50),
                y: 300 + CGFloat.random(in: -50...50)
            )
        )
        editingPipeline.nodes.append(newNode)
        selectedNodeId = newNode.id
    }

    private func deleteNode(_ nodeId: UUID) {
        editingPipeline.nodes.removeAll { $0.id == nodeId }
        editingPipeline.connections.removeAll { $0.sourceNodeId == nodeId || $0.targetNodeId == nodeId }
        if selectedNodeId == nodeId {
            selectedNodeId = nil
        }
    }

    private func loadHooks() async {
        isLoading = true
        defer { isLoading = false }

        do {
            installedHooks = try await HooksInstallationService.shared.listInstalledHooks()
        } catch {
            print("Failed to load hooks: \(error)")
        }
    }

    private func saveHook() async {
        let errors = editingPipeline.validate()
        if !errors.isEmpty {
            print("Validation errors: \(errors.map { $0.message })")
            return
        }

        let compiled = editingPipeline.exportToSettings()
        do {
            try await HooksInstallationService.shared.installHooks(scope: .project, compiledHooks: compiled)
            showCanvasEditor = false
            await loadHooks()
        } catch {
            print("Failed to save hook: \(error)")
        }
    }

    // MARK: - Zoom Controls

    private func zoomIn() {
        let newScale = canvasScale * 1.25
        canvasScale = min(newScale, HooksCanvas.maxScale)
    }

    private func zoomOut() {
        let newScale = canvasScale / 1.25
        canvasScale = max(newScale, HooksCanvas.minScale)
    }

    private func resetZoom() {
        canvasScale = 1.0
        canvasOffset = .zero
    }

    private func fitToNodes() {
        guard !editingPipeline.nodes.isEmpty else {
            resetZoom()
            return
        }

        // Calculate bounding box of all nodes
        let nodeWidth: CGFloat = 200
        let nodeHeight: CGFloat = 80
        let padding: CGFloat = 50

        let minX = editingPipeline.nodes.map { $0.position.x - nodeWidth / 2 }.min() ?? 0
        let maxX = editingPipeline.nodes.map { $0.position.x + nodeWidth / 2 }.max() ?? 0
        let minY = editingPipeline.nodes.map { $0.position.y - nodeHeight / 2 }.min() ?? 0
        let maxY = editingPipeline.nodes.map { $0.position.y + nodeHeight / 2 }.max() ?? 0

        let contentWidth = (maxX - minX) + padding * 2
        let contentHeight = (maxY - minY) + padding * 2

        // Assume a reasonable viewport size (canvas will be ~800x500 typically)
        let viewportWidth: CGFloat = 800
        let viewportHeight: CGFloat = 500

        // Calculate scale to fit
        let scaleX = viewportWidth / contentWidth
        let scaleY = viewportHeight / contentHeight
        let fitScale = min(scaleX, scaleY, HooksCanvas.maxScale)

        canvasScale = max(fitScale, HooksCanvas.minScale)

        // Center the content
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        canvasOffset = CGSize(
            width: viewportWidth / 2 - centerX * canvasScale,
            height: viewportHeight / 2 - centerY * canvasScale
        )
    }

    // MARK: - Hook Testing

    private func testHook() async {
        isTesting = true
        defer { isTesting = false }

        var results = HookTestResult()

        // Validate pipeline first
        let validationErrors = editingPipeline.validate()
        if !validationErrors.isEmpty {
            results.validationErrors = validationErrors.map { $0.message }
            results.success = false
            testResults = results
            showTestResults = true
            return
        }

        // Find command nodes and test them
        let commandNodes = editingPipeline.nodes.filter { $0.type == .command }

        for node in commandNodes {
            guard let command = node.config["command"]?.value as? String else {
                results.nodeResults.append(HookTestResult.NodeResult(
                    nodeId: node.id,
                    nodeName: node.type.displayName,
                    success: false,
                    output: "No command configured"
                ))
                continue
            }

            // Test the command (dry run with echo)
            do {
                let output = try await runTestCommand(command)
                results.nodeResults.append(HookTestResult.NodeResult(
                    nodeId: node.id,
                    nodeName: "\(node.type.displayName): \(command.prefix(30))...",
                    success: true,
                    output: output
                ))
            } catch {
                results.nodeResults.append(HookTestResult.NodeResult(
                    nodeId: node.id,
                    nodeName: "\(node.type.displayName): \(command.prefix(30))...",
                    success: false,
                    output: error.localizedDescription
                ))
            }
        }

        results.success = results.nodeResults.allSatisfy { $0.success } && validationErrors.isEmpty
        testResults = results
        showTestResults = true
    }

    private func runTestCommand(_ command: String) async throws -> String {
        // Run the command and capture output
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "HookTest",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorOutput.isEmpty ? "Command failed with exit code \(process.terminationStatus)" : errorOutput]
            )
        }

        return output.isEmpty ? "(No output)" : output
    }
}

// MARK: - Hook Test Result

struct HookTestResult {
    var success: Bool = true
    var validationErrors: [String] = []
    var nodeResults: [NodeResult] = []

    struct NodeResult: Identifiable {
        let id = UUID()
        let nodeId: UUID
        let nodeName: String
        let success: Bool
        let output: String
    }
}

// MARK: - Hook Test Results View

struct HookTestResultsView: View {
    let results: HookTestResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: results.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(results.success ? Color.ds.positive : Color.ds.negative)
                    .font(.title2)

                Text(results.success ? "Test Passed" : "Test Failed")
                    .font(.headline)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color.ds.bg1)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    // Validation errors
                    if !results.validationErrors.isEmpty {
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            Label("Validation Errors", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.ds.warning)

                            ForEach(results.validationErrors, id: \.self) { error in
                                Text("• \(error)")
                                    .font(.caption)
                                    .foregroundStyle(Color.ds.secondary)
                            }
                        }
                        .padding()
                        .background(Color.ds.warning.opacity(0.1))
                        .cornerRadius(DSRadius.md)
                    }

                    // Node results
                    if !results.nodeResults.isEmpty {
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            Text("Command Results")
                                .font(.subheadline.bold())

                            ForEach(results.nodeResults) { result in
                                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                    HStack {
                                        Image(systemName: result.success ? "checkmark.circle" : "xmark.circle")
                                            .foregroundStyle(result.success ? Color.ds.positive : Color.ds.negative)
                                        Text(result.nodeName)
                                            .font(.caption.bold())
                                        Spacer()
                                    }

                                    Text(result.output)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(Color.ds.secondary)
                                        .padding(DSSpacing.xs)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.ds.surface)
                                        .cornerRadius(DSRadius.sm)
                                }
                                .padding()
                                .background(Color.ds.bg1)
                                .cornerRadius(DSRadius.md)
                            }
                        }
                    }

                    if results.nodeResults.isEmpty && results.validationErrors.isEmpty {
                        Text("No command nodes to test. Add a command action to your workflow.")
                            .font(.caption)
                            .foregroundStyle(Color.ds.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
        .background(Color.ds.bg0)
    }
}
