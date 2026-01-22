import SwiftUI

// MARK: - InstallationProgressView

/// Displays step-by-step installation progress for a CLI tool.
///
/// Shows current step indicator, progress bar, step description,
/// elapsed time, scrolling output log, and cancel button.
///
/// **E005-F005-S001-T005-A001**
public struct InstallationProgressView: View {
    /// Current installation progress state.
    public let progress: InstallProgress

    /// Name of the CLI being installed.
    public let cliName: String

    /// Error message if installation failed (nil if in progress).
    public let errorMessage: String?

    /// Called when user taps cancel.
    public let onCancel: () -> Void

    /// Maximum number of output lines to display.
    private let maxOutputLines: Int = 50

    /// Creates an installation progress view.
    /// - Parameters:
    ///   - progress: Current installation progress.
    ///   - cliName: Name of the CLI being installed.
    ///   - errorMessage: Optional error message for failure state.
    ///   - onCancel: Closure called when cancel is tapped.
    public init(
        progress: InstallProgress,
        cliName: String,
        errorMessage: String? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.progress = progress
        self.cliName = cliName
        self.errorMessage = errorMessage
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 20) {
            headerSection
            progressSection
            outputSection
            footerSection
        }
        .padding(24)
        .frame(minWidth: 400, maxWidth: 600)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: errorMessage != nil ? "exclamationmark.triangle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(errorMessage != nil ? .red : .accentColor)

            Text(errorMessage != nil ? "Installation Failed" : "Installing \(cliName)")
                .font(.title2)
                .fontWeight(.semibold)

            if errorMessage == nil {
                Text("Step \(progress.currentStep) of \(progress.totalSteps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var progressSection: some View {
        VStack(spacing: 12) {
            if let error = errorMessage {
                // Error state
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                // Progress bar
                ProgressView(value: progress.fractionComplete)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)

                // Step description
                Text(progress.stepDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Elapsed time
                Text(formattedElapsedTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Output")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(displayedOutput.count) lines")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(displayedOutput.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(lineColor(for: line))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .frame(height: 150)
                .onChange(of: progress.output.count) { _, _ in
                    // Auto-scroll to bottom on new output
                    if let lastIndex = displayedOutput.indices.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var footerSection: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .frame(minWidth: 80)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    // MARK: - Helpers

    /// Output lines to display (limited to maxOutputLines).
    private var displayedOutput: [String] {
        if progress.output.count <= maxOutputLines {
            return progress.output
        }
        return Array(progress.output.suffix(maxOutputLines))
    }

    /// Formatted elapsed time string.
    private var formattedElapsedTime: String {
        let minutes = Int(progress.elapsedTime) / 60
        let seconds = Int(progress.elapsedTime) % 60
        return String(format: "%d:%02d elapsed", minutes, seconds)
    }

    /// Color for output line based on content.
    private func lineColor(for line: String) -> Color {
        let lowercased = line.lowercased()
        if lowercased.contains("error") || lowercased.contains("failed") {
            return .red
        } else if lowercased.contains("warning") || lowercased.contains("warn") {
            return .orange
        } else if lowercased.contains("success") || lowercased.contains("complete") {
            return .green
        }
        return .primary.opacity(0.8)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Installing") {
    InstallationProgressView(
        progress: InstallProgress(
            currentStep: 2,
            totalSteps: 4,
            stepDescription: "Downloading claude-code package...",
            elapsedTime: 45,
            output: [
                "Checking npm version...",
                "npm version 10.2.4",
                "Installing @anthropic-ai/claude-code@latest...",
                "Downloading package...",
                "Progress: 45%"
            ]
        ),
        cliName: "Claude Code",
        onCancel: {}
    )
    .frame(width: 500)
    .padding()
}

#Preview("Error State") {
    InstallationProgressView(
        progress: InstallProgress(
            currentStep: 2,
            totalSteps: 4,
            stepDescription: "Installing package...",
            elapsedTime: 120,
            output: [
                "Checking npm version...",
                "npm version 10.2.4",
                "Installing @anthropic-ai/claude-code@latest...",
                "ERROR: EACCES permission denied",
                "npm ERR! code EACCES"
            ]
        ),
        cliName: "Claude Code",
        errorMessage: "Permission denied. Try running with administrator privileges or check npm configuration.",
        onCancel: {}
    )
    .frame(width: 500)
    .padding()
}

#Preview("Long Output") {
    let manyLines = (1...60).map { "Line \($0): Processing installation step..." }
    return InstallationProgressView(
        progress: InstallProgress(
            currentStep: 3,
            totalSteps: 4,
            stepDescription: "Running post-install scripts...",
            elapsedTime: 180,
            output: manyLines
        ),
        cliName: "Gemini CLI",
        onCancel: {}
    )
    .frame(width: 500)
    .padding()
}
#endif
