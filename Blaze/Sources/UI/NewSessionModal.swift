import SwiftUI
import AppKit

// MARK: - New Session Modal

/// Modal sheet for creating a new session with directory selection and git worktree setup.
///
/// **Phase 2 Behavior:**
/// 1. User selects a directory via NSOpenPanel
/// 2. App checks if directory is a git repo
/// 3. If not git: offer to initialize with consent
/// 4. Create session record
/// 5. Create git worktree for isolation
/// 6. Update session with worktree path
struct NewSessionModal: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedPath: String = ""
    @State private var sessionName: String = "New Session"
    @State private var isGitRepo: Bool = false
    @State private var showGitInitOptions: Bool = false
    @State private var shouldInitGit: Bool = false
    @State private var shouldCreateInitialCommit: Bool = false
    @State private var selectedTrustMode: TrustMode = .prompt
    @State private var isChecking: Bool = false
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?
    @State private var gitInstalled: Bool = true
    @State private var availableBranches: [String] = []
    @State private var selectedBaseBranch: String = ""
    @State private var createNewBranch: Bool = true

    // MARK: - CLI Provider State
    @State private var availableProviders: [AIProvider] = []
    @State private var selectedProvider: AIProvider = .anthropic
    @State private var cliStatuses: [EngineType: CLIStatus] = [:]
    @State private var isCheckingCLIs: Bool = true

    // MARK: - Dependencies

    private let gitManager = GitWorktreeManager()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    // Directory selection
                    directorySection

                    // Git status section
                    if !selectedPath.isEmpty {
                        gitStatusSection
                    }

                    // Git init options (if not a git repo)
                    if showGitInitOptions {
                        gitInitSection
                    }

                    // Session options
                    if !selectedPath.isEmpty && (isGitRepo || shouldInitGit) {
                        sessionOptionsSection
                    }

                    // CLI Provider selection
                    cliProviderSection

                    // Trust mode
                    trustModeSection

                    // Preview actions
                    if !selectedPath.isEmpty {
                        previewSection
                    }

                    // Error display
                    if let error = errorMessage {
                        errorSection(error)
                    }
                }
                .padding(DSSpacing.lg)
            }

            Divider()

            // Footer with actions
            footer
        }
        .frame(width: 500, height: 600)
        .background(Color.ds.bg1)
        .task {
            // Check if git is installed
            gitInstalled = await gitManager.isGitInstalled()

            // Check CLI availability
            await checkCLIAvailability()
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("New Session")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.ds.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(DSSpacing.md)
    }

    private var directorySection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Project Directory", systemImage: "folder")
                .dsTextStyle(.caption, color: .ds.secondary)

            HStack {
                TextField("Select a directory...", text: $selectedPath)
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)

                Button("Browse...") {
                    selectDirectory()
                }
            }

            if !gitInstalled {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.ds.warning)
                    Text("Git is not installed. Install git to enable worktree isolation.")
                        .dsTextStyle(.caption, color: .ds.warning)
                }
                .padding(DSSpacing.sm)
                .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.sm, elevation: .none)
            }
        }
    }

    private var gitStatusSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Git Status", systemImage: "arrow.triangle.branch")
                .dsTextStyle(.caption, color: .ds.secondary)

            HStack(spacing: DSSpacing.sm) {
                if isChecking {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if isGitRepo {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.ds.positive)
                    Text("Git repository detected")
                        .dsTextStyle(.body)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.ds.negative)
                    Text("Not a git repository")
                        .dsTextStyle(.body)
                }
            }
            .padding(DSSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.sm, elevation: .none)
        }
    }

    private var gitInitSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Initialize Git", systemImage: "arrow.triangle.branch")
                .dsTextStyle(.caption, color: .ds.secondary)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Toggle(isOn: $shouldInitGit) {
                    VStack(alignment: .leading) {
                        Text("Initialize git repository")
                            .dsTextStyle(.body)
                        Text("Creates .git folder in the project directory")
                            .dsTextStyle(.caption, color: .ds.secondary)
                    }
                }
                .toggleStyle(.checkbox)

                if shouldInitGit {
                    Toggle(isOn: $shouldCreateInitialCommit) {
                        VStack(alignment: .leading) {
                            Text("Create initial commit")
                                .dsTextStyle(.body)
                            Text("Commits all existing files with 'Initial commit' message")
                                .dsTextStyle(.caption, color: .ds.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(.leading, DSSpacing.lg)
                }
            }
            .padding(DSSpacing.md)
            .dsGlassPanel(level: .regular, cornerRadius: DSRadius.md, elevation: .low)
        }
    }

    private var sessionOptionsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Session Options", systemImage: "doc.badge.plus")
                .dsTextStyle(.caption, color: .ds.secondary)

            VStack(alignment: .leading, spacing: DSSpacing.md) {
                // Session name
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("Session Name")
                        .dsTextStyle(.caption, color: .ds.secondary)
                    TextField("Enter session name", text: $sessionName)
                        .textFieldStyle(.roundedBorder)
                }

                // Branch options
                if isGitRepo && !availableBranches.isEmpty {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        Text("Base Branch")
                            .dsTextStyle(.caption, color: .ds.secondary)

                        Picker("", selection: $selectedBaseBranch) {
                            Text("Current HEAD").tag("")
                            ForEach(availableBranches, id: \.self) { branch in
                                Text(branch).tag(branch)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }
            .padding(DSSpacing.md)
            .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
        }
    }

    private var cliProviderSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("CLI Provider", systemImage: "terminal")
                .dsTextStyle(.caption, color: .ds.secondary)

            if isCheckingCLIs {
                HStack(spacing: DSSpacing.sm) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Checking installed CLIs...")
                        .dsTextStyle(.body, color: .ds.secondary)
                }
                .padding(DSSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
            } else if availableProviders.isEmpty {
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.ds.warning)
                    Text("No CLI providers installed. Install Claude Code, Gemini CLI, or Codex CLI.")
                        .dsTextStyle(.body, color: .ds.warning)
                }
                .padding(DSSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
            } else {
                Picker("", selection: $selectedProvider) {
                    ForEach(availableProviders, id: \.self) { provider in
                        HStack(spacing: DSSpacing.sm) {
                            providerLogo(for: provider)
                            VStack(alignment: .leading) {
                                Text(provider.displayName)
                                if let status = cliStatuses[provider.engineType],
                                   case .available(let version, _) = status {
                                    Text("v\(version)")
                                        .font(.caption2)
                                        .foregroundStyle(Color.ds.tertiary)
                                }
                            }
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.radioGroup)
                .padding(DSSpacing.md)
                .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
            }
        }
    }

    private var trustModeSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Trust Mode", systemImage: "shield")
                .dsTextStyle(.caption, color: .ds.secondary)

            Picker("", selection: $selectedTrustMode) {
                ForEach(TrustMode.allCases, id: \.self) { mode in
                    VStack(alignment: .leading) {
                        Text(mode.displayName)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .padding(DSSpacing.md)
            .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Actions Preview", systemImage: "list.bullet.clipboard")
                .dsTextStyle(.caption, color: .ds.secondary)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                ForEach(previewActions, id: \.self) { action in
                    HStack(alignment: .top, spacing: DSSpacing.sm) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.ds.tertiary)
                        Text(action)
                            .dsTextStyle(.monoSmall, color: .ds.secondary)
                    }
                }
            }
            .padding(DSSpacing.md)
            .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
        }
    }

    private func errorSection(_ message: String) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.ds.negative)
            Text(message)
                .dsTextStyle(.body, color: .ds.negative)
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ds.negative.opacity(0.1))
        .cornerRadius(DSRadius.md)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button {
                Task {
                    await createSession()
                }
            } label: {
                if isCreating {
                    HStack(spacing: DSSpacing.xs) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Creating...")
                    }
                } else {
                    Text("Create Session")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canCreateSession || isCreating)
            .keyboardShortcut(.return)
        }
        .padding(DSSpacing.md)
    }

    // MARK: - Computed Properties

    private var canCreateSession: Bool {
        !selectedPath.isEmpty &&
        !sessionName.isEmpty &&
        (isGitRepo || shouldInitGit) &&
        gitInstalled &&
        !availableProviders.isEmpty
    }

    private var previewActions: [String] {
        var actions: [String] = []

        if !isGitRepo && shouldInitGit {
            actions.append("git init")
            if shouldCreateInitialCommit {
                actions.append("git add -A")
                actions.append("git commit -m \"Initial commit\"")
            }
        }

        let shortId = UUID().uuidString.prefix(8).lowercased()
        actions.append("Create session record")
        actions.append("git worktree add .blaze-worktrees/<sessionId>/ -b blaze-session-\(shortId)")
        actions.append("Spawn \(selectedProvider.displayName) CLI in worktree")

        return actions
    }

    @ViewBuilder
    private func providerLogo(for provider: AIProvider) -> some View {
        ProviderLogos.image(for: provider, size: 20)
    }

    // MARK: - Actions

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a project directory"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
            sessionName = url.lastPathComponent

            Task {
                await checkGitStatus()
            }
        }
    }

    private func checkGitStatus() async {
        isChecking = true
        errorMessage = nil

        do {
            isGitRepo = try await gitManager.isGitRepository(selectedPath)
            showGitInitOptions = !isGitRepo

            if isGitRepo {
                availableBranches = try await gitManager.getBranches(repoPath: selectedPath)
            } else {
                availableBranches = []
            }
        } catch {
            errorMessage = "Failed to check git status: \(error.localizedDescription)"
        }

        isChecking = false
    }

    private func checkCLIAvailability() async {
        isCheckingCLIs = true

        // Check all CLI providers
        let statuses = await CLIAvailabilityChecker.shared.checkAllProviders()
        cliStatuses = statuses

        // Build list of available providers (excluding .community for now as it's not fully supported)
        let mainProviders: [AIProvider] = [.anthropic, .openai, .google]
        availableProviders = mainProviders.filter { provider in
            statuses[provider.engineType]?.isAvailable == true
        }

        // Default to Claude (anthropic) if available, otherwise first available
        if availableProviders.contains(.anthropic) {
            selectedProvider = .anthropic
        } else if let first = availableProviders.first {
            selectedProvider = first
        }

        isCheckingCLIs = false
    }

    private func createSession() async {
        isCreating = true
        errorMessage = nil

        do {
            // Canonicalize the path
            guard let canonicalPath = PathUtilities.canonicalize(selectedPath) else {
                throw GitWorktreeError.invalidRepoPath(selectedPath)
            }

            // Initialize git if needed
            if !isGitRepo && shouldInitGit {
                try await gitManager.initRepository(
                    at: canonicalPath,
                    createInitialCommit: shouldCreateInitialCommit
                )
            }

            // Create session via AppState
            await appState.createSessionWithWorktree(
                name: sessionName,
                projectPath: canonicalPath,
                trustMode: selectedTrustMode,
                baseBranch: selectedBaseBranch.isEmpty ? nil : selectedBaseBranch,
                provider: selectedProvider
            )

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }
}

// MARK: - Preview

#Preview {
    NewSessionModal()
        .environmentObject(AppState())
}
