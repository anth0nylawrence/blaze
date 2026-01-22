import Foundation

/// Protocol for syntax highlighters.
///
/// Highlighters process a TextSnapshot and return an array of HighlightSpans.
/// They should be designed to work incrementally when possible, prioritizing
/// the visible range for responsive UI.
///
/// Implementations should be Sendable and safe to call from any thread.
public protocol Highlighter: Sendable {
    /// Languages this highlighter supports
    var supportedLanguages: Set<String> { get }

    /// Highlight the given text snapshot.
    ///
    /// - Parameter snapshot: Immutable text snapshot with UTF-16 semantics
    /// - Returns: Array of highlight spans covering the processed range
    ///
    /// Implementation notes:
    /// - Use `snapshot.nsString` for all range calculations (UTF-16 safe)
    /// - Prioritize `snapshot.visibleRange` if available
    /// - For incremental updates, focus on `snapshot.editedRange` + padding
    /// - Return spans with NSRange values matching NSString indices
    func highlight(_ snapshot: TextSnapshot) async throws -> [HighlightSpan]

    /// Optional: Check if this highlighter can process incrementally
    /// Default implementation returns false
    var supportsIncremental: Bool { get }
}

// MARK: - Default Implementations

extension Highlighter {
    public var supportsIncremental: Bool { false }
}

// MARK: - Highlighter Registry

/// Registry of available highlighters
public final class HighlighterRegistry: @unchecked Sendable {
    public static let shared = HighlighterRegistry()

    private var highlighters: [any Highlighter] = []
    private let lock = NSLock()

    private init() {}

    /// Register a highlighter
    public func register(_ highlighter: any Highlighter) {
        lock.lock()
        defer { lock.unlock() }
        highlighters.append(highlighter)
    }

    /// Get a highlighter for the given language
    public func highlighter(for languageId: String) -> (any Highlighter)? {
        lock.lock()
        defer { lock.unlock() }
        return highlighters.first { $0.supportedLanguages.contains(languageId) }
    }

    /// Get all registered highlighters
    public var allHighlighters: [any Highlighter] {
        lock.lock()
        defer { lock.unlock() }
        return highlighters
    }
}
