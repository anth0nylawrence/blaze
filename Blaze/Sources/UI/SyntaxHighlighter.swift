import SwiftUI

// MARK: - Syntax Highlighter

/// Shared syntax highlighting utility for Swift, Python, JavaScript/TypeScript, JSON, Markdown, and Shell
enum SyntaxHighlighter {

    // MARK: - Language Detection

    /// Detected language for a file
    enum Language: String, CaseIterable {
        case swift
        case python
        case javascript
        case typescript
        case json
        case markdown
        case shell
        case yaml
        case css
        case html
        case go
        case rust
        case unknown

        /// Get language from file extension
        static func from(extension ext: String) -> Language {
            switch ext.lowercased() {
            case "swift": return .swift
            case "py": return .python
            case "js", "jsx", "mjs", "cjs": return .javascript
            case "ts", "tsx": return .typescript
            case "json", "jsonl": return .json
            case "md", "markdown": return .markdown
            case "sh", "bash", "zsh", "fish": return .shell
            case "yaml", "yml": return .yaml
            case "css", "scss", "less": return .css
            case "html", "htm": return .html
            case "go": return .go
            case "rs": return .rust
            default: return .unknown
            }
        }

        /// Icon for the language
        var icon: String {
            switch self {
            case .swift: return "swift"
            case .python: return "number"
            case .javascript, .typescript: return "chevron.left.forwardslash.chevron.right"
            case .json: return "curlybraces"
            case .markdown: return "doc.text"
            case .shell: return "terminal"
            case .yaml: return "list.bullet"
            case .css: return "paintbrush"
            case .html: return "globe"
            case .go: return "g.circle"
            case .rust: return "gear"
            case .unknown: return "doc"
            }
        }

        /// Color associated with the language
        var color: Color {
            switch self {
            case .swift: return .orange
            case .python: return .blue
            case .javascript: return .yellow
            case .typescript: return .blue
            case .json: return .green
            case .markdown: return .gray
            case .shell: return .green
            case .yaml: return .purple
            case .css: return .pink
            case .html: return .red
            case .go: return .cyan
            case .rust: return .orange
            case .unknown: return .secondary
            }
        }
    }

    // MARK: - Syntax Theme

    /// Theme colors for syntax highlighting
    struct Theme {
        let keyword: Color
        let string: Color
        let number: Color
        let comment: Color
        let type: Color
        let function: Color
        let property: Color
        let `operator`: Color
        let punctuation: Color
        let plain: Color

        /// Default dark theme matching Ghostty aesthetic
        static let dark = Theme(
            keyword: Color(red: 0.77, green: 0.45, blue: 0.83),   // Purple
            string: Color(red: 0.67, green: 0.85, blue: 0.57),    // Green
            number: Color(red: 0.82, green: 0.62, blue: 0.42),    // Orange
            comment: Color(red: 0.55, green: 0.55, blue: 0.55),   // Gray
            type: Color(red: 0.52, green: 0.78, blue: 0.91),      // Cyan
            function: Color(red: 0.92, green: 0.76, blue: 0.45),  // Yellow
            property: Color(red: 0.82, green: 0.62, blue: 0.42),  // Orange
            operator: Color(red: 0.72, green: 0.72, blue: 0.75),  // Light gray
            punctuation: Color(red: 0.72, green: 0.72, blue: 0.75),
            plain: Color(red: 0.85, green: 0.85, blue: 0.85)      // Off-white
        )

        /// Current theme (could be user-configurable)
        static var current: Theme { .dark }
    }

    // MARK: - Keywords by Language

    private static let keywords: [Language: Set<String>] = [
        .swift: [
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
        .python: [
            "def", "class", "import", "from", "if", "elif", "else", "for", "while",
            "return", "try", "except", "finally", "raise", "with", "as", "pass",
            "break", "continue", "lambda", "yield", "async", "await", "None",
            "True", "False", "and", "or", "not", "in", "is", "global", "nonlocal",
            "assert", "del", "match", "case"
        ],
        .javascript: [
            "function", "const", "let", "var", "class", "import", "export",
            "if", "else", "switch", "case", "for", "while", "return", "async",
            "await", "try", "catch", "throw", "new", "this", "super", "null",
            "undefined", "true", "false", "default", "from", "extends", "static",
            "get", "set", "of", "in", "typeof", "instanceof", "delete", "void",
            "yield", "debugger", "with", "break", "continue", "finally"
        ],
        .typescript: [
            "function", "const", "let", "var", "class", "import", "export",
            "if", "else", "switch", "case", "for", "while", "return", "async",
            "await", "try", "catch", "throw", "new", "this", "super", "null",
            "undefined", "true", "false", "interface", "type", "enum", "as",
            "implements", "extends", "readonly", "private", "public", "protected",
            "abstract", "declare", "namespace", "module", "keyof", "infer", "never",
            "unknown", "any", "void", "is", "asserts", "satisfies"
        ],
        .shell: [
            "if", "then", "else", "elif", "fi", "case", "esac", "for", "while",
            "do", "done", "in", "function", "return", "exit", "local", "export",
            "source", "alias", "unalias", "set", "unset", "shift", "break",
            "continue", "true", "false", "read", "echo", "printf"
        ],
        .go: [
            "func", "var", "const", "type", "struct", "interface", "package", "import",
            "if", "else", "switch", "case", "for", "range", "return", "defer",
            "go", "chan", "select", "break", "continue", "fallthrough", "default",
            "map", "make", "new", "len", "cap", "append", "copy", "delete", "nil",
            "true", "false", "iota"
        ],
        .rust: [
            "fn", "let", "mut", "const", "static", "struct", "enum", "trait", "impl",
            "use", "mod", "pub", "crate", "super", "self", "Self", "if", "else",
            "match", "for", "while", "loop", "return", "break", "continue", "move",
            "async", "await", "dyn", "where", "as", "in", "ref", "type", "unsafe",
            "extern", "true", "false", "Some", "None", "Ok", "Err"
        ]
    ]

    // MARK: - Built-in Types by Language

    private static let builtinTypes: [Language: Set<String>] = [
        .swift: [
            "Int", "String", "Bool", "Double", "Float", "Array", "Dictionary", "Set",
            "Optional", "Result", "Error", "Any", "AnyObject", "Void", "Never",
            "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Character", "StaticString", "Substring", "Data", "Date", "URL", "UUID",
            "CGFloat", "CGPoint", "CGSize", "CGRect", "NSObject"
        ],
        .python: [
            "int", "str", "bool", "float", "list", "dict", "set", "tuple",
            "None", "type", "object", "bytes", "bytearray", "complex", "frozenset",
            "range", "slice", "property", "classmethod", "staticmethod"
        ],
        .typescript: [
            "string", "number", "boolean", "object", "any", "unknown", "never", "void",
            "null", "undefined", "Array", "Map", "Set", "Promise", "Record", "Partial",
            "Required", "Readonly", "Pick", "Omit", "Exclude", "Extract", "NonNullable"
        ],
        .go: [
            "int", "int8", "int16", "int32", "int64",
            "uint", "uint8", "uint16", "uint32", "uint64", "uintptr",
            "float32", "float64", "complex64", "complex128",
            "string", "bool", "byte", "rune", "error"
        ],
        .rust: [
            "i8", "i16", "i32", "i64", "i128", "isize",
            "u8", "u16", "u32", "u64", "u128", "usize",
            "f32", "f64", "bool", "char", "str", "String",
            "Vec", "Option", "Result", "Box", "Rc", "Arc", "Cell", "RefCell"
        ]
    ]

    // MARK: - Highlight Line

    /// Apply syntax highlighting to a line of code
    static func highlight(
        _ text: String,
        language: Language,
        theme: Theme = .current
    ) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = theme.plain

        // Handle comments first (they override everything)
        if isCommentLine(text, language: language) {
            attributed.foregroundColor = theme.comment
            return attributed
        }

        // Apply keyword highlighting
        if let langKeywords = keywords[language] {
            for keyword in langKeywords {
                highlightWord(&attributed, word: keyword, color: theme.keyword, in: text)
            }
        }

        // Apply type highlighting
        if let langTypes = builtinTypes[language] {
            for typeName in langTypes {
                highlightWord(&attributed, word: typeName, color: theme.type, in: text)
            }
        }

        // Highlight strings
        highlightStrings(&attributed, text: text, color: theme.string)

        // Highlight numbers
        highlightNumbers(&attributed, text: text, color: theme.number)

        return attributed
    }

    /// Highlight a single line for diff display
    static func highlightForDiff(
        _ text: String,
        fileExtension: String,
        theme: Theme = .current
    ) -> AttributedString {
        let language = Language.from(extension: fileExtension)
        return highlight(text, language: language, theme: theme)
    }

    // MARK: - Private Helpers

    private static func isCommentLine(_ text: String, language: Language) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        switch language {
        case .swift, .javascript, .typescript, .go, .rust, .css:
            return trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*")
        case .python, .shell, .yaml:
            return trimmed.hasPrefix("#")
        case .html:
            return trimmed.hasPrefix("<!--")
        case .markdown:
            return false // Markdown doesn't have code comments
        case .json:
            return false // JSON doesn't support comments
        case .unknown:
            return trimmed.hasPrefix("//") || trimmed.hasPrefix("#")
        }
    }

    private static func highlightWord(
        _ attributed: inout AttributedString,
        word: String,
        color: Color,
        in originalText: String
    ) {
        // Simple word boundary matching
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let nsString = originalText as NSString
        let matches = regex.matches(in: originalText, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            if let swiftRange = Range(match.range, in: originalText),
               let attributedRange = Range(swiftRange, in: attributed) {
                attributed[attributedRange].foregroundColor = color
            }
        }
    }

    private static func highlightStrings(
        _ attributed: inout AttributedString,
        text: String,
        color: Color
    ) {
        // Match double-quoted and single-quoted strings
        let patterns = [
            "\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"",  // Double-quoted
            "'[^'\\\\]*(\\\\.[^'\\\\]*)*'",      // Single-quoted
            "`[^`]*`"                            // Template literals
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                if let swiftRange = Range(match.range, in: text),
                   let attributedRange = Range(swiftRange, in: attributed) {
                    attributed[attributedRange].foregroundColor = color
                }
            }
        }
    }

    private static func highlightNumbers(
        _ attributed: inout AttributedString,
        text: String,
        color: Color
    ) {
        // Match various number formats
        let pattern = "\\b(0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+|\\d+\\.\\d+|\\d+)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            if let swiftRange = Range(match.range, in: text),
               let attributedRange = Range(swiftRange, in: attributed) {
                attributed[attributedRange].foregroundColor = color
            }
        }
    }
}

// MARK: - Syntax Highlighted Text View

/// SwiftUI view that displays syntax-highlighted text
struct SyntaxHighlightedText: View {
    let text: String
    let language: SyntaxHighlighter.Language
    let theme: SyntaxHighlighter.Theme

    init(
        _ text: String,
        language: SyntaxHighlighter.Language,
        theme: SyntaxHighlighter.Theme = .current
    ) {
        self.text = text
        self.language = language
        self.theme = theme
    }

    init(
        _ text: String,
        fileExtension: String,
        theme: SyntaxHighlighter.Theme = .current
    ) {
        self.text = text
        self.language = SyntaxHighlighter.Language.from(extension: fileExtension)
        self.theme = theme
    }

    var body: some View {
        Text(SyntaxHighlighter.highlight(text, language: language, theme: theme))
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
    }
}

// MARK: - Syntax Highlighted Code Block

/// Multi-line code block with syntax highlighting and line numbers
struct SyntaxHighlightedCodeBlock: View {
    let code: String
    let language: SyntaxHighlighter.Language
    let showLineNumbers: Bool
    let highlightedLine: Int?
    let startLineNumber: Int

    init(
        code: String,
        language: SyntaxHighlighter.Language,
        showLineNumbers: Bool = true,
        highlightedLine: Int? = nil,
        startLineNumber: Int = 1
    ) {
        self.code = code
        self.language = language
        self.showLineNumbers = showLineNumbers
        self.highlightedLine = highlightedLine
        self.startLineNumber = startLineNumber
    }

    private var lines: [String] {
        code.components(separatedBy: .newlines)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    let lineNumber = startLineNumber + index
                    let isHighlighted = highlightedLine == lineNumber

                    HStack(alignment: .top, spacing: 0) {
                        // Line number
                        if showLineNumbers {
                            Text("\(lineNumber)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.ds.tertiary)
                                .frame(width: 40, alignment: .trailing)
                                .padding(.trailing, DSSpacing.sm)
                                .background(
                                    isHighlighted
                                        ? Color.ds.accent.opacity(0.1)
                                        : Color.ds.surface.opacity(0.3)
                                )
                        }

                        // Code line
                        Text(SyntaxHighlighter.highlight(line, language: language))
                            .font(.system(size: 13, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, DSSpacing.sm)
                    }
                    .padding(.vertical, 1)
                    .background(
                        isHighlighted
                            ? Color.ds.accent.opacity(0.1)
                            : Color.clear
                    )
                }
            }
            .padding(.vertical, DSSpacing.xs)
        }
        .background(Color.ds.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
    }
}

// MARK: - Previews

#Preview("Syntax Highlighter - Swift") {
    let swiftCode = """
    import SwiftUI

    // A sample view
    struct ContentView: View {
        @State private var count: Int = 0
        let message = "Hello, World!"

        var body: some View {
            VStack {
                Text(message)
                Button("Increment") {
                    count += 1
                }
            }
        }
    }
    """

    return ScrollView {
        SyntaxHighlightedCodeBlock(
            code: swiftCode,
            language: .swift,
            highlightedLine: 5
        )
        .frame(height: 300)
        .padding()
    }
    .background(Color.ds.bg0)
}

#Preview("Syntax Highlighter - Multiple Languages") {
    let pythonCode = """
    def hello_world():
        # Print greeting
        message = "Hello, World!"
        print(message)
        return True
    """

    let jsCode = """
    const greet = async (name) => {
        const message = `Hello, ${name}!`;
        console.log(message);
        return true;
    };
    """

    return ScrollView {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Text("Python").dsTextStyle(.subtitle)
            SyntaxHighlightedCodeBlock(code: pythonCode, language: .python)
                .frame(height: 150)

            Text("JavaScript").dsTextStyle(.subtitle)
            SyntaxHighlightedCodeBlock(code: jsCode, language: .javascript)
                .frame(height: 150)
        }
        .padding()
    }
    .background(Color.ds.bg0)
}
