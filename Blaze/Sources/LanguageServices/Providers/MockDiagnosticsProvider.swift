import Foundation

/// Mock diagnostics provider for MVP.
///
/// Detects common patterns like TODO/FIXME comments and debug statements.
/// This is enough to wire up the diagnostics UI end-to-end.
public actor MockDiagnosticsProvider: DiagnosticsProvider {
    public nonisolated let providerId: String = "blaze.mock"
    public nonisolated let displayName: String = "Blaze (Built-in)"
    public nonisolated let supportedLanguages: Set<String> = []  // All languages

    public init() {}

    public func provideDiagnostics(_ snapshot: TextSnapshot) async throws -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        let nsString = snapshot.nsString
        let processRange = snapshot.effectiveProcessingRange(padding: 1000)

        // Detect TODO/FIXME/HACK/XXX comments
        diagnostics.append(contentsOf: detectTodoComments(in: nsString, range: processRange, fileURL: snapshot.fileURL))

        // Detect debug print statements
        diagnostics.append(contentsOf: detectDebugStatements(in: nsString, range: processRange, language: snapshot.languageId, fileURL: snapshot.fileURL))

        // Detect force unwraps in Swift
        if snapshot.languageId == "swift" {
            diagnostics.append(contentsOf: detectForceUnwraps(in: nsString, range: processRange, fileURL: snapshot.fileURL))
        }

        return diagnostics
    }

    // MARK: - TODO/FIXME Detection

    private func detectTodoComments(in nsString: NSString, range: NSRange, fileURL: URL?) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []

        let patterns: [(String, DiagnosticSeverity, String)] = [
            ("TODO:", .info, "TODO comment"),
            ("FIXME:", .warning, "FIXME comment"),
            ("HACK:", .warning, "HACK comment"),
            ("XXX:", .warning, "XXX marker"),
            ("BUG:", .error, "Known bug marker"),
            ("DEPRECATED:", .warning, "Deprecated code")
        ]

        for (marker, severity, message) in patterns {
            let pattern = "(?i)\(NSRegularExpression.escapedPattern(for: marker))\\s*(.*)$"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
                continue
            }

            let safeRange = clampRange(range, to: nsString.length)
            let matches = regex.matches(in: nsString as String, options: [], range: safeRange)

            for match in matches {
                let fullRange = match.range
                let lineInfo = lineAndColumn(for: fullRange.location, in: nsString)

                // Extract the comment text if captured
                var fullMessage = message
                if match.numberOfRanges > 1 {
                    let textRange = match.range(at: 1)
                    if textRange.location != NSNotFound {
                        let text = nsString.substring(with: textRange).trimmingCharacters(in: .whitespaces)
                        if !text.isEmpty {
                            fullMessage = "\(message): \(text)"
                        }
                    }
                }

                diagnostics.append(Diagnostic(
                    range: fullRange,
                    severity: severity,
                    message: fullMessage,
                    code: marker.replacingOccurrences(of: ":", with: "").lowercased(),
                    source: providerId,
                    fileURL: fileURL,
                    line: lineInfo.line,
                    column: lineInfo.column
                ))
            }
        }

        return diagnostics
    }

    // MARK: - Debug Statement Detection

    private func detectDebugStatements(in nsString: NSString, range: NSRange, language: String, fileURL: URL?) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []

        let patterns: [String]
        switch language {
        case "swift":
            patterns = ["\\bprint\\s*\\(", "\\bdebugPrint\\s*\\(", "\\bdump\\s*\\("]
        case "python":
            patterns = ["\\bprint\\s*\\(", "\\bbreakpoint\\s*\\(", "\\bpdb\\.set_trace\\s*\\("]
        case "javascript", "typescript":
            patterns = ["\\bconsole\\.log\\s*\\(", "\\bconsole\\.debug\\s*\\(", "\\bdebugger\\b"]
        case "go":
            patterns = ["\\bfmt\\.Print", "\\bfmt\\.Println", "\\blog\\.Print"]
        case "rust":
            patterns = ["\\bprintln!\\s*\\(", "\\bdbg!\\s*\\(", "\\beprintln!\\s*\\("]
        default:
            return []
        }

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }

            let safeRange = clampRange(range, to: nsString.length)
            let matches = regex.matches(in: nsString as String, options: [], range: safeRange)

            for match in matches {
                let lineInfo = lineAndColumn(for: match.range.location, in: nsString)

                diagnostics.append(Diagnostic(
                    range: match.range,
                    severity: .hint,
                    message: "Debug statement - consider removing before commit",
                    code: "debug-statement",
                    source: providerId,
                    fileURL: fileURL,
                    line: lineInfo.line,
                    column: lineInfo.column
                ))
            }
        }

        return diagnostics
    }

    // MARK: - Swift Force Unwrap Detection

    private func detectForceUnwraps(in nsString: NSString, range: NSRange, fileURL: URL?) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []

        // Match force unwrap (!) but not != or !== or !!
        let pattern = "(?<![!=])!(?![!=])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let safeRange = clampRange(range, to: nsString.length)
        let matches = regex.matches(in: nsString as String, options: [], range: safeRange)

        for match in matches {
            let lineInfo = lineAndColumn(for: match.range.location, in: nsString)

            diagnostics.append(Diagnostic(
                range: match.range,
                severity: .hint,
                message: "Force unwrap - consider using optional binding",
                code: "force-unwrap",
                source: providerId,
                fileURL: fileURL,
                line: lineInfo.line,
                column: lineInfo.column
            ))
        }

        return diagnostics
    }

    // MARK: - Helpers

    private func clampRange(_ range: NSRange, to length: Int) -> NSRange {
        let start = max(0, min(range.location, length))
        let end = max(start, min(range.location + range.length, length))
        return NSRange(location: start, length: end - start)
    }

    private func lineAndColumn(for location: Int, in nsString: NSString) -> (line: Int, column: Int) {
        var line = 1
        var lastLineStart = 0

        let searchRange = NSRange(location: 0, length: min(location, nsString.length))
        let string = nsString as String
        let searchString = (string as NSString).substring(with: searchRange)

        for char in searchString {
            if char == "\n" {
                line += 1
                lastLineStart = 0
            } else {
                lastLineStart += 1
            }
        }

        return (line: line, column: lastLineStart + 1)
    }
}
