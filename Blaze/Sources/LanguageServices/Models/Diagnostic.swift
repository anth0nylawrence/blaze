import AppKit

/// A diagnostic message (error, warning, info, hint) for a range of text.
///
/// Critical: Uses NSRange (UTF-16) for TextKit compatibility.
public struct Diagnostic: Sendable, Identifiable, Equatable {
    public let id: UUID

    /// Character range in UTF-16 offsets (NSString/NSRange compatible)
    public let range: NSRange

    /// Severity level
    public let severity: DiagnosticSeverity

    /// Human-readable message
    public let message: String

    /// Optional diagnostic code (e.g., "E0001", "swift-lint/force-unwrap")
    public let code: String?

    /// Source of the diagnostic (e.g., "swiftlint", "sourcekit-lsp", "blaze")
    public let source: String?

    /// File URL where this diagnostic was found
    public let fileURL: URL?

    /// Line number (1-indexed, for display)
    public let line: Int?

    /// Column number (1-indexed, for display)
    public let column: Int?

    public init(
        id: UUID = UUID(),
        range: NSRange,
        severity: DiagnosticSeverity,
        message: String,
        code: String? = nil,
        source: String? = nil,
        fileURL: URL? = nil,
        line: Int? = nil,
        column: Int? = nil
    ) {
        self.id = id
        self.range = range
        self.severity = severity
        self.message = message
        self.code = code
        self.source = source
        self.fileURL = fileURL
        self.line = line
        self.column = column
    }

    public static func == (lhs: Diagnostic, rhs: Diagnostic) -> Bool {
        lhs.id == rhs.id
    }
}

/// Severity levels for diagnostics
public enum DiagnosticSeverity: String, Sendable, CaseIterable, Comparable {
    case error
    case warning
    case info
    case hint

    /// Sort order (errors first)
    private var sortOrder: Int {
        switch self {
        case .error: return 0
        case .warning: return 1
        case .info: return 2
        case .hint: return 3
        }
    }

    public static func < (lhs: DiagnosticSeverity, rhs: DiagnosticSeverity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    /// SF Symbol name for this severity
    public var iconName: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .hint: return "lightbulb.fill"
        }
    }

    /// Color for this severity
    public var nsColor: NSColor {
        switch self {
        case .error: return NSColor.systemRed
        case .warning: return NSColor.systemYellow
        case .info: return NSColor.systemBlue
        case .hint: return NSColor.systemGray
        }
    }

    /// Underline style for this severity
    public var underlineStyle: NSUnderlineStyle {
        switch self {
        case .error: return [.single, .patternDot]
        case .warning: return .single
        case .info: return [.single, .patternDash]
        case .hint: return [.single, .patternDashDot]
        }
    }
}

// MARK: - Custom Attribute Key

extension NSAttributedString.Key {
    /// Custom attribute key for storing diagnostic info (for hover tooltips)
    public static let diagnosticInfo = NSAttributedString.Key("BlazeLanguageServices.DiagnosticInfo")
}
