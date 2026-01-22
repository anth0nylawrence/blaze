import Foundation

/// Regex-based syntax highlighter for MVP.
///
/// Uses simple regex patterns to identify keywords, strings, numbers, and comments.
/// All regex operations use NSString/NSRange for UTF-16 correctness.
///
/// This is a stopgap until tree-sitter integration is added.
public actor RegexHighlighter: Highlighter {
    public nonisolated let supportedLanguages: Set<String>

    public init() {
        // Support all languages with keyword definitions
        self.supportedLanguages = Set(Self.keywords.keys)
    }

    public func highlight(_ snapshot: TextSnapshot) async throws -> [HighlightSpan] {
        let nsString = snapshot.nsString
        let languageId = snapshot.languageId

        // Determine range to process (visible + padding, or full document)
        let processRange = snapshot.effectiveProcessingRange(padding: 500)

        var spans: [HighlightSpan] = []

        // 1. Highlight comments first (they override everything)
        spans.append(contentsOf: highlightComments(in: nsString, range: processRange, language: languageId))

        // 2. Highlight strings
        spans.append(contentsOf: highlightStrings(in: nsString, range: processRange))

        // 3. Highlight numbers
        spans.append(contentsOf: highlightNumbers(in: nsString, range: processRange))

        // 4. Highlight keywords
        if let keywords = Self.keywords[languageId] {
            spans.append(contentsOf: highlightWords(keywords, style: .keyword, in: nsString, range: processRange))
        }

        // 5. Highlight built-in types
        if let types = Self.builtinTypes[languageId] {
            spans.append(contentsOf: highlightWords(types, style: .type, in: nsString, range: processRange))
        }

        // 6. Highlight attributes (@-prefixed for Swift, # for others)
        spans.append(contentsOf: highlightAttributes(in: nsString, range: processRange, language: languageId))

        return spans
    }

    // MARK: - Comment Highlighting

    private func highlightComments(in nsString: NSString, range: NSRange, language: String) -> [HighlightSpan] {
        var spans: [HighlightSpan] = []

        // Line comments
        let lineCommentPatterns: [String]
        switch language {
        case "python", "shell", "yaml", "ruby", "perl", "r":
            lineCommentPatterns = ["#[^\n]*"]
        case "html":
            lineCommentPatterns = ["<!--[\\s\\S]*?-->"]
        case "sql":
            lineCommentPatterns = ["--[^\n]*"]
        case "lua":
            lineCommentPatterns = ["--[^\n]*", "--\\[\\[[\\s\\S]*?\\]\\]"]
        default:
            // C-style comments (Swift, JS, TS, Go, Rust, C, C++, Java, etc.)
            lineCommentPatterns = ["//[^\n]*"]
        }

        for pattern in lineCommentPatterns {
            spans.append(contentsOf: matchPattern(pattern, style: .comment, in: nsString, range: range))
        }

        // Block comments for C-style languages
        switch language {
        case "swift", "javascript", "typescript", "go", "rust", "c", "cpp", "objc", "objcpp", "java", "kotlin", "scala", "css":
            // Non-greedy match for /* ... */
            spans.append(contentsOf: matchPattern("/\\*[\\s\\S]*?\\*/", style: .comment, in: nsString, range: range))
        default:
            break
        }

        return spans
    }

    // MARK: - String Highlighting

    private func highlightStrings(in nsString: NSString, range: NSRange) -> [HighlightSpan] {
        var spans: [HighlightSpan] = []

        // Double-quoted strings (with escape handling)
        spans.append(contentsOf: matchPattern("\"(?:[^\"\\\\]|\\\\.)*\"", style: .string, in: nsString, range: range))

        // Single-quoted strings
        spans.append(contentsOf: matchPattern("'(?:[^'\\\\]|\\\\.)*'", style: .string, in: nsString, range: range))

        // Template literals (backticks)
        spans.append(contentsOf: matchPattern("`(?:[^`\\\\]|\\\\.)*`", style: .string, in: nsString, range: range))

        // Triple-quoted strings (Python, Swift)
        spans.append(contentsOf: matchPattern("\"\"\"[\\s\\S]*?\"\"\"", style: .string, in: nsString, range: range))

        return spans
    }

    // MARK: - Number Highlighting

    private func highlightNumbers(in nsString: NSString, range: NSRange) -> [HighlightSpan] {
        // Match various number formats
        let pattern = "\\b(0x[0-9a-fA-F_]+|0b[01_]+|0o[0-7_]+|\\d[\\d_]*\\.\\d[\\d_]*([eE][+-]?\\d+)?|\\d[\\d_]*)\\b"
        return matchPattern(pattern, style: .number, in: nsString, range: range)
    }

    // MARK: - Attribute Highlighting

    private func highlightAttributes(in nsString: NSString, range: NSRange, language: String) -> [HighlightSpan] {
        var spans: [HighlightSpan] = []

        switch language {
        case "swift":
            // @attribute patterns
            spans.append(contentsOf: matchPattern("@[a-zA-Z_][a-zA-Z0-9_]*", style: .attribute, in: nsString, range: range))
            // #directive patterns
            spans.append(contentsOf: matchPattern("#[a-zA-Z_][a-zA-Z0-9_]*", style: .attribute, in: nsString, range: range))
        case "python":
            // @decorator patterns
            spans.append(contentsOf: matchPattern("@[a-zA-Z_][a-zA-Z0-9_.]*", style: .attribute, in: nsString, range: range))
        case "rust":
            // #[...] and #![...] attributes
            spans.append(contentsOf: matchPattern("#!?\\[[^\\]]*\\]", style: .attribute, in: nsString, range: range))
        case "java", "kotlin":
            // @Annotation patterns
            spans.append(contentsOf: matchPattern("@[a-zA-Z_][a-zA-Z0-9_]*", style: .attribute, in: nsString, range: range))
        case "typescript", "javascript":
            // @decorator patterns (experimental decorators)
            spans.append(contentsOf: matchPattern("@[a-zA-Z_][a-zA-Z0-9_]*", style: .attribute, in: nsString, range: range))
        default:
            break
        }

        return spans
    }

    // MARK: - Word Highlighting

    private func highlightWords(_ words: Set<String>, style: HighlightStyle, in nsString: NSString, range: NSRange) -> [HighlightSpan] {
        var spans: [HighlightSpan] = []

        for word in words {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            spans.append(contentsOf: matchPattern(pattern, style: style, in: nsString, range: range))
        }

        return spans
    }

    // MARK: - Pattern Matching Helper

    private func matchPattern(_ pattern: String, style: HighlightStyle, in nsString: NSString, range: NSRange) -> [HighlightSpan] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        // Clamp range to string bounds
        let safeRange = NSRange(
            location: max(0, range.location),
            length: min(range.length, nsString.length - max(0, range.location))
        )

        guard safeRange.length > 0 else { return [] }

        let matches = regex.matches(in: nsString as String, options: [], range: safeRange)

        return matches.map { match in
            HighlightSpan(range: match.range, style: style)
        }
    }

    // MARK: - Keyword Definitions

    /// Keywords by language (reused from SyntaxHighlighter)
    private static let keywords: [String: Set<String>] = [
        "swift": [
            "func", "var", "let", "struct", "class", "enum", "protocol", "import",
            "if", "else", "guard", "switch", "case", "for", "while", "return",
            "private", "public", "internal", "fileprivate", "open", "static", "final",
            "async", "await", "throws", "throw", "try", "catch", "self", "Self", "nil",
            "true", "false", "init", "deinit", "extension", "where", "in", "as", "is",
            "typealias", "associatedtype", "mutating", "nonmutating", "inout", "some",
            "weak", "unowned", "lazy", "override", "required", "convenience", "dynamic",
            "defer", "repeat", "break", "continue", "fallthrough", "default", "do",
            "willSet", "didSet", "get", "set", "subscript", "operator", "precedencegroup",
            "any", "actor", "nonisolated", "isolated", "sending", "borrowing", "consuming"
        ],
        "python": [
            "def", "class", "import", "from", "if", "elif", "else", "for", "while",
            "return", "try", "except", "finally", "raise", "with", "as", "pass",
            "break", "continue", "lambda", "yield", "async", "await", "None",
            "True", "False", "and", "or", "not", "in", "is", "global", "nonlocal",
            "assert", "del", "match", "case"
        ],
        "javascript": [
            "function", "const", "let", "var", "class", "import", "export",
            "if", "else", "switch", "case", "for", "while", "return", "async",
            "await", "try", "catch", "throw", "new", "this", "super", "null",
            "undefined", "true", "false", "default", "from", "extends", "static",
            "get", "set", "of", "in", "typeof", "instanceof", "delete", "void",
            "yield", "debugger", "with", "break", "continue", "finally"
        ],
        "typescript": [
            "function", "const", "let", "var", "class", "import", "export",
            "if", "else", "switch", "case", "for", "while", "return", "async",
            "await", "try", "catch", "throw", "new", "this", "super", "null",
            "undefined", "true", "false", "interface", "type", "enum", "as",
            "implements", "extends", "readonly", "private", "public", "protected",
            "abstract", "declare", "namespace", "module", "keyof", "infer", "never",
            "unknown", "any", "void", "is", "asserts", "satisfies"
        ],
        "shell": [
            "if", "then", "else", "elif", "fi", "case", "esac", "for", "while",
            "do", "done", "in", "function", "return", "exit", "local", "export",
            "source", "alias", "unalias", "set", "unset", "shift", "break",
            "continue", "true", "false", "read", "echo", "printf"
        ],
        "go": [
            "func", "var", "const", "type", "struct", "interface", "package", "import",
            "if", "else", "switch", "case", "for", "range", "return", "defer",
            "go", "chan", "select", "break", "continue", "fallthrough", "default",
            "map", "make", "new", "len", "cap", "append", "copy", "delete", "nil",
            "true", "false", "iota"
        ],
        "rust": [
            "fn", "let", "mut", "const", "static", "struct", "enum", "trait", "impl",
            "use", "mod", "pub", "crate", "super", "self", "Self", "if", "else",
            "match", "for", "while", "loop", "return", "break", "continue", "move",
            "async", "await", "dyn", "where", "as", "in", "ref", "type", "unsafe",
            "extern", "true", "false", "Some", "None", "Ok", "Err"
        ],
        "json": [],
        "markdown": [],
        "yaml": ["true", "false", "null", "yes", "no", "on", "off"],
        "html": [],
        "css": [
            "import", "media", "keyframes", "font-face", "supports", "charset",
            "namespace", "page", "viewport", "counter-style", "font-feature-values"
        ]
    ]

    /// Built-in types by language (reused from SyntaxHighlighter)
    private static let builtinTypes: [String: Set<String>] = [
        "swift": [
            "Int", "String", "Bool", "Double", "Float", "Array", "Dictionary", "Set",
            "Optional", "Result", "Error", "Any", "AnyObject", "Void", "Never",
            "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Character", "StaticString", "Substring", "Data", "Date", "URL", "UUID",
            "CGFloat", "CGPoint", "CGSize", "CGRect", "NSObject"
        ],
        "python": [
            "int", "str", "bool", "float", "list", "dict", "set", "tuple",
            "None", "type", "object", "bytes", "bytearray", "complex", "frozenset",
            "range", "slice", "property", "classmethod", "staticmethod"
        ],
        "typescript": [
            "string", "number", "boolean", "object", "any", "unknown", "never", "void",
            "null", "undefined", "Array", "Map", "Set", "Promise", "Record", "Partial",
            "Required", "Readonly", "Pick", "Omit", "Exclude", "Extract", "NonNullable"
        ],
        "go": [
            "int", "int8", "int16", "int32", "int64",
            "uint", "uint8", "uint16", "uint32", "uint64", "uintptr",
            "float32", "float64", "complex64", "complex128",
            "string", "bool", "byte", "rune", "error"
        ],
        "rust": [
            "i8", "i16", "i32", "i64", "i128", "isize",
            "u8", "u16", "u32", "u64", "u128", "usize",
            "f32", "f64", "bool", "char", "str", "String",
            "Vec", "Option", "Result", "Box", "Rc", "Arc", "Cell", "RefCell"
        ]
    ]
}
