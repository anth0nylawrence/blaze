import SwiftUI

// MARK: - CLI Detection View

/// Onboarding screen for detecting installed AI CLI tools.
/// Shows Claude Code, Gemini CLI, and OpenAI Codex with detection status.
public struct CLIDetectionView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    public init() {}

    public var body: some View {
        VStack(spacing: DSSpacing.xl) {
            // Header
            VStack(spacing: DSSpacing.sm) {
                Text("Detect Your AI CLIs")
                    .dsTextStyle(.hero)

                Text("Blaze works with popular AI coding assistants. Let's see which ones you have installed.")
                    .dsTextStyle(.body, color: .ds.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            .onboardingFadeIn(delay: 0)

            // CLI List
            VStack(spacing: DSSpacing.sm) {
                ForEach(Array(viewModel.detectedCLIs.enumerated()), id: \.element.id) { index, cli in
                    CLIDetectionRow(cli: cli, isScanning: viewModel.cliDetectionState == .scanning)
                        .onboardingFadeIn(delay: Double(index) * OnboardingAnimation.staggerDelay + 0.1)
                }
            }
            .padding(.vertical, DSSpacing.md)

            // Status message
            statusMessage
                .onboardingFadeIn(delay: 0.2)

            Spacer()

            // Navigation buttons
            HStack(spacing: DSSpacing.md) {
                GlassButton("Back", icon: "chevron.left", style: .ghost, size: .medium) {
                    viewModel.previousStep()
                }

                Spacer()

                if viewModel.cliDetectionState == .idle {
                    GlassButton("Scan", icon: "magnifyingglass", style: .secondary, size: .medium) {
                        Task {
                            await viewModel.scanForCLIs()
                        }
                    }
                }

                GlassButton("Continue", icon: "chevron.right", style: .primary, size: .medium) {
                    viewModel.nextStep()
                }
            }
            .onboardingFadeIn(delay: 0.3)
        }
        .padding(DSSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Message

    @ViewBuilder
    private var statusMessage: some View {
        switch viewModel.cliDetectionState {
        case .idle:
            Text("Click \"Scan\" to detect installed CLI tools")
                .dsTextStyle(.caption, color: .ds.tertiary)

        case .scanning:
            HStack(spacing: DSSpacing.xs) {
                ProgressView()
                    .controlSize(.small)
                Text("Scanning...")
                    .dsTextStyle(.caption, color: .ds.secondary)
            }

        case .completed:
            if viewModel.detectedCLICount > 0 {
                Label("\(viewModel.detectedCLICount) CLI\(viewModel.detectedCLICount == 1 ? "" : "s") detected", systemImage: "checkmark.circle.fill")
                    .dsTextStyle(.caption, color: .ds.positive)
            } else {
                VStack(spacing: DSSpacing.xxs) {
                    Label("No CLIs detected", systemImage: "exclamationmark.triangle")
                        .dsTextStyle(.caption, color: .ds.warning)
                    Text("You can install them later and re-run detection.")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                }
            }

        case .error(let message):
            Label(message, systemImage: "xmark.circle")
                .dsTextStyle(.caption, color: .ds.negative)
        }
    }
}

// MARK: - CLI Detection Row

/// A row displaying a single CLI with its detection status and install options.
private struct CLIDetectionRow: View {
    let cli: DetectedCLI
    let isScanning: Bool

    @State private var isInstalling = false
    @State private var showInstallConfirmation = false
    @State private var installError: String?

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: DSSize.xl, height: DSSize.xl)

                Image(systemName: cli.icon)
                    .font(.system(size: DSSize.sm))
                    .foregroundStyle(iconForegroundColor)
            }

            // CLI info
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(cli.name)
                    .dsTextStyle(.subtitle)

                HStack(spacing: DSSpacing.xs) {
                    Text(cli.command)
                        .dsTextStyle(.mono, color: .ds.tertiary)

                    if let version = cli.version, cli.isDetected {
                        Text("(\(version.components(separatedBy: .newlines).first ?? version))")
                            .dsTextStyle(.micro, color: .ds.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Status indicator and actions
            statusAndActions
        }
        .padding(DSSpacing.md)
        .dsGlassPanel(
            level: .light,
            cornerRadius: DSRadius.lg,
            elevation: cli.isDetected ? .low : .none,
            border: .subtle
        )
        .alert("Install \(cli.name)?", isPresented: $showInstallConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Copy Command") {
                if let cmd = cli.installCommand {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cmd, forType: .string)
                }
            }
            if let url = cli.installUrl, let nsUrl = URL(string: url) {
                Button("Open Docs") {
                    NSWorkspace.shared.open(nsUrl)
                }
            }
        } message: {
            if let cmd = cli.installCommand {
                Text("Run this command in Terminal:\n\n\(cmd)")
            } else if let url = cli.installUrl {
                Text("Visit \(url) for installation instructions.")
            }
        }
    }

    // MARK: - Computed Properties

    private var iconBackgroundColor: Color {
        if cli.isDetected {
            return Color.ds.positive.opacity(0.15)
        } else if isScanning || isInstalling {
            return Color.ds.accent.opacity(0.1)
        } else {
            return Color.ds.tertiary.opacity(0.1)
        }
    }

    private var iconForegroundColor: Color {
        if cli.isDetected {
            return Color.ds.positive
        } else if isScanning || isInstalling {
            return Color.ds.accent
        } else {
            return Color.ds.tertiary
        }
    }

    @ViewBuilder
    private var statusAndActions: some View {
        if isScanning {
            ProgressView()
                .controlSize(.small)
                .frame(width: DSSize.md, height: DSSize.md)
        } else if cli.isDetected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DSSize.md))
                .foregroundStyle(Color.ds.positive)
                .transition(.scale.combined(with: .opacity))
        } else {
            // Not detected - show install options if available
            HStack(spacing: DSSpacing.xs) {
                if cli.installCommand != nil || cli.installUrl != nil {
                    Button {
                        showInstallConfirmation = true
                    } label: {
                        Label("Install", systemImage: "arrow.down.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.ds.accent)
                } else {
                    Text("Not found")
                        .dsTextStyle(.caption, color: .ds.tertiary)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("CLI Detection - Idle") {
    CLIDetectionView()
        .environment(OnboardingViewModel())
        .frame(width: 500, height: 600)
        .background(Color.ds.bg0)
}

#Preview("CLI Detection - Scanning") {
    let vm = OnboardingViewModel()
    // Simulate scanning state
    return CLIDetectionView()
        .environment(vm)
        .frame(width: 500, height: 600)
        .background(Color.ds.bg0)
        .task {
            await vm.scanForCLIs()
        }
}
#endif
