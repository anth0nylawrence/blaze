import SwiftUI
import AppKit

// MARK: - Directory Source Result

/// The complete result from DirectorySourcePicker, including all state for the selected mode.
///
/// **E005-F001-S001-T003-A001:**
/// This struct captures the full form state, while DirectorySource (in Core) is the segment enum.
public struct DirectorySourceResult: Equatable {
    /// Which mode is selected
    public let source: DirectorySource

    /// For browse mode: the selected directory path
    public let browsePath: URL?

    /// For clone mode: the repository URL
    public let cloneURL: String

    /// For clone mode: where to clone to
    public let cloneDestination: URL?

    /// For clone mode: whether to use shallow clone
    public let cloneShallow: Bool

    /// For create mode: the project name
    public let createName: String

    /// For create mode: the parent folder
    public let createParent: URL

    /// For create mode: whether to init git
    public let createInitGit: Bool

    /// Whether the current selection is complete and valid
    public var isComplete: Bool {
        switch source {
        case .browse:
            return browsePath != nil

        case .clone:
            return !cloneURL.isEmpty &&
                   DirectorySourcePicker.validateGitURL(cloneURL) &&
                   cloneDestination != nil

        case .create:
            let sanitized = DirectorySourcePicker.sanitizeProjectName(createName)
            return !sanitized.isEmpty
        }
    }

    /// The resolved path for the session
    public var resolvedPath: URL? {
        switch source {
        case .browse:
            return browsePath
        case .clone:
            return cloneDestination
        case .create:
            let sanitized = DirectorySourcePicker.sanitizeProjectName(createName)
            guard !sanitized.isEmpty else { return nil }
            return createParent.appendingPathComponent(sanitized)
        }
    }
}

// MARK: - Directory Source Picker

/// A segmented picker for selecting how to specify a session's working directory.
/// Supports three modes: Browse (existing folder), Clone (git repo), Create (new project).
///
/// State for each mode is preserved when switching between segments.
///
/// **E005-F001-S001-T003-A001 Implementation:**
/// - Segmented control for Browse/Clone/Create modes
/// - Each mode shows appropriate input fields
/// - State preserved across segment switches
/// - Callback with selected DirectorySourceResult
public struct DirectorySourcePicker: View {
    /// The complete state result, updated when any field changes
    @Binding var result: DirectorySourceResult

    // MARK: - Internal State (preserved across segment switches)

    @State private var selectedSource: DirectorySource
    @State private var browsePath: URL?
    @State private var cloneURL: String = ""
    @State private var cloneDestination: URL?
    @State private var cloneShallow: Bool = false
    @State private var createName: String = ""
    @State private var createParent: URL
    @State private var createInitGit: Bool = true

    // External cloning state (controlled by parent)
    @Binding var isCloning: Bool

    // MARK: - Init

    public init(result: Binding<DirectorySourceResult>, isCloning: Binding<Bool> = .constant(false)) {
        self._result = result
        self._isCloning = isCloning

        // Initialize from current result
        let r = result.wrappedValue
        _selectedSource = State(initialValue: r.source)
        _browsePath = State(initialValue: r.browsePath)
        _cloneURL = State(initialValue: r.cloneURL)
        _cloneDestination = State(initialValue: r.cloneDestination)
        _cloneShallow = State(initialValue: r.cloneShallow)
        _createName = State(initialValue: r.createName)
        _createParent = State(initialValue: r.createParent)
        _createInitGit = State(initialValue: r.createInitGit)
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            // Segmented picker using existing DirectorySource enum
            Picker("Source", selection: $selectedSource) {
                ForEach(DirectorySource.allCases, id: \.self) { source in
                    Label(source.displayName, systemImage: source.icon)
                        .tag(source)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: selectedSource) { _, _ in
                updateResult()
            }

            // Conditional content based on segment
            Group {
                switch selectedSource {
                case .browse:
                    BrowseDirectoryView(selectedPath: $browsePath)
                        .onChange(of: browsePath) { _, _ in updateResult() }

                case .clone:
                    CloneRepositoryView(
                        repositoryURL: $cloneURL,
                        destination: $cloneDestination,
                        shallow: $cloneShallow,
                        isCloning: $isCloning
                    )
                    .onChange(of: cloneURL) { _, _ in updateResult() }
                    .onChange(of: cloneDestination) { _, _ in updateResult() }
                    .onChange(of: cloneShallow) { _, _ in updateResult() }

                case .create:
                    CreateProjectView(
                        name: $createName,
                        parent: $createParent,
                        initGit: $createInitGit
                    )
                    .onChange(of: createName) { _, _ in updateResult() }
                    .onChange(of: createParent) { _, _ in updateResult() }
                    .onChange(of: createInitGit) { _, _ in updateResult() }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: selectedSource)
        }
    }

    // MARK: - Private Methods

    private func updateResult() {
        result = DirectorySourceResult(
            source: selectedSource,
            browsePath: browsePath,
            cloneURL: cloneURL,
            cloneDestination: cloneDestination,
            cloneShallow: cloneShallow,
            createName: createName,
            createParent: createParent,
            createInitGit: createInitGit
        )
    }

    // MARK: - Static Helpers

    /// Validates a Git repository URL format.
    /// Supports HTTPS, SSH (git@), and git:// protocols.
    public static func validateGitURL(_ url: String) -> Bool {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // HTTPS pattern: https://host/path.git or https://host/path
        let httpsPattern = #"^https://[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+(/[-a-zA-Z0-9._~:/?#\[\]@!$&'()*+,;=%]+)?$"#

        // SSH pattern: git@host:user/repo.git
        let sshPattern = #"^git@[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+:[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(\.git)?$"#

        // Git protocol pattern: git://host/path
        let gitPattern = #"^git://[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+(/[-a-zA-Z0-9._~:/?#\[\]@!$&'()*+,;=%]+)?$"#

        let patterns = [httpsPattern, sshPattern, gitPattern]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                return true
            }
        }

        return false
    }

    /// Sanitizes a project name for use as a filesystem directory name.
    public static func sanitizeProjectName(_ name: String) -> String {
        var sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Replace spaces with hyphens
        sanitized = sanitized.replacingOccurrences(of: " ", with: "-")

        // Remove invalid filesystem characters
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?*\"<>|\0")
        sanitized = sanitized.components(separatedBy: invalidCharacters).joined()

        // Remove path traversal attempts
        sanitized = sanitized.replacingOccurrences(of: "..", with: "")

        // Remove leading/trailing dots and hyphens
        while sanitized.hasPrefix(".") || sanitized.hasPrefix("-") {
            sanitized.removeFirst()
        }
        while !sanitized.isEmpty && (sanitized.hasSuffix(".") || sanitized.hasSuffix("-")) {
            sanitized.removeLast()
        }

        // Collapse multiple hyphens
        while sanitized.contains("--") {
            sanitized = sanitized.replacingOccurrences(of: "--", with: "-")
        }

        return sanitized
    }
}

// MARK: - Default Result Factory

public extension DirectorySourceResult {
    /// Creates a default result with browse mode selected
    static var defaultBrowse: DirectorySourceResult {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return DirectorySourceResult(
            source: .browse,
            browsePath: nil,
            cloneURL: "",
            cloneDestination: nil,
            cloneShallow: false,
            createName: "",
            createParent: documentsURL,
            createInitGit: true
        )
    }
}

// MARK: - Browse Directory View

/// View for browsing and selecting an existing local directory.
public struct BrowseDirectoryView: View {
    @Binding var selectedPath: URL?

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.sm) {
                // Path display
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "folder")
                        .foregroundStyle(Color.ds.secondary)

                    Text(pathDisplayText)
                        .dsTextStyle(.body, color: selectedPath == nil ? .ds.tertiary : .ds.foreground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)

                // Browse button
                GlassButton("Browse", icon: "folder.badge.plus", style: .secondary, size: .medium) {
                    openDirectoryPanel()
                }
            }

            if let path = selectedPath {
                Text("Full path: \(path.path)")
                    .dsTextStyle(.caption, color: .ds.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var pathDisplayText: String {
        if let path = selectedPath {
            return path.lastPathComponent
        }
        return "No directory selected"
    }

    private func openDirectoryPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a project directory"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            // Resolve symlinks to get actual path
            selectedPath = url.resolvingSymlinksInPath()
        }
    }
}

// MARK: - Clone Repository View

/// View for cloning a remote Git repository.
public struct CloneRepositoryView: View {
    @Binding var repositoryURL: String
    @Binding var destination: URL?
    @Binding var shallow: Bool
    @Binding var isCloning: Bool

    @State private var useCustomDestination: Bool = false

    private var isURLValid: Bool {
        DirectorySourcePicker.validateGitURL(repositoryURL)
    }

    private var autoDestinationName: String {
        // Extract repo name from URL
        let trimmed = repositoryURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

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
            // For SSH format git@github.com:user/repo, get the repo part
            if let slashIndex = name.lastIndex(of: "/") {
                name = String(name[name.index(after: slashIndex)...])
            }
        }

        return name
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            // Repository URL field
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Repository URL")
                    .dsTextStyle(.caption, color: .ds.secondary)

                HStack(spacing: DSSpacing.sm) {
                    GlassTextField("https://github.com/user/repo.git", text: $repositoryURL, icon: "link")
                        .disabled(isCloning)

                    // Validation indicator
                    if !repositoryURL.isEmpty {
                        Image(systemName: isURLValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isURLValid ? Color.ds.positive : Color.ds.negative)
                            .help(isURLValid ? "Valid Git URL format" : "Invalid URL format")
                    }
                }
            }

            // Clone destination
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Clone to")
                    .dsTextStyle(.caption, color: .ds.secondary)

                HStack(spacing: DSSpacing.sm) {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "folder")
                            .foregroundStyle(Color.ds.secondary)

                        Text(destinationDisplayText)
                            .dsTextStyle(.body, color: destination == nil ? .ds.tertiary : .ds.foreground)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)
                    .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)

                    GlassButton("Change", icon: "folder.badge.plus", style: .secondary, size: .medium) {
                        selectDestinationFolder()
                    }
                    .disabled(isCloning)
                }

                if !autoDestinationName.isEmpty && !useCustomDestination {
                    Text("Will clone to: \(autoDestinationName)")
                        .dsTextStyle(.caption, color: .ds.tertiary)
                }
            }

            // Shallow clone toggle
            GlassToggle("Shallow clone (faster)", isOn: $shallow, description: "Downloads only recent history")
                .disabled(isCloning)

            // Cloning progress
            if isCloning {
                HStack(spacing: DSSpacing.sm) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Cloning repository...")
                        .dsTextStyle(.body, color: .ds.secondary)
                }
                .padding(DSSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
            }
        }
    }

    private var destinationDisplayText: String {
        if let dest = destination {
            return dest.path
        }
        return "Select destination folder"
    }

    private func selectDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select destination folder for clone"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            useCustomDestination = true
            let repoName = autoDestinationName.isEmpty ? "repository" : autoDestinationName
            destination = url.appendingPathComponent(repoName)
        }
    }
}

// MARK: - Create Project View

/// View for creating a new project folder.
public struct CreateProjectView: View {
    @Binding var name: String
    @Binding var parent: URL
    @Binding var initGit: Bool

    private var sanitizedName: String {
        DirectorySourcePicker.sanitizeProjectName(name)
    }

    private var computedPath: URL? {
        guard !sanitizedName.isEmpty else { return nil }
        return parent.appendingPathComponent(sanitizedName)
    }

    private var folderExists: Bool {
        guard let path = computedPath else { return false }
        return FileManager.default.fileExists(atPath: path.path)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            // Project name field
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Project name")
                    .dsTextStyle(.caption, color: .ds.secondary)

                GlassTextField("my-project", text: $name, icon: "doc.text")
            }

            // Name sanitization warning
            if !name.isEmpty && sanitizedName != name && !sanitizedName.isEmpty {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.ds.info)
                    Text("Will be created as: \(sanitizedName)")
                        .dsTextStyle(.caption, color: .ds.info)
                }
            }

            // Empty name warning
            if !name.isEmpty && sanitizedName.isEmpty {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.ds.warning)
                    Text("Name contains only invalid characters")
                        .dsTextStyle(.caption, color: .ds.warning)
                }
            }

            // Parent folder selection
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Location")
                    .dsTextStyle(.caption, color: .ds.secondary)

                HStack(spacing: DSSpacing.sm) {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "folder")
                            .foregroundStyle(Color.ds.secondary)

                        Text(parent.path)
                            .dsTextStyle(.body)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)
                    .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)

                    GlassButton("Change", icon: "folder.badge.plus", style: .secondary, size: .medium) {
                        selectParentFolder()
                    }
                }
            }

            // Computed path preview
            if let path = computedPath {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("Full path")
                        .dsTextStyle(.caption, color: .ds.secondary)

                    HStack(spacing: DSSpacing.xs) {
                        Text(path.path)
                            .dsTextStyle(.mono, color: .ds.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if folderExists {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.ds.warning)
                                .help("Folder already exists")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)
                    .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
                }

                if folderExists {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.ds.warning)
                        Text("A folder with this name already exists")
                            .dsTextStyle(.caption, color: .ds.warning)
                    }
                }
            }

            // Git init toggle
            GlassToggle("Initialize Git repository", isOn: $initGit, description: "Creates a git repo in the new folder")
        }
    }

    private func selectParentFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select parent folder for new project"
        panel.prompt = "Select"
        panel.directoryURL = parent

        if panel.runModal() == .OK, let url = panel.url {
            parent = url.resolvingSymlinksInPath()
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Directory Source Picker - Browse") {
    DirectorySourcePickerPreview()
}

private struct DirectorySourcePickerPreview: View {
    @State var result: DirectorySourceResult = .defaultBrowse
    @State var isCloning = false

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            DirectorySourcePicker(result: $result, isCloning: $isCloning)

            Divider()

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Current Selection:")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Group {
                    Text("Mode: \(result.source.displayName)")
                    Text("Is Complete: \(result.isComplete ? "Yes" : "No")")
                        .foregroundStyle(result.isComplete ? Color.ds.positive : Color.ds.negative)
                    if let path = result.resolvedPath {
                        Text("Path: \(path.path)")
                    }
                }
                .dsTextStyle(.mono)
            }
        }
        .padding(DSSpacing.lg)
        .frame(width: 450)
        .background(Color.ds.bg1)
    }
}
#endif
