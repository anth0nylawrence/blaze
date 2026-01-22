import SwiftUI
import AppKit

// MARK: - Session Creation Modal

/// Unified session creation wizard combining directory source, provider/model selection,
/// and session configuration.
///
/// **E005-F001-S001-T005-A001 Implementation:**
/// - Composes DirectorySourcePicker and ProviderModelSelector
/// - Session name field with auto-generation from directory
/// - Create/Cancel buttons with validation
/// - Calls AppState.createSessionWithWorktree on submit
///
/// **UI States:**
/// - Initial: Browse tab selected, form empty, Create button disabled
/// - Ready: Valid configuration, Create button enabled
/// - Creating: All inputs disabled, button shows spinner
/// - Error: Error banner displayed with retry option
struct SessionCreationModal: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // MARK: - Directory Source State

    /// The directory source result (complete state from the picker)
    @State private var directorySourceResult: DirectorySourceResult = .defaultBrowse

    /// Whether a clone operation is in progress
    @State private var isCloning: Bool = false

    // MARK: - Provider/Model State

    @State private var selectedProvider: EngineType = .claude
    @State private var selectedModelId: String = ModelService.defaultModel(for: .claude)

    // MARK: - Session Config State

    @State private var sessionName: String = ""
    @State private var selectedTrustMode: TrustMode = .prompt

    // MARK: - UI State

    @State private var isCreating: Bool = false
    @State private var validationError: String? = nil
    @State private var gitInstalled: Bool = true
    @State private var availableBranches: [String] = []
    @State private var selectedBaseBranch: String = ""

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
                    // Directory source picker
                    directorySourceSection

                    // Provider and model selection
                    providerModelSection

                    // Session configuration
                    sessionConfigSection

                    // Trust mode
                    trustModeSection

                    // Actions preview
                    if directorySourceResult.isComplete {
                        previewSection
                    }

                    // Error display
                    if let error = validationError {
                        errorSection(error)
                    }
                }
                .padding(DSSpacing.lg)
            }

            Divider()

            // Footer with actions
            footer
        }
        .frame(width: 550, height: 700)
        .background(Color.ds.bg1)
        .task {
            // Check if git is installed
            gitInstalled = await gitManager.isGitInstalled()
        }
        .onChange(of: directorySourceResult) { _, newResult in
            // Check git status when browsing a directory
            updateFromDirectoryResult(newResult)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("New Session")
                    .font(.headline)
                Text("Create a new coding session with AI assistance")
                    .dsTextStyle(.caption, color: .ds.secondary)
            }

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

    private var directorySourceSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Project Location", systemImage: "folder")
                .dsTextStyle(.caption, color: .ds.secondary)

            DirectorySourcePicker(
                result: $directorySourceResult,
                isCloning: $isCloning
            )
            .padding(DSSpacing.md)
            .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
        }
    }

    private var providerModelSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("AI Configuration", systemImage: "brain")
                .dsTextStyle(.caption, color: .ds.secondary)

            ProviderModelSelector(
                selectedProvider: $selectedProvider,
                selectedModelId: $selectedModelId
            )
            .padding(DSSpacing.md)
            .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
        }
    }

    private var sessionConfigSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Session Options", systemImage: "doc.badge.plus")
                .dsTextStyle(.caption, color: .ds.secondary)

            VStack(alignment: .leading, spacing: DSSpacing.md) {
                // Session name
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("Session Name")
                        .dsTextStyle(.caption, color: .ds.secondary)

                    GlassTextField("Enter session name", text: $sessionName, icon: "text.cursor")

                    if sessionName.isEmpty && directorySourceResult.isComplete {
                        Text("Will use: \(autoGeneratedName)")
                            .dsTextStyle(.caption, color: .ds.tertiary)
                    }
                }

                // Branch selection (only for browse mode with git repo)
                if directorySourceResult.source == .browse,
                   directorySourceResult.browsePath != nil,
                   !availableBranches.isEmpty {
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

    private var trustModeSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Trust Mode", systemImage: "shield")
                .dsTextStyle(.caption, color: .ds.secondary)

            Picker("", selection: $selectedTrustMode) {
                ForEach(TrustMode.allCases, id: \.self) { mode in
                    VStack(alignment: .leading) {
                        Text(mode.displayName)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundStyle(Color.ds.tertiary)
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
            Spacer()
            Button("Dismiss") {
                validationError = nil
            }
            .buttonStyle(.borderless)
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

            // Provider indicator
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: selectedProvider.icon)
                Text(selectedProvider.rawValue)
            }
            .dsTextStyle(.caption, color: .ds.tertiary)

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
        guard directorySourceResult.isComplete else { return false }
        guard !isCloning else { return false }

        // For clone and create modes, git must be installed
        switch directorySourceResult.source {
        case .browse:
            return true
        case .clone, .create:
            return gitInstalled
        }
    }

    private var effectiveSessionName: String {
        sessionName.isEmpty ? autoGeneratedName : sessionName
    }

    private var autoGeneratedName: String {
        switch directorySourceResult.source {
        case .browse:
            return directorySourceResult.browsePath?.lastPathComponent ?? "New Session"

        case .clone:
            // Extract repo name from URL
            let trimmed = directorySourceResult.cloneURL.trimmingCharacters(in: .whitespacesAndNewlines)
            var name = trimmed

            // Remove .git suffix if present
            if name.hasSuffix(".git") {
                name = String(name.dropLast(4))
            }

            // Get the last component after / or :
            if let lastSlash = name.lastIndex(of: "/") {
                name = String(name[name.index(after: lastSlash)...])
            } else if let lastColon = name.lastIndex(of: ":") {
                name = String(name[name.index(after: lastColon)...])
                if let slashIndex = name.lastIndex(of: "/") {
                    name = String(name[name.index(after: slashIndex)...])
                }
            }

            return name.isEmpty ? "Cloned Project" : name

        case .create:
            let sanitized = DirectorySourcePicker.sanitizeProjectName(directorySourceResult.createName)
            return sanitized.isEmpty ? "New Project" : sanitized
        }
    }

    private var previewActions: [String] {
        var actions: [String] = []

        switch directorySourceResult.source {
        case .browse:
            if let path = directorySourceResult.browsePath {
                actions.append("Use existing directory: \(path.lastPathComponent)")
            }

        case .clone:
            actions.append("Clone repository: \(directorySourceResult.cloneURL)")
            if directorySourceResult.cloneShallow {
                actions.append("Shallow clone enabled (faster)")
            }
            if let dest = directorySourceResult.cloneDestination {
                actions.append("Clone to: \(dest.path)")
            }

        case .create:
            let sanitized = DirectorySourcePicker.sanitizeProjectName(directorySourceResult.createName)
            let targetDir = directorySourceResult.createParent.appendingPathComponent(sanitized)
            actions.append("Create directory: \(targetDir.path)")
            if directorySourceResult.createInitGit {
                actions.append("git init")
            }
        }

        actions.append("Create session: \"\(effectiveSessionName)\"")
        actions.append("Provider: \(selectedProvider.rawValue)")

        // Get model name from ModelService
        let models = ModelService.models(for: selectedProvider)
        let modelName = models.first { $0.id == selectedModelId }?.displayName ?? selectedModelId
        actions.append("Model: \(modelName)")

        let shortId = UUID().uuidString.prefix(8).lowercased()
        actions.append("git worktree add .blaze-worktrees/<sessionId>/ -b blaze-session-\(shortId)")

        return actions
    }

    // MARK: - Actions

    private func updateFromDirectoryResult(_ result: DirectorySourceResult) {
        // Only update if session name is empty (user hasn't typed anything)
        guard sessionName.isEmpty else { return }

        // Check git status for browse mode
        if result.source == .browse, let path = result.browsePath {
            Task {
                await checkGitStatus(for: path.path)
            }
        }
    }

    private func checkGitStatus(for path: String) async {
        validationError = nil

        do {
            let isGitRepo = try await gitManager.isGitRepository(path)

            await MainActor.run {
                if isGitRepo {
                    Task {
                        do {
                            let branches = try await gitManager.getBranches(repoPath: path)
                            await MainActor.run {
                                availableBranches = branches
                            }
                        } catch {
                            await MainActor.run {
                                availableBranches = []
                            }
                        }
                    }
                } else {
                    availableBranches = []
                }
            }
        } catch {
            await MainActor.run {
                validationError = "Failed to check git status: \(error.localizedDescription)"
            }
        }
    }

    private func createSession() async {
        isCreating = true
        validationError = nil

        do {
            let projectPath: String

            switch directorySourceResult.source {
            case .browse:
                guard let path = directorySourceResult.browsePath else {
                    throw SessionCreationError.invalidPath("No directory selected")
                }
                projectPath = path.path

            case .clone:
                // Clone operation
                guard let dest = directorySourceResult.cloneDestination else {
                    throw SessionCreationError.invalidPath("No clone destination specified")
                }

                // TODO: Implement actual clone via GitWorktreeManager
                // For now, this would be:
                // projectPath = try await gitManager.cloneRepository(
                //     url: directorySourceResult.cloneURL,
                //     to: dest.path,
                //     shallow: directorySourceResult.cloneShallow
                // )
                _ = dest // silence unused warning
                throw SessionCreationError.notImplemented("Clone flow requires GitWorktreeManager.cloneRepository")

            case .create:
                projectPath = try await createNewProject(
                    name: directorySourceResult.createName,
                    parent: directorySourceResult.createParent,
                    initGit: directorySourceResult.createInitGit
                )
            }

            // Canonicalize the path
            guard let canonicalPath = PathUtilities.canonicalize(projectPath) else {
                throw SessionCreationError.invalidPath(projectPath)
            }

            // Create session via AppState
            // Convert EngineType to AIProvider for the session
            await appState.createSessionWithWorktree(
                name: effectiveSessionName,
                projectPath: canonicalPath,
                trustMode: selectedTrustMode,
                baseBranch: selectedBaseBranch.isEmpty ? nil : selectedBaseBranch,
                provider: selectedProvider.aiProvider
            )

            dismiss()
        } catch {
            validationError = error.localizedDescription
        }

        isCreating = false
    }

    private func createNewProject(name: String, parent: URL, initGit: Bool) async throws -> String {
        let sanitized = DirectorySourcePicker.sanitizeProjectName(name)
        guard !sanitized.isEmpty else {
            throw SessionCreationError.emptyProjectName
        }

        let targetDir = parent.appendingPathComponent(sanitized)

        // Check if directory already exists
        if FileManager.default.fileExists(atPath: targetDir.path) {
            throw SessionCreationError.directoryExists(sanitized)
        }

        // Create directory
        try FileManager.default.createDirectory(
            at: targetDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Initialize git if requested
        if initGit && gitInstalled {
            try await gitManager.initRepository(at: targetDir.path, createInitialCommit: false)
        }

        return targetDir.path
    }
}

// MARK: - Session Creation Error

enum SessionCreationError: LocalizedError {
    case invalidPath(String)
    case emptyProjectName
    case directoryExists(String)
    case cloneFailed(String)
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid project path: \(path)"
        case .emptyProjectName:
            return "Project name cannot be empty"
        case .directoryExists(let name):
            return "A directory named '\(name)' already exists"
        case .cloneFailed(let reason):
            return "Clone failed: \(reason)"
        case .notImplemented(let feature):
            return "\(feature)"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Session Creation Modal") {
    SessionCreationModal()
        .environmentObject(AppState())
}
#endif
