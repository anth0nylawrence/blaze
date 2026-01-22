import AppKit

/// Coordinates diagnostics display for an editor buffer.
///
/// Critical design:
/// - Uses SEPARATE attribute layer from highlights (underlineStyle, not foregroundColor)
/// - This prevents diagnostics from stomping on syntax highlighting
/// - Stores diagnostic info in custom attribute for hover tooltips
@MainActor
public final class DiagnosticsCoordinator {
    /// The text view we're coordinating diagnostics for
    private weak var textView: NSTextView?

    /// Current diagnostics (for external access)
    public private(set) var diagnostics: [Diagnostic] = []

    /// Track ranges we've applied diagnostics to
    private var appliedRanges: [NSRange] = []

    public init() {}

    /// Attach to a text view
    public func attach(to textView: NSTextView) {
        self.textView = textView
    }

    /// Detach from the current text view
    public func detach() {
        clearAllDiagnostics()
        textView = nil
    }

    /// Apply diagnostics as underline squiggles.
    ///
    /// Uses a SEPARATE attribute layer from syntax highlighting:
    /// - Highlights use: .foregroundColor
    /// - Diagnostics use: .underlineStyle + .underlineColor + .diagnosticInfo
    ///
    /// - Parameter diagnostics: Diagnostics from providers
    public func applyDiagnostics(_ newDiagnostics: [Diagnostic]) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else {
            return
        }

        let documentLength = textStorage.length
        guard documentLength > 0 else { return }

        // 1. Clear previous diagnostic attributes (NOT highlight attributes!)
        for range in appliedRanges {
            let safeRange = clampRange(range, to: documentLength)
            if safeRange.length > 0 {
                layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: safeRange)
                layoutManager.removeTemporaryAttribute(.underlineColor, forCharacterRange: safeRange)
                layoutManager.removeTemporaryAttribute(.diagnosticInfo, forCharacterRange: safeRange)
            }
        }

        // 2. Apply new diagnostics
        var newAppliedRanges: [NSRange] = []

        for diagnostic in newDiagnostics {
            // Validate range
            guard diagnostic.range.location >= 0,
                  diagnostic.range.location + diagnostic.range.length <= documentLength else {
                continue
            }

            let range = diagnostic.range

            // Apply underline style based on severity
            layoutManager.addTemporaryAttribute(
                .underlineStyle,
                value: diagnostic.severity.underlineStyle.rawValue,
                forCharacterRange: range
            )

            // Apply underline color based on severity
            layoutManager.addTemporaryAttribute(
                .underlineColor,
                value: diagnostic.severity.nsColor,
                forCharacterRange: range
            )

            // Store diagnostic info for hover tooltip
            layoutManager.addTemporaryAttribute(
                .diagnosticInfo,
                value: diagnostic,
                forCharacterRange: range
            )

            newAppliedRanges.append(range)
        }

        self.diagnostics = newDiagnostics
        self.appliedRanges = newAppliedRanges
    }

    /// Clear all diagnostic underlines
    public func clearAllDiagnostics() {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else {
            return
        }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: fullRange)
        layoutManager.removeTemporaryAttribute(.underlineColor, forCharacterRange: fullRange)
        layoutManager.removeTemporaryAttribute(.diagnosticInfo, forCharacterRange: fullRange)

        diagnostics = []
        appliedRanges = []
    }

    /// Get diagnostic at a character position (for hover tooltip)
    public func diagnostic(at characterIndex: Int) -> Diagnostic? {
        for diagnostic in diagnostics {
            if NSLocationInRange(characterIndex, diagnostic.range) {
                return diagnostic
            }
        }
        return nil
    }

    /// Get all diagnostics intersecting a range
    public func diagnostics(in range: NSRange) -> [Diagnostic] {
        diagnostics.filter { NSIntersectionRange($0.range, range).length > 0 }
    }

    // MARK: - Helpers

    private func clampRange(_ range: NSRange, to length: Int) -> NSRange {
        let start = max(0, min(range.location, length))
        let end = max(start, min(range.location + range.length, length))
        return NSRange(location: start, length: end - start)
    }
}

// MARK: - Diagnostic Counts

extension DiagnosticsCoordinator {
    /// Count of error-level diagnostics
    public var errorCount: Int {
        diagnostics.filter { $0.severity == .error }.count
    }

    /// Count of warning-level diagnostics
    public var warningCount: Int {
        diagnostics.filter { $0.severity == .warning }.count
    }

    /// Count of info-level diagnostics
    public var infoCount: Int {
        diagnostics.filter { $0.severity == .info }.count
    }

    /// Count of hint-level diagnostics
    public var hintCount: Int {
        diagnostics.filter { $0.severity == .hint }.count
    }
}
