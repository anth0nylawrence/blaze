import SwiftUI

// MARK: - Hook Test Panel View

/// Interactive panel for testing hook execution with mock input data.
///
/// Provides:
/// - JSON input editor for mock hook input
/// - Run button to execute hook via HookTestRunner
/// - Output display with stdout, stderr, and timing
/// - Status indicators for running/success/failure/timeout
/// - History of recent test runs
///
/// **E005-F009-S002-T003-A001**
public struct HookTestPanelView: View {
    let hook: Hook

    @State private var inputJSON: String = ""
    @State private var testResults: [HookExecutionTestResult] = []
    @State private var currentRun: HookExecutionTestResult?
    @State private var isRunning = false

    private let maxHistoryCount = 10
    private let testRunner = HookTestRunner()

    public init(hook: Hook) {
        self.hook = hook
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    // Input section
                    inputSection

                    // Run controls
                    controlsSection

                    // Current run output
                    if let run = currentRun {
                        outputSection(for: run)
                    }

                    // History section
                    if !testResults.isEmpty {
                        historySection
                    }
                }
                .padding(DSSpacing.md)
            }
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: 600)
        .background(Color.ds.bg0)
        .onAppear {
            inputJSON = generateDefaultInput()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 18))
                .foregroundStyle(Color.ds.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Test Hook")
                    .dsTextStyle(.subtitle)

                Text(hook.name)
                    .dsTextStyle(.caption, color: .ds.secondary)
            }

            Spacer()

            // Hook type badge
            HStack(spacing: DSSpacing.xxs) {
                Image(systemName: hook.scriptType.icon)
                    .font(.system(size: 11))
                Text(hook.scriptType.displayName)
                    .dsTextStyle(.micro)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)
            .background(Color.ds.bg1)
            .cornerRadius(DSRadius.sm)
        }
        .padding(DSSpacing.md)
        .background(Color.ds.bg1)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        FormSection(
            title: "Input Data",
            description: "JSON input to pass to the hook via stdin"
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Template selector
                HStack {
                    Text("Template:")
                        .dsTextStyle(.caption, color: .ds.secondary)

                    Spacer()

                    Menu {
                        ForEach(HookInputTemplateType.allCases, id: \.self) { template in
                            Button(template.displayName) {
                                inputJSON = template.generateJSON()
                            }
                        }
                    } label: {
                        Label("Select Template", systemImage: "doc.text")
                            .dsTextStyle(.caption)
                    }
                    .menuStyle(.borderlessButton)

                    Button {
                        inputJSON = formatJSON(inputJSON)
                    } label: {
                        Image(systemName: "text.alignleft")
                    }
                    .buttonStyle(.borderless)
                    .help("Format JSON")
                }

                // JSON editor
                TextEditor(text: $inputJSON)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 120, maxHeight: 200)
                    .padding(DSSpacing.sm)
                    .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .stroke(jsonValidationColor, lineWidth: 1)
                    )

                // Validation status
                HStack(spacing: DSSpacing.xxs) {
                    if isValidJSON {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.ds.positive)
                        Text("Valid JSON")
                            .dsTextStyle(.micro, color: .ds.positive)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.ds.warning)
                        Text("Invalid JSON")
                            .dsTextStyle(.micro, color: .ds.warning)
                    }
                }
            }
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        HStack(spacing: DSSpacing.md) {
            GlassButton(
                "Run Test",
                icon: "play.fill",
                style: .primary,
                isLoading: isRunning,
                isDisabled: !isValidJSON || !hook.hasScript
            ) {
                Task {
                    await runTest()
                }
            }

            if !hook.hasScript {
                HStack(spacing: DSSpacing.xxs) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.ds.warning)
                    Text("No script configured")
                        .dsTextStyle(.caption, color: .ds.warning)
                }
            }

            Spacer()

            if !testResults.isEmpty {
                Button {
                    Task {
                        await testRunner.clearHistory()
                    }
                    testResults.removeAll()
                    currentRun = nil
                } label: {
                    Label("Clear History", systemImage: "trash")
                        .dsTextStyle(.caption, color: .ds.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Output Section

    @ViewBuilder
    private func outputSection(for run: HookExecutionTestResult) -> some View {
        FormSection(
            title: "Output",
            description: "Results from the most recent test run"
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                // Status row
                HStack(spacing: DSSpacing.sm) {
                    statusIndicator(for: run.status)

                    Spacer()

                    // Timing
                    HStack(spacing: DSSpacing.xxs) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(run.formattedDuration)
                    }
                    .dsTextStyle(.mono, color: .ds.secondary)

                    // Exit code
                    if let exitCode = run.exitCode {
                        HStack(spacing: DSSpacing.xxs) {
                            Text("Exit:")
                            Text("\(exitCode)")
                                .foregroundStyle(exitCode == 0 ? Color.ds.positive : Color.ds.negative)
                        }
                        .dsTextStyle(.mono)
                    }
                }

                // Stdout
                if let stdout = run.stdout, !stdout.isEmpty {
                    outputBlock(title: "stdout", content: stdout, icon: "arrow.right.doc")
                }

                // Stderr
                if let stderr = run.stderr, !stderr.isEmpty {
                    outputBlock(title: "stderr", content: stderr, icon: "exclamationmark.bubble", isError: true)
                }

                // Error message
                if let error = run.error {
                    outputBlock(title: "error", content: error, icon: "exclamationmark.triangle.fill", isError: true)
                }

                // Empty output message
                if (run.stdout ?? "").isEmpty && (run.stderr ?? "").isEmpty && run.error == nil {
                    HStack {
                        Spacer()
                        Text("No output")
                            .dsTextStyle(.caption, color: .ds.tertiary)
                        Spacer()
                    }
                    .padding(DSSpacing.md)
                }
            }
        }
    }

    @ViewBuilder
    private func outputBlock(title: String, content: String, icon: String, isError: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .dsTextStyle(.caption, weight: .medium)
            }
            .foregroundStyle(isError ? Color.ds.negative : Color.ds.secondary)

            ScrollView(.vertical, showsIndicators: true) {
                Text(content)
                    .dsTextStyle(.monoSmall)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 150)
            .padding(DSSpacing.sm)
            .background(Color.ds.bg0)
            .cornerRadius(DSRadius.sm)
        }
    }

    @ViewBuilder
    private func statusIndicator(for status: TestRunnerResultStatus) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: status.icon)
                .foregroundStyle(statusColor(for: status))
            Text(status.displayName)
                .dsTextStyle(.body, color: statusColor(for: status))
        }
    }

    private func statusColor(for status: TestRunnerResultStatus) -> Color {
        switch status {
        case .passed: return Color.ds.positive
        case .failed, .error: return Color.ds.negative
        case .timedOut: return Color.ds.warning
        case .cancelled: return Color.ds.tertiary
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        FormSection(
            title: "Test History",
            description: "Previous \(min(testResults.count, maxHistoryCount)) test runs"
        ) {
            VStack(spacing: DSSpacing.xs) {
                ForEach(testResults.prefix(maxHistoryCount), id: \.id) { run in
                    historyRow(for: run)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            currentRun = run
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func historyRow(for run: HookExecutionTestResult) -> some View {
        HStack(spacing: DSSpacing.sm) {
            // Status icon
            Image(systemName: run.status.icon)
                .foregroundStyle(statusColor(for: run.status))
                .font(.system(size: 12))

            // Timestamp
            Text(formatTimestamp(run.startedAt))
                .dsTextStyle(.monoSmall, color: .ds.secondary)

            Spacer()

            // Duration
            Text(run.formattedDuration)
                .dsTextStyle(.monoSmall, color: .ds.tertiary)

            // Exit code
            if let exitCode = run.exitCode {
                Text("[\(exitCode)]")
                    .dsTextStyle(.monoSmall, color: exitCode == 0 ? .ds.positive : .ds.negative)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(
            currentRun?.id == run.id
                ? Color.ds.accent.opacity(0.1)
                : Color.clear
        )
        .cornerRadius(DSRadius.sm)
    }

    // MARK: - Actions

    private func runTest() async {
        guard isValidJSON else { return }

        isRunning = true

        // Determine the event type from hook
        let eventType = mapHookEventType(hook.eventType)

        // Execute the test
        let result = await testRunner.test(
            hook: hook,
            mockInput: HookMockInput(
                eventType: eventType,
                json: inputJSON,
                description: "Custom test input"
            )
        )

        currentRun = result
        testResults.insert(result, at: 0)

        // Trim history
        if testResults.count > maxHistoryCount {
            testResults = Array(testResults.prefix(maxHistoryCount))
        }

        isRunning = false
    }

    /// Map internal HookEventType to CLI HookEventType.
    private func mapHookEventType(_ eventType: HookEventType) -> CLIHookEventType {
        switch eventType {
        case .preToolCall: return .preToolUse
        case .postToolCall: return .postToolUse
        case .sessionStart: return .sessionStart
        case .sessionEnd, .turnEnd: return .stop
        case .preFileWrite, .preFileDelete: return .preToolUse
        case .postFileWrite, .postFileDelete: return .postToolUse
        case .turnStart: return .sessionStart
        case .toolApproved, .toolRejected: return .permissionRequest
        case .preCommit, .postCommit: return .stop
        }
    }

    // MARK: - Helpers

    private var isValidJSON: Bool {
        guard !inputJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true // Empty is valid (will use defaults)
        }
        guard let data = inputJSON.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private var jsonValidationColor: Color {
        if inputJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Color.ds.border
        }
        return isValidJSON ? Color.ds.positive.opacity(0.5) : Color.ds.warning.opacity(0.5)
    }

    private func formatJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: formatted, encoding: .utf8) else {
            return json
        }
        return result
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func generateDefaultInput() -> String {
        HookInputTemplateType.preToolUse.generateJSON()
    }
}

// MARK: - Hook Input Template Type

/// Pre-defined input templates for different hook event types.
private enum HookInputTemplateType: String, CaseIterable {
    case preToolUse
    case postToolUse
    case sessionStart
    case stop
    case userPromptSubmit
    case preCompact
    case empty

    var displayName: String {
        switch self {
        case .preToolUse: return "PreToolUse"
        case .postToolUse: return "PostToolUse"
        case .sessionStart: return "SessionStart"
        case .stop: return "Stop"
        case .userPromptSubmit: return "UserPromptSubmit"
        case .preCompact: return "PreCompact"
        case .empty: return "Empty Object"
        }
    }

    func generateJSON() -> String {
        let sessionId = UUID().uuidString
        let projectPath = "/Users/test/project"

        switch self {
        case .preToolUse:
            return """
            {
              "tool_name": "Bash",
              "tool_input": {
                "command": "echo 'Hello World'"
              },
              "session_id": "\(sessionId)",
              "project_path": "\(projectPath)"
            }
            """

        case .postToolUse:
            return """
            {
              "tool_name": "Read",
              "tool_input": {
                "file_path": "/src/main.swift"
              },
              "tool_output": "file contents...",
              "tool_error": null,
              "duration_ms": 42,
              "session_id": "\(sessionId)",
              "project_path": "\(projectPath)"
            }
            """

        case .sessionStart:
            return """
            {
              "session_id": "\(sessionId)",
              "project_path": "\(projectPath)",
              "type": "start",
              "cwd": "\(projectPath)"
            }
            """

        case .stop:
            return """
            {
              "stop_reason": "end_of_turn",
              "session_id": "\(sessionId)",
              "project_path": "\(projectPath)",
              "turn_count": 5
            }
            """

        case .userPromptSubmit:
            return """
            {
              "prompt": "Fix the bug in main.swift",
              "session_id": "\(sessionId)",
              "project_path": "\(projectPath)"
            }
            """

        case .preCompact:
            return """
            {
              "session_id": "\(sessionId)",
              "project_path": "\(projectPath)",
              "token_count": 180000,
              "token_limit": 200000
            }
            """

        case .empty:
            return "{}"
        }
    }
}

// MARK: - HookScriptType Icon Extension

extension HookScriptType {
    var icon: String {
        switch self {
        case .shell: return "terminal"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .node: return "globe"
        case .applescript: return "applescript"
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Hook Test Panel - Placeholder") {
    // Note: Full preview requires a real Hook, which needs database setup
    VStack {
        Text("HookTestPanelView Preview")
            .dsTextStyle(.title)

        Text("Pass a Hook instance to use the panel")
            .dsTextStyle(.caption, color: .ds.secondary)
    }
    .frame(width: 500, height: 400)
    .background(Color.ds.bg0)
}

#Preview("Status Indicators") {
    VStack(spacing: DSSpacing.md) {
        // Passed
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.ds.positive)
            Text("Passed")
                .dsTextStyle(.body, color: .ds.positive)
        }

        // Failed
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color.ds.negative)
            Text("Failed")
                .dsTextStyle(.body, color: .ds.negative)
        }

        // Timed Out
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .foregroundStyle(Color.ds.warning)
            Text("Timed Out")
                .dsTextStyle(.body, color: .ds.warning)
        }

        // Cancelled
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "stop.circle.fill")
                .foregroundStyle(Color.ds.tertiary)
            Text("Cancelled")
                .dsTextStyle(.body, color: .ds.tertiary)
        }

        // Error
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.ds.negative)
            Text("Error")
                .dsTextStyle(.body, color: .ds.negative)
        }
    }
    .padding()
    .background(Color.ds.bg0)
}
#endif
