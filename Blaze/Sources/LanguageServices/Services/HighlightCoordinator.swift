import AppKit

/// Coordinates syntax highlighting for an editor buffer.
///
/// Critical performance design:
/// - Uses `layoutManager.addTemporaryAttribute()` for non-destructive styling
/// - INCREMENTAL clearing: only clears visible + edited ranges, never full document
/// - All operations are MainActor-bound (must interact with NSTextView)
@MainActor
public final class HighlightCoordinator {
    /// The text view we're coordinating highlights for
    private weak var textView: NSTextView?

    /// Highlighter to use for this buffer
    private let highlighter: any Highlighter

    /// Theme for colors
    private var theme: Theme = .current

    /// Track last cleared range to avoid redundant work
    private var lastClearedRange: NSRange?

    /// Padding around visible range for pre-rendering
    private let visiblePadding: Int = 500

    /// Safety margin around edited range
    private let editedMargin: Int = 200

    public init(highlighter: any Highlighter) {
        self.highlighter = highlighter
    }

    /// Attach to a text view
    public func attach(to textView: NSTextView) {
        self.textView = textView
    }

    /// Detach from the current text view
    public func detach() {
        textView = nil
        lastClearedRange = nil
    }

    /// Apply highlights from a snapshot.
    ///
    /// This method:
    /// 1. Computes the minimal clear range (visible + edited, NOT full document)
    /// 2. Clears temporary foreground color in that range only
    /// 3. Applies new highlight spans via temporary attributes
    ///
    /// - Parameters:
    ///   - spans: Highlight spans from the highlighter
    ///   - editedRange: Range that was edited (for incremental clearing)
    ///   - visibleRange: Currently visible range in viewport
    public func applyHighlights(
        _ spans: [HighlightSpan],
        editedRange: NSRange?,
        visibleRange: NSRange?
    ) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else {
            return
        }

        let documentLength = textStorage.length
        guard documentLength > 0 else { return }

        // 1. Compute clear range - INCREMENTAL, not full document
        let clearRange = computeClearRange(
            editedRange: editedRange,
            visibleRange: visibleRange,
            documentLength: documentLength
        )

        // 2. Clear temporary attributes only in the affected range
        //    Using .foregroundColor for highlights (diagnostics use .underlineStyle)
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: clearRange)

        // 3. Apply spans that intersect the clear range
        for span in spans {
            // Validate range is within document bounds
            guard span.range.location >= 0,
                  span.range.location + span.range.length <= documentLength else {
                continue
            }

            // Only apply if span intersects the range we cleared
            guard NSIntersectionRange(span.range, clearRange).length > 0 else {
                continue
            }

            layoutManager.addTemporaryAttribute(
                .foregroundColor,
                value: span.style.color,
                forCharacterRange: span.range
            )
        }

        lastClearedRange = clearRange
    }

    /// Clear all highlights (e.g., when disabling syntax highlighting)
    public func clearAllHighlights() {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else {
            return
        }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)
        lastClearedRange = nil
    }

    /// Update theme colors
    public func setTheme(_ theme: Theme) {
        self.theme = theme
    }

    // MARK: - Private Helpers

    /// Compute the minimal range to clear for incremental updates.
    ///
    /// This is critical for performance - we only clear:
    /// - visible range + padding (for smooth scrolling)
    /// - edited range + margin (for accurate updates around edits)
    ///
    /// We NEVER clear the full document on every keystroke.
    private func computeClearRange(
        editedRange: NSRange?,
        visibleRange: NSRange?,
        documentLength: Int
    ) -> NSRange {
        guard documentLength > 0 else {
            return NSRange(location: 0, length: 0)
        }

        var start = 0
        var end = documentLength

        // If we have a visible range, use it as the primary constraint
        // Guard against NSNotFound, out-of-bounds values, and arithmetic overflow
        if let visible = visibleRange,
           visible.location != NSNotFound,
           visible.location >= 0,
           visible.location <= documentLength,
           visible.length > 0,
           visible.length <= documentLength {
            // Use subtraction to avoid overflow: visibleEnd = min(docLen, loc + len)
            // Rewrite as: if docLen - loc >= len then visibleEnd = loc + len else visibleEnd = docLen
            let remainingAfterLoc = documentLength - visible.location
            let visibleEnd = remainingAfterLoc >= visible.length
                ? visible.location + visible.length
                : documentLength
            start = max(0, visible.location - visiblePadding)
            end = min(documentLength, visibleEnd + visiblePadding)
        }

        // Expand to include edited range + safety margin
        // Guard against NSNotFound, out-of-bounds values, and arithmetic overflow
        if let edited = editedRange,
           edited.location != NSNotFound,
           edited.location >= 0,
           edited.location <= documentLength,
           edited.length >= 0,
           edited.length <= documentLength {
            // Safe computation of editEnd to avoid overflow
            let remainingAfterLoc = documentLength - edited.location
            let editEnd = remainingAfterLoc >= edited.length
                ? edited.location + edited.length
                : documentLength
            let editStart = max(0, edited.location - editedMargin)
            let editEndPadded = min(documentLength, editEnd + editedMargin)
            start = min(start, editStart)
            end = max(end, editEndPadded)
        }

        // Clamp to document bounds
        start = max(0, start)
        end = min(documentLength, end)

        return NSRange(location: start, length: max(0, end - start))
    }
}

// MARK: - Convenience Extensions

extension HighlightCoordinator {
    /// Process a snapshot and apply highlights
    public func process(_ snapshot: TextSnapshot) async {
        do {
            let spans = try await highlighter.highlight(snapshot)

            // Apply on main actor (we're already MainActor, but being explicit)
            applyHighlights(
                spans,
                editedRange: snapshot.editedRange,
                visibleRange: snapshot.visibleRange
            )
        } catch {
            // Log error but don't crash - highlighting is non-critical
            print("[HighlightCoordinator] Highlight error: \(error)")
        }
    }
}
