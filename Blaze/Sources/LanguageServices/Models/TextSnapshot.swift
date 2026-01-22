import Foundation

/// Immutable snapshot of text content for language service processing.
///
/// Critical: Uses NSString (UTF-16) for all range operations to ensure
/// compatibility with TextKit's NSRange semantics. Emoji and combining
/// marks require UTF-16 indexed ranges to work correctly.
///
/// Note: @unchecked Sendable because NSString is immutable and thread-safe,
/// but Swift 6 strict concurrency doesn't recognize this.
public struct TextSnapshot: @unchecked Sendable {
    /// Monotonically increasing version number, bumped on each edit
    public let version: Int

    /// File URL if available (for language detection, LSP identification)
    public let fileURL: URL?

    /// Detected or manually set language identifier (e.g., "swift", "python")
    public let languageId: String

    /// Source of truth for text content - UTF-16 indexed
    /// Using NSString ensures correct range semantics for TextKit operations
    public let nsString: NSString

    /// Range that changed in this edit (for incremental processing)
    /// nil for initial load or full document replacement
    public let editedRange: NSRange?

    /// Length delta from the edit (positive for insertions, negative for deletions)
    public let changeInLength: Int

    /// Currently visible character range in the viewport (for prioritization)
    /// Highlighters should process this range first
    public let visibleRange: NSRange?

    /// Create a snapshot from current text state
    public init(
        version: Int,
        fileURL: URL? = nil,
        languageId: String = "unknown",
        nsString: NSString,
        editedRange: NSRange? = nil,
        changeInLength: Int = 0,
        visibleRange: NSRange? = nil
    ) {
        self.version = version
        self.fileURL = fileURL
        self.languageId = languageId
        self.nsString = nsString
        self.editedRange = editedRange
        self.changeInLength = changeInLength
        self.visibleRange = visibleRange
    }

    /// Convenience: create snapshot from Swift String
    public init(
        version: Int,
        fileURL: URL? = nil,
        languageId: String = "unknown",
        string: String,
        editedRange: NSRange? = nil,
        changeInLength: Int = 0,
        visibleRange: NSRange? = nil
    ) {
        self.init(
            version: version,
            fileURL: fileURL,
            languageId: languageId,
            nsString: string as NSString,
            editedRange: editedRange,
            changeInLength: changeInLength,
            visibleRange: visibleRange
        )
    }

    /// Total length in UTF-16 code units
    public var length: Int {
        nsString.length
    }

    /// Full document range
    public var fullRange: NSRange {
        NSRange(location: 0, length: nsString.length)
    }

    /// Get substring for a range (returns nil if range is invalid)
    public func substring(with range: NSRange) -> String? {
        guard range.location >= 0,
              range.location + range.length <= nsString.length else {
            return nil
        }
        return nsString.substring(with: range)
    }

    /// Compute line range containing the given character index
    public func lineRange(containing characterIndex: Int) -> NSRange {
        guard characterIndex >= 0 && characterIndex <= nsString.length else {
            return NSRange(location: 0, length: 0)
        }
        return nsString.lineRange(for: NSRange(location: characterIndex, length: 0))
    }

    /// Get all line ranges in the document
    public func allLineRanges() -> [NSRange] {
        var ranges: [NSRange] = []
        var index = 0
        while index < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: index, length: 0))
            ranges.append(lineRange)
            index = lineRange.location + lineRange.length
        }
        // Handle empty document or trailing newline
        if ranges.isEmpty || (nsString.length > 0 && (nsString.substring(from: nsString.length - 1) == "\n")) {
            // Don't add extra empty line - lineRange handles this
        }
        return ranges
    }

    /// Compute effective range to process (visible + edited with padding)
    public func effectiveProcessingRange(padding: Int = 500) -> NSRange {
        let docLength = nsString.length
        guard docLength > 0 else {
            return NSRange(location: 0, length: 0)
        }

        var start = 0
        var end = docLength

        // If we have visible range, constrain to that + padding
        // Guard against NSNotFound, out-of-bounds, and arithmetic overflow
        if let visible = visibleRange,
           visible.location != NSNotFound,
           visible.location >= 0,
           visible.location <= docLength,
           visible.length >= 0,
           visible.length <= docLength {
            // Safe computation to avoid overflow
            let remainingAfterLoc = docLength - visible.location
            let visibleEnd = remainingAfterLoc >= visible.length
                ? visible.location + visible.length
                : docLength
            start = max(0, visible.location - padding)
            end = min(docLength, visibleEnd + padding)
        }

        // Expand to include edited range + safety margin
        // Guard against NSNotFound, out-of-bounds, and arithmetic overflow
        if let edited = editedRange,
           edited.location != NSNotFound,
           edited.location >= 0,
           edited.location <= docLength,
           edited.length >= 0,
           edited.length <= docLength {
            let editMargin = 200
            // Safe computation to avoid overflow
            let remainingAfterLoc = docLength - edited.location
            let editEnd = remainingAfterLoc >= edited.length
                ? edited.location + edited.length
                : docLength
            start = min(start, max(0, edited.location - editMargin))
            end = max(end, min(docLength, editEnd + editMargin))
        }

        return NSRange(location: start, length: max(0, end - start))
    }
}
