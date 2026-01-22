import SwiftUI
import AppKit

// MARK: - AutoFocusTextField

/// NSViewRepresentable that wraps NSTextField and explicitly becomes first responder.
/// Works around SwiftUI @FocusState issues with glass windows.
struct AutoFocusTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var shouldFocus: Bool

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.delegate = context.coordinator
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        // Become first responder when shouldFocus is true
        if shouldFocus && nsView.window != nil && nsView.window?.firstResponder != nsView.currentEditor() {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                text = textField.stringValue
            }
        }
    }
}

// MARK: - OnboardingRootView

/// Root container for the onboarding flow.
///
/// Switches between step-specific views based on the current step and displays
/// a progress indicator. The ViewModel is injected via Environment.
public struct OnboardingRootView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    public init() {}

    public var body: some View {
        ZStack {
            // Full-window glass background (matches MainContentView pattern)
            ThemeAwareBackground()

            // Onboarding content centered in window
            onboardingContent
        }
        .ignoresSafeArea()
        .background(
            // Configure window for transparency
            WindowAccessor { window in
                configureLiquidGlassWindow(window)
            }
        )
    }

    // MARK: - Onboarding Content

    private var onboardingContent: some View {
        VStack(spacing: 0) {
            // Progress indicator at top
            OnboardingProgressView(currentStep: viewModel.currentStep)
                .padding(.top, 40)
                .padding(.horizontal, 40)

            // Step content
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)

            // Navigation buttons at bottom
            OnboardingNavigationBar(
                currentStep: viewModel.currentStep,
                canProceed: viewModel.canProceedFromCurrentStep(),
                validationMessage: viewModel.validationMessage,
                onBack: { viewModel.goToPreviousStep() },
                onNext: { viewModel.goToNextStep() },
                onSkip: { viewModel.skipOnboarding() }
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: 800) // Limit content width for readability
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            WelcomeView()
        case .userProfile:
            OnboardingUserProfileStepView()
        case .cliDetection:
            OnboardingCLIDetectionStepView()
        case .skillsRecommendations:
            SkillsRecommendationsView()
        case .pluginsRecommendations:
            OnboardingPluginsStepView()
        case .agentsRecommendations:
            AgentsRecommendationsView()
        case .completion:
            OnboardingCompletionStepView()
        }
    }

}

// MARK: - Progress View

/// Shows progress through the onboarding steps
struct OnboardingProgressView: View {
    let currentStep: OnboardingStep

    var body: some View {
        VStack(spacing: 8) {
            // Step indicator dots
            HStack(spacing: 12) {
                ForEach(OnboardingStep.allCases) { step in
                    Circle()
                        .fill(stepColor(for: step))
                        .frame(width: 10, height: 10)
                        .scaleEffect(step == currentStep ? 1.3 : 1.0)
                        .animation(.spring(duration: 0.3), value: currentStep)
                }
            }

            // Step title
            Text(currentStep.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func stepColor(for step: OnboardingStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            return .green
        } else if step == currentStep {
            return .accentColor
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// MARK: - Navigation Bar

/// Bottom navigation bar with back, next, and skip buttons
struct OnboardingNavigationBar: View {
    let currentStep: OnboardingStep
    let canProceed: Bool
    let validationMessage: String?
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Validation message
            if let message = validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                // Back button (hidden on first step)
                if !currentStep.isFirst {
                    Button("Back") {
                        onBack()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Skip button (only on welcome)
                if currentStep == .welcome {
                    Button("Skip Setup") {
                        onSkip()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                // Next/Complete button
                Button(currentStep.isLast ? "Get Started" : "Continue") {
                    onNext()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            }
        }
    }
}

// MARK: - Step View Stubs

/// User profile setup step
struct OnboardingUserProfileStepView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @State private var shouldFocusTextField = false

    var body: some View {
        // Use @Bindable to create bindings to @Observable STORED properties
        // IMPORTANT: userName and userExperienceLevel are computed properties that
        // wrap displayName and experienceLevel. The Observation framework cannot
        // create bindings to computed properties - only stored properties work.
        @Bindable var vm = viewModel

        return VStack(spacing: 32) {
            Spacer()

            Text("Tell us about yourself")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Name")
                        .font(.headline)
                    // Use AutoFocusTextField (AppKit) instead of SwiftUI TextField
                    // to work around glass window focus issues
                    AutoFocusTextField(
                        text: $vm.displayName,
                        placeholder: "Enter your name",
                        shouldFocus: shouldFocusTextField
                    )
                    .frame(maxWidth: 300, minHeight: 22)
                }
                .onAppear {
                    // Delay focus to ensure window is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        shouldFocusTextField = true
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Experience Level")
                        .font(.headline)
                    // Use experienceLevel (stored property) not userExperienceLevel (computed)
                    Picker("", selection: $vm.experienceLevel) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 400, alignment: .leading)

                    Text(vm.experienceLevel.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

/// CLI detection step
struct OnboardingCLIDetectionStepView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    private var detectedCLIs: [DetectedCLI] {
        viewModel.detectedCLIs.filter { $0.isDetected }
    }

    private var undetectedCLIs: [DetectedCLI] {
        viewModel.detectedCLIs.filter { !$0.isDetected }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Detecting Installed CLIs")
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.isDetectingCLIs {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Scanning for agentic coding CLIs...")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Detected CLIs section
                        if !detectedCLIs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Detected")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                ForEach(detectedCLIs) { cli in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text(cli.name)
                                            .fontWeight(.medium)
                                        Spacer()
                                        if let version = cli.version {
                                            Text(version)
                                                .foregroundStyle(.secondary)
                                                .font(.caption)
                                        }
                                    }
                                    .padding()
                                    .background(.background.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        } else {
                            // No CLIs detected warning
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.orange)
                                Text("No CLIs detected")
                                    .font(.headline)
                                Text("Install at least one CLI below to use Blaze.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }

                        // Available CLIs section (undetected)
                        if !undetectedCLIs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Available")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                ForEach(undetectedCLIs) { cli in
                                    HStack {
                                        Image(systemName: cli.icon)
                                            .foregroundStyle(.secondary)
                                        Text(cli.name)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if let url = cli.installUrl, let nsUrl = URL(string: url) {
                                            Button {
                                                NSWorkspace.shared.open(nsUrl)
                                            } label: {
                                                Label("Install", systemImage: "arrow.down.circle")
                                                    .font(.caption)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                    }
                                    .padding()
                                    .background(.background.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 400, maxHeight: 350)
            }

            Spacer()
        }
        .task {
            await viewModel.scanForCLIs()
        }
    }
}

/// Skills recommendations step
struct OnboardingSkillsStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Recommended Skills")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Skills extend your CLI's capabilities.\nWe'll suggest some based on your setup.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            // Placeholder for skills list
            Text("Coming soon...")
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }
}

/// Plugins recommendations step - shows MCP servers grouped by CLI
struct OnboardingPluginsStepView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    private var detectedCLIsFiltered: [DetectedCLI] {
        viewModel.detectedCLIs.filter { $0.isDetected }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("MCP Plugins")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Model Context Protocol servers extend your CLI capabilities.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if viewModel.isDetectingMCPs {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Text("Scanning for MCP servers across all CLIs...")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                // MCP Summary Table
                mcpSummaryTable

                // MCPs grouped by CLI
                if !viewModel.detectedMCPs.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(detectedCLIsFiltered) { cli in
                                mcpSectionForCLI(cli)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxWidth: 550, maxHeight: 220)

                    Text("\(viewModel.enabledMCPCount) of \(viewModel.detectedMCPs.count) plugins enabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Install prompt
                installPromptSection
            }
        }
        .task {
            await viewModel.scanForMCPs()
        }
    }

    // MARK: - Summary Table

    private var mcpSummaryTable: some View {
        VStack(spacing: 8) {
            HStack(spacing: 24) {
                ForEach(detectedCLIsFiltered) { cli in
                    VStack(spacing: 4) {
                        Image(systemName: cli.icon)
                            .font(.title2)
                            .foregroundStyle(mcpCountForCLI(cli.id) > 0 ? Color.accentColor : Color.secondary)
                        Text(cli.name)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("\(mcpCountForCLI(cli.id)) MCPs")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 100)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(.background.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func mcpCountForCLI(_ cliId: String) -> Int {
        viewModel.detectedMCPs.filter { $0.sourceCLI == cliId }.count
    }

    // MARK: - MCP Section per CLI

    @ViewBuilder
    private func mcpSectionForCLI(_ cli: DetectedCLI) -> some View {
        let mcpsForCLI = viewModel.detectedMCPs.filter { $0.sourceCLI == cli.id }

        if !mcpsForCLI.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: cli.icon)
                        .foregroundStyle(.secondary)
                    Text(cli.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(mcpsForCLI.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.background.opacity(0.7))
                        .clipShape(Capsule())
                }

                ForEach(mcpsForCLI) { mcp in
                    OnboardingMCPRow(mcp: mcp) {
                        viewModel.toggleMCP(id: mcp.id)
                    }
                }
            }
        }
    }

    // MARK: - Install Prompt

    private var installPromptSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            if viewModel.detectedMCPs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No MCP servers found")
                        .font(.headline)
                }
            }

            Text("Would you like to install additional MCP servers?")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    // Open MCP catalog/documentation
                    if let url = URL(string: "https://github.com/modelcontextprotocol/servers") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Browse MCP Catalog", systemImage: "globe")
                }
                .buttonStyle(.bordered)

                Button {
                    // Open Claude settings for manual config
                    let settingsPath = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".claude/settings.json")
                    NSWorkspace.shared.open(settingsPath)
                } label: {
                    Label("Open Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// Row displaying a single MCP server with toggle for onboarding
private struct OnboardingMCPRow: View {
    let mcp: DetectedMCP
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mcp.icon)
                .font(.title3)
                .foregroundStyle(mcp.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(mcp.name)
                    .fontWeight(.medium)
                Text(mcp.serverType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { mcp.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


/// Completion step
struct OnboardingCompletionStepView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            if !viewModel.displayName.isEmpty {
                Text("Welcome aboard, \(viewModel.displayName)!")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                if viewModel.detectedCLICount > 0 {
                    Label("\(viewModel.detectedCLICount) CLI(s) ready", systemImage: "terminal")
                }
                if !viewModel.selectedSkills.isEmpty {
                    Label("\(viewModel.selectedSkills.count) skill(s) enabled", systemImage: "star")
                }
                if !viewModel.selectedPlugins.isEmpty {
                    Label("\(viewModel.selectedPlugins.count) plugin(s) configured", systemImage: "puzzlepiece")
                }
            }
            .foregroundStyle(.secondary)

            Spacer()

            Text("Click 'Get Started' to begin using Blaze")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingRootView()
        .environment(OnboardingViewModel())
        .frame(width: 700, height: 600)
}
