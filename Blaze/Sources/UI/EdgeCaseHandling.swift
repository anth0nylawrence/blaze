import SwiftUI
import AppKit

// MARK: - Edge Case Handling

/// Edge case handlers for session creation and file viewing.
///
/// **Phase 2.10 - Polish:**
/// Handles these scenarios gracefully:
/// - Git not installed
/// - Claude CLI not installed
/// - Repo moved/deleted
/// - Binary file in viewer
/// - Worktree deletion fails

// MARK: - Git Not Installed Banner

/// Warning banner shown when git is not installed.
struct GitNotInstalledBanner: View {
    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.ds.warning)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("Git is not installed")
                    .dsTextStyle(.body, color: .ds.warning)
                    .fontWeight(.medium)

                Text("Install git to enable worktree isolation for sessions.")
                    .dsTextStyle(.caption, color: .ds.secondary)
            }

            Spacer()

            Link("Install Git", destination: URL(string: "https://git-scm.com/download/mac")!)
                .buttonStyle(.bordered)
        }
        .padding(DSSpacing.md)
        .background(Color.ds.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
    }
}

// MARK: - CLI Not Installed Modal

/// Error modal shown when the required CLI is not installed.
struct CLINotInstalledModal: View {
    let engineType: EngineType
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            // Icon
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.negative)

            // Title
            Text("\(engineType.rawValue) Not Found")
                .font(.title2)
                .fontWeight(.semibold)

            // Description
            Text("The \(engineType.rawValue) command-line tool is required to use this engine. Please install it to continue.")
                .dsTextStyle(.body, color: .ds.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            // Installation instructions
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Installation:")
                    .dsTextStyle(.caption, color: .ds.tertiary)

                Text(installationInstructions)
                    .dsTextStyle(.monoSmall)
                    .padding(DSSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ds.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            HStack(spacing: DSSpacing.md) {
                if let downloadURL = downloadURL {
                    Link("Download", destination: downloadURL)
                        .buttonStyle(.borderedProminent)
                }

                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DSSpacing.xl)
        .frame(width: 400)
        .background(Color.ds.bg1)
    }

    private var installationInstructions: String {
        switch engineType {
        case .claude:
            return "npm install -g @anthropic-ai/claude-code"
        case .gemini:
            return "npm install -g @google/gemini-cli"
        case .codex:
            return "npm install -g @openai/codex-cli"
        }
    }

    private var downloadURL: URL? {
        switch engineType {
        case .claude:
            return URL(string: "https://www.npmjs.com/package/@anthropic-ai/claude-code")
        case .gemini:
            return URL(string: "https://www.npmjs.com/package/@google/gemini-cli")
        case .codex:
            return URL(string: "https://www.npmjs.com/package/@openai/codex-cli")
        }
    }
}

// MARK: - Repo Not Found View

/// View shown when the repository path no longer exists.
struct RepoNotFoundView: View {
    let originalPath: String
    let onLocateRepo: () -> Void
    let onRemoveSession: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            // Icon
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.warning)

            // Title
            Text("Repository Not Found")
                .font(.title2)
                .fontWeight(.semibold)

            // Description
            VStack(spacing: DSSpacing.sm) {
                Text("The project directory could not be found:")
                    .dsTextStyle(.body, color: .ds.secondary)

                Text(originalPath)
                    .dsTextStyle(.monoSmall, color: .ds.tertiary)
                    .padding(DSSpacing.sm)
                    .background(Color.ds.surface.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))

                Text("The directory may have been moved, renamed, or deleted.")
                    .dsTextStyle(.caption, color: .ds.tertiary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 350)

            // Actions
            HStack(spacing: DSSpacing.md) {
                Button {
                    onLocateRepo()
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Locate Repo")
                    }
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    onRemoveSession()
                } label: {
                    Text("Remove Session")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DSSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ds.bg0.opacity(0.5))
    }
}

// MARK: - Binary File View

/// View shown when attempting to view a binary file.
struct BinaryFileView: View {
    let filePath: String
    let fileSize: Int64?

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            // Icon
            Image(systemName: "doc.zipper")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.tertiary)

            // Title
            Text("Binary File")
                .font(.title2)
                .fontWeight(.semibold)

            // Description
            VStack(spacing: DSSpacing.sm) {
                Text("This file cannot be displayed as text.")
                    .dsTextStyle(.body, color: .ds.secondary)

                HStack(spacing: DSSpacing.lg) {
                    VStack(alignment: .leading) {
                        Text("File")
                            .dsTextStyle(.micro, color: .ds.tertiary)
                        Text((filePath as NSString).lastPathComponent)
                            .dsTextStyle(.monoSmall)
                    }

                    if let size = fileSize {
                        VStack(alignment: .leading) {
                            Text("Size")
                                .dsTextStyle(.micro, color: .ds.tertiary)
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                .dsTextStyle(.monoSmall)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Type")
                            .dsTextStyle(.micro, color: .ds.tertiary)
                        Text(fileType)
                            .dsTextStyle(.monoSmall)
                    }
                }
                .padding(DSSpacing.md)
                .background(Color.ds.surface.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
            }
            .multilineTextAlignment(.center)

            // Actions
            HStack(spacing: DSSpacing.md) {
                Button {
                    openInFinder()
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("Reveal in Finder")
                    }
                }
                .buttonStyle(.bordered)

                Button {
                    openWithDefaultApp()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.forward.app")
                        Text("Open with Default App")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DSSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ds.bg0.opacity(0.3))
    }

    private var fileType: String {
        let ext = (filePath as NSString).pathExtension.lowercased()
        return BinaryFileDetector.fileTypeDescription(for: ext)
    }

    private func openInFinder() {
        let url = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

    private func openWithDefaultApp() {
        let url = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Binary File Detector

/// Utility to detect binary files.
struct BinaryFileDetector {
    /// Known binary file extensions.
    static let binaryExtensions: Set<String> = [
        // Executables
        "exe", "dll", "so", "dylib", "a", "o", "obj",
        // Archives
        "zip", "tar", "gz", "bz2", "xz", "7z", "rar",
        // Images
        "png", "jpg", "jpeg", "gif", "bmp", "ico", "webp", "heic", "heif", "tiff", "tif",
        // Audio
        "mp3", "wav", "ogg", "flac", "aac", "m4a", "wma",
        // Video
        "mp4", "mov", "avi", "mkv", "webm", "wmv", "flv",
        // Documents
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        // Data
        "sqlite", "db", "realm",
        // Other
        "class", "jar", "wasm", "pyc", "pyo",
        // Xcode
        "xcarchive", "ipa", "app",
    ]

    /// Check if a file extension indicates a binary file.
    static func isBinaryExtension(_ ext: String) -> Bool {
        binaryExtensions.contains(ext.lowercased())
    }

    /// Check if file content appears to be binary.
    /// Checks for null bytes in the first 8KB.
    static func isBinaryContent(_ data: Data) -> Bool {
        let checkSize = min(data.count, 8192)
        let bytes = data.prefix(checkSize)
        return bytes.contains(0)
    }

    /// Get a human-readable file type description.
    static func fileTypeDescription(for ext: String) -> String {
        switch ext.lowercased() {
        case "png", "jpg", "jpeg", "gif", "bmp", "ico", "webp", "heic", "heif", "tiff", "tif":
            return "Image"
        case "mp3", "wav", "ogg", "flac", "aac", "m4a", "wma":
            return "Audio"
        case "mp4", "mov", "avi", "mkv", "webm", "wmv", "flv":
            return "Video"
        case "pdf":
            return "PDF Document"
        case "doc", "docx":
            return "Word Document"
        case "xls", "xlsx":
            return "Excel Spreadsheet"
        case "ppt", "pptx":
            return "PowerPoint"
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar":
            return "Archive"
        case "exe", "dll":
            return "Windows Executable"
        case "so", "dylib":
            return "Shared Library"
        case "sqlite", "db":
            return "Database"
        default:
            return "Binary File"
        }
    }
}

// MARK: - Worktree Deletion Failed Alert

/// Alert shown when worktree deletion fails.
struct WorktreeDeletionFailedAlert: ViewModifier {
    @Binding var isPresented: Bool
    let worktreePath: String
    let error: String
    let onRetryForce: () -> Void
    let onSkip: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Worktree Deletion Failed", isPresented: $isPresented) {
                Button("Retry with Force") {
                    onRetryForce()
                }
                Button("Keep Worktree") {
                    onSkip()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                VStack {
                    Text("Failed to delete the worktree at:")
                    Text(worktreePath)
                        .font(.caption)
                    Text("\nError: \(error)")
                    Text("\nYou can retry with force option (will discard uncommitted changes) or keep the worktree.")
                }
            }
    }
}

extension View {
    func worktreeDeletionFailedAlert(
        isPresented: Binding<Bool>,
        worktreePath: String,
        error: String,
        onRetryForce: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) -> some View {
        self.modifier(WorktreeDeletionFailedAlert(
            isPresented: isPresented,
            worktreePath: worktreePath,
            error: error,
            onRetryForce: onRetryForce,
            onSkip: onSkip
        ))
    }
}

// MARK: - Directory Picker with Validation

/// Directory picker that validates the selected path.
struct ValidatingDirectoryPicker {
    /// Pick a directory and validate it.
    static func pick(
        title: String = "Select Directory",
        validateAsGitRepo: Bool = false,
        completion: @escaping (Result<URL, DirectoryPickerError>) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = title
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            // Check if directory exists
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                completion(.failure(.notADirectory))
                return
            }

            // Check if it's a git repo if required
            if validateAsGitRepo {
                let gitDir = url.appendingPathComponent(".git")
                if !FileManager.default.fileExists(atPath: gitDir.path) {
                    completion(.failure(.notAGitRepository))
                    return
                }
            }

            completion(.success(url))
        } else {
            completion(.failure(.cancelled))
        }
    }
}

/// Errors from directory picker validation.
enum DirectoryPickerError: Error, LocalizedError {
    case cancelled
    case notADirectory
    case notAGitRepository
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Selection cancelled"
        case .notADirectory:
            return "Selected path is not a directory"
        case .notAGitRepository:
            return "Selected directory is not a git repository"
        case .accessDenied:
            return "Access denied to selected directory"
        }
    }
}

// MARK: - Previews

#Preview("Git Not Installed Banner") {
    GitNotInstalledBanner()
        .padding()
        .background(Color.ds.bg0)
}

#Preview("CLI Not Installed Modal") {
    CLINotInstalledModal(engineType: .claude, onDismiss: {})
}

#Preview("Repo Not Found") {
    RepoNotFoundView(
        originalPath: "/Users/dev/old-project",
        onLocateRepo: {},
        onRemoveSession: {}
    )
}

#Preview("Binary File View") {
    BinaryFileView(
        filePath: "/Users/dev/project/image.png",
        fileSize: 1_234_567
    )
}
