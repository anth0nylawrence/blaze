import AppKit

/// A highlighted region of text with a style.
///
/// Critical: Uses NSRange (UTF-16) for TextKit compatibility.
public struct HighlightSpan: Sendable {
    /// Character range in UTF-16 offsets (NSString/NSRange compatible)
    public let range: NSRange

    /// Style to apply (keyword, string, comment, etc.)
    public let style: HighlightStyle

    public init(range: NSRange, style: HighlightStyle) {
        self.range = range
        self.style = style
    }

    /// Convenience initializer from location and length
    public init(location: Int, length: Int, style: HighlightStyle) {
        self.range = NSRange(location: location, length: length)
        self.style = style
    }
}

/// Semantic token types for syntax highlighting
public enum HighlightStyle: String, Sendable, CaseIterable {
    case keyword        // if, func, class, etc.
    case string         // "hello", 'world'
    case number         // 42, 3.14, 0xFF
    case comment        // // comment, /* block */
    case type           // Int, String, CustomType
    case function       // function calls
    case property       // object.property
    case `operator`     // +, -, *, /, etc.
    case punctuation    // {, }, (, ), etc.
    case variable       // variable names
    case constant       // constants, enum cases
    case attribute      // @IBAction, #pragma
    case plain          // default/fallback

    /// Get NSColor for this style using the current theme
    public var color: NSColor {
        Theme.current.color(for: self)
    }
}

/// Theme colors for syntax highlighting
public struct Theme: Sendable {
    public let keyword: NSColor
    public let string: NSColor
    public let number: NSColor
    public let comment: NSColor
    public let type: NSColor
    public let function: NSColor
    public let property: NSColor
    public let `operator`: NSColor
    public let punctuation: NSColor
    public let variable: NSColor
    public let constant: NSColor
    public let attribute: NSColor
    public let plain: NSColor

    /// Get color for a highlight style
    public func color(for style: HighlightStyle) -> NSColor {
        switch style {
        case .keyword: return keyword
        case .string: return string
        case .number: return number
        case .comment: return comment
        case .type: return type
        case .function: return function
        case .property: return property
        case .operator: return `operator`
        case .punctuation: return punctuation
        case .variable: return variable
        case .constant: return constant
        case .attribute: return attribute
        case .plain: return plain
        }
    }

    /// Default dark theme matching Ghostty aesthetic
    /// Colors match SyntaxHighlighter.Theme.dark
    public static let dark = Theme(
        keyword: NSColor(red: 0.77, green: 0.45, blue: 0.83, alpha: 1.0),     // Purple
        string: NSColor(red: 0.67, green: 0.85, blue: 0.57, alpha: 1.0),      // Green
        number: NSColor(red: 0.82, green: 0.62, blue: 0.42, alpha: 1.0),      // Orange
        comment: NSColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0),     // Gray
        type: NSColor(red: 0.52, green: 0.78, blue: 0.91, alpha: 1.0),        // Cyan
        function: NSColor(red: 0.92, green: 0.76, blue: 0.45, alpha: 1.0),    // Yellow
        property: NSColor(red: 0.82, green: 0.62, blue: 0.42, alpha: 1.0),    // Orange
        operator: NSColor(red: 0.72, green: 0.72, blue: 0.75, alpha: 1.0),    // Light gray
        punctuation: NSColor(red: 0.72, green: 0.72, blue: 0.75, alpha: 1.0), // Light gray
        variable: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0),    // Off-white
        constant: NSColor(red: 0.82, green: 0.62, blue: 0.42, alpha: 1.0),    // Orange
        attribute: NSColor(red: 0.77, green: 0.45, blue: 0.83, alpha: 1.0),   // Purple
        plain: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)        // Off-white
    )

    /// Current active theme
    public static var current: Theme { .dark }
}
