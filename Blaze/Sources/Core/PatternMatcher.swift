import Foundation

// MARK: - Pattern Matcher

/// Pattern matching system for Claude Code hook matchers.
///
/// Supports the following patterns:
/// - Exact match: `"Read"` matches "Read"
/// - Wildcard: `"*"` matches anything
/// - Glob patterns: `"Bash*"` matches "Bash", "BashTool", etc.
/// - Character class: `"[RB]ead"` matches "Read" or "Bead"
/// - Single char wildcard: `"Re?d"` matches "Read", "Reed", etc.
/// - Arrays: `["Read", "Bash"]` matches any in list
/// - Case-insensitive mode for flexible matching
///
/// **E005-F009-S001-T002-A001**
public struct PatternMatcher: Sendable {

    /// Compiled pattern for efficient repeated matching
    private let compiledPatterns: [CompiledPattern]

    /// Whether matching is case-insensitive
    public let caseInsensitive: Bool

    // MARK: - Initialization

    /// Create a matcher from a single pattern string
    public init(pattern: String, caseInsensitive: Bool = false) {
        self.caseInsensitive = caseInsensitive
        self.compiledPatterns = [CompiledPattern(pattern: pattern, caseInsensitive: caseInsensitive)]
    }

    /// Create a matcher from multiple patterns (match any)
    public init(patterns: [String], caseInsensitive: Bool = false) {
        self.caseInsensitive = caseInsensitive
        self.compiledPatterns = patterns.map { CompiledPattern(pattern: $0, caseInsensitive: caseInsensitive) }
    }

    /// Create a matcher from a JSON-compatible value (string or array)
    public init?(jsonValue: Any, caseInsensitive: Bool = false) {
        self.caseInsensitive = caseInsensitive

        if let pattern = jsonValue as? String {
            self.compiledPatterns = [CompiledPattern(pattern: pattern, caseInsensitive: caseInsensitive)]
        } else if let patterns = jsonValue as? [String] {
            guard !patterns.isEmpty else { return nil }
            self.compiledPatterns = patterns.map { CompiledPattern(pattern: $0, caseInsensitive: caseInsensitive) }
        } else {
            return nil
        }
    }

    // MARK: - Matching

    /// Check if the input matches any of the patterns
    public func matches(_ input: String) -> Bool {
        let normalizedInput = caseInsensitive ? input.lowercased() : input
        return compiledPatterns.contains { $0.matches(normalizedInput) }
    }

    /// Find the first matching pattern, if any
    public func firstMatch(_ input: String) -> String? {
        let normalizedInput = caseInsensitive ? input.lowercased() : input
        return compiledPatterns.first { $0.matches(normalizedInput) }?.originalPattern
    }

    /// Check if any input in the collection matches
    public func matchesAny<S: Sequence>(_ inputs: S) -> Bool where S.Element == String {
        inputs.contains { matches($0) }
    }

    /// Filter inputs to only those that match
    public func filter<S: Sequence>(_ inputs: S) -> [String] where S.Element == String {
        inputs.filter { matches($0) }
    }

    /// Raw patterns (for serialization/debugging)
    public var rawPatterns: [String] {
        compiledPatterns.map(\.originalPattern)
    }

    /// Whether this matcher matches all inputs (universal wildcard)
    public var matchesAll: Bool {
        compiledPatterns.count == 1 && compiledPatterns[0].originalPattern == "*"
    }
}

// MARK: - Compiled Pattern

/// Pre-compiled pattern for efficient matching
private struct CompiledPattern: Sendable {
    let originalPattern: String
    let matchType: MatchType

    init(pattern: String, caseInsensitive: Bool) {
        self.originalPattern = pattern
        let normalizedPattern = caseInsensitive ? pattern.lowercased() : pattern
        self.matchType = MatchType.compile(normalizedPattern)
    }

    func matches(_ input: String) -> Bool {
        matchType.matches(input)
    }
}

// MARK: - Match Type

/// Optimized match strategies
private enum MatchType: Sendable {
    /// Matches anything
    case wildcard

    /// Exact string match (fastest)
    case exact(String)

    /// Prefix match: "foo*"
    case prefix(String)

    /// Suffix match: "*foo"
    case suffix(String)

    /// Contains match: "*foo*"
    case contains(String)

    /// Full glob pattern (slowest, most flexible)
    case glob(GlobPattern)

    /// Compile a pattern into the most efficient match type
    static func compile(_ pattern: String) -> MatchType {
        // Universal wildcard
        if pattern == "*" {
            return .wildcard
        }

        // Check for special glob characters
        let hasGlobChars = pattern.contains { char in
            char == "*" || char == "?" || char == "[" || char == "]"
        }

        if !hasGlobChars {
            // No glob chars = exact match
            return .exact(pattern)
        }

        // Simple prefix: "foo*" with no other special chars
        if pattern.hasSuffix("*") && !pattern.dropLast().contains(where: { $0 == "*" || $0 == "?" || $0 == "[" }) {
            return .prefix(String(pattern.dropLast()))
        }

        // Simple suffix: "*foo" with no other special chars
        if pattern.hasPrefix("*") && !pattern.dropFirst().contains(where: { $0 == "*" || $0 == "?" || $0 == "[" }) {
            return .suffix(String(pattern.dropFirst()))
        }

        // Simple contains: "*foo*" with no other special chars
        if pattern.hasPrefix("*") && pattern.hasSuffix("*") {
            let inner = String(pattern.dropFirst().dropLast())
            if !inner.contains(where: { $0 == "*" || $0 == "?" || $0 == "[" }) {
                return .contains(inner)
            }
        }

        // Fall back to full glob matching
        return .glob(GlobPattern(pattern: pattern))
    }

    func matches(_ input: String) -> Bool {
        switch self {
        case .wildcard:
            return true
        case .exact(let expected):
            return input == expected
        case .prefix(let prefix):
            return input.hasPrefix(prefix)
        case .suffix(let suffix):
            return input.hasSuffix(suffix)
        case .contains(let substring):
            return input.contains(substring)
        case .glob(let globPattern):
            return globPattern.matches(input)
        }
    }
}

// MARK: - Glob Pattern

/// Full glob pattern matcher supporting *, ?, and [abc] character classes
private struct GlobPattern: Sendable {
    private let segments: [GlobSegment]

    init(pattern: String) {
        self.segments = Self.parse(pattern)
    }

    func matches(_ input: String) -> Bool {
        var inputIndex = input.startIndex
        var segmentIndex = 0

        // Backtracking state for * wildcards
        var lastStarInputIndex: String.Index?
        var lastStarSegmentIndex: Int?

        while inputIndex < input.endIndex || segmentIndex < segments.count {
            if segmentIndex < segments.count {
                let segment = segments[segmentIndex]

                switch segment {
                case .literal(let char):
                    if inputIndex < input.endIndex && input[inputIndex] == char {
                        inputIndex = input.index(after: inputIndex)
                        segmentIndex += 1
                        continue
                    }

                case .singleWildcard:
                    if inputIndex < input.endIndex {
                        inputIndex = input.index(after: inputIndex)
                        segmentIndex += 1
                        continue
                    }

                case .multiWildcard:
                    // Save backtrack point
                    lastStarInputIndex = inputIndex
                    lastStarSegmentIndex = segmentIndex
                    segmentIndex += 1
                    continue

                case .charClass(let chars, let negated):
                    if inputIndex < input.endIndex {
                        let char = input[inputIndex]
                        let inClass = chars.contains(char)
                        if negated ? !inClass : inClass {
                            inputIndex = input.index(after: inputIndex)
                            segmentIndex += 1
                            continue
                        }
                    }
                }
            }

            // If we have a backtrack point, try consuming one more char
            if let starInput = lastStarInputIndex,
               let starSegment = lastStarSegmentIndex,
               starInput < input.endIndex {
                lastStarInputIndex = input.index(after: starInput)
                inputIndex = lastStarInputIndex!
                segmentIndex = starSegment + 1
                continue
            }

            // No match and no backtrack available
            return false
        }

        return true
    }

    private static func parse(_ pattern: String) -> [GlobSegment] {
        var segments: [GlobSegment] = []
        var index = pattern.startIndex

        while index < pattern.endIndex {
            let char = pattern[index]

            switch char {
            case "*":
                // Collapse consecutive *
                if case .multiWildcard = segments.last {
                    // Already have a *, skip
                } else {
                    segments.append(.multiWildcard)
                }

            case "?":
                segments.append(.singleWildcard)

            case "[":
                // Parse character class
                let (charClass, newIndex) = parseCharClass(pattern, from: pattern.index(after: index))
                segments.append(charClass)
                index = newIndex
                continue

            default:
                segments.append(.literal(char))
            }

            index = pattern.index(after: index)
        }

        return segments
    }

    private static func parseCharClass(_ pattern: String, from startIndex: String.Index) -> (GlobSegment, String.Index) {
        var chars: Set<Character> = []
        var index = startIndex
        var negated = false

        // Check for negation
        if index < pattern.endIndex && (pattern[index] == "!" || pattern[index] == "^") {
            negated = true
            index = pattern.index(after: index)
        }

        while index < pattern.endIndex {
            let char = pattern[index]

            if char == "]" && !chars.isEmpty {
                return (.charClass(chars, negated: negated), index)
            }

            // Check for range: a-z
            let nextIndex = pattern.index(after: index)
            if nextIndex < pattern.endIndex && pattern[nextIndex] == "-" {
                let rangeEndIndex = pattern.index(after: nextIndex)
                if rangeEndIndex < pattern.endIndex && pattern[rangeEndIndex] != "]" {
                    let rangeEnd = pattern[rangeEndIndex]
                    // Add all chars in range
                    if let start = char.asciiValue, let end = rangeEnd.asciiValue, start <= end {
                        for ascii in start...end {
                            chars.insert(Character(UnicodeScalar(ascii)))
                        }
                    }
                    index = pattern.index(after: rangeEndIndex)
                    continue
                }
            }

            chars.insert(char)
            index = pattern.index(after: index)
        }

        // Unclosed bracket - treat as literal
        return (.literal("["), startIndex)
    }
}

// MARK: - Glob Segment

private enum GlobSegment: Sendable {
    case literal(Character)
    case singleWildcard    // ?
    case multiWildcard     // *
    case charClass(Set<Character>, negated: Bool)  // [abc] or [!abc]
}

// MARK: - Pattern Utilities

public extension PatternMatcher {

    /// Create a matcher that matches common file operation tools
    static var fileTools: PatternMatcher {
        PatternMatcher(patterns: ["Read", "Write", "Edit", "Glob", "NotebookEdit"])
    }

    /// Create a matcher that matches shell/execution tools
    static var shellTools: PatternMatcher {
        PatternMatcher(patterns: ["Bash", "Task"])
    }

    /// Create a matcher that matches search tools
    static var searchTools: PatternMatcher {
        PatternMatcher(patterns: ["Grep", "Glob", "WebSearch", "WebFetch"])
    }

    /// Create a matcher that matches all tools
    static var allTools: PatternMatcher {
        PatternMatcher(pattern: "*")
    }

    /// Create a matcher for MCP tool patterns (e.g., "mcp__*")
    static var mcpTools: PatternMatcher {
        PatternMatcher(pattern: "mcp__*")
    }
}

// MARK: - Equatable

extension PatternMatcher: Equatable {
    public static func == (lhs: PatternMatcher, rhs: PatternMatcher) -> Bool {
        lhs.compiledPatterns.map(\.originalPattern) == rhs.compiledPatterns.map(\.originalPattern) &&
        lhs.caseInsensitive == rhs.caseInsensitive
    }
}

// MARK: - Hashable

extension PatternMatcher: Hashable {
    public func hash(into hasher: inout Hasher) {
        for pattern in compiledPatterns {
            hasher.combine(pattern.originalPattern)
        }
        hasher.combine(caseInsensitive)
    }
}

// MARK: - CustomStringConvertible

extension PatternMatcher: CustomStringConvertible {
    public var description: String {
        let patterns = compiledPatterns.map(\.originalPattern).joined(separator: ", ")
        let suffix = caseInsensitive ? " (case-insensitive)" : ""
        return "PatternMatcher([\(patterns)]\(suffix))"
    }
}

// MARK: - Convenience Functions

/// Quick pattern matching without creating a matcher (for one-off checks)
public func matchesGlobPattern(_ pattern: String, _ input: String, caseInsensitive: Bool = false) -> Bool {
    let matcher = PatternMatcher(pattern: pattern, caseInsensitive: caseInsensitive)
    return matcher.matches(input)
}

/// Quick pattern matching against multiple patterns
public func matchesAnyGlobPattern(_ patterns: [String], _ input: String, caseInsensitive: Bool = false) -> Bool {
    let matcher = PatternMatcher(patterns: patterns, caseInsensitive: caseInsensitive)
    return matcher.matches(input)
}
