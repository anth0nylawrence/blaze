import Foundation

// MARK: - DirectorySource

/// How a session's working directory was obtained.
///
/// Used in the session creation wizard to track the source of the project:
/// - **browse**: User selected an existing folder
/// - **clone**: Repository was cloned from URL
/// - **create**: New project was created
///
/// **E005-F001-S001-T001-A001**
public enum DirectorySource: String, Codable, CaseIterable, Sendable, Hashable {
    case browse
    case clone
    case create

    // MARK: - Display Properties

    /// Human-readable source name.
    public var displayName: String {
        switch self {
        case .browse: return "Browse"
        case .clone: return "Clone"
        case .create: return "Create"
        }
    }

    /// SF Symbol icon for UI.
    public var icon: String {
        switch self {
        case .browse: return "folder"
        case .clone: return "arrow.down.circle"
        case .create: return "plus.circle"
        }
    }

    /// Descriptive text for wizard UI.
    public var description: String {
        switch self {
        case .browse: return "Select an existing project folder"
        case .clone: return "Clone a Git repository"
        case .create: return "Create a new project"
        }
    }
}
