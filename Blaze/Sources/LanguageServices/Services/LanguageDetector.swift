import Foundation

/// Detects programming language from file metadata and content.
///
/// Detection priority (highest to lowest):
/// 1. Manual override (user explicitly set)
/// 2. File extension
/// 3. Shebang line (#!/usr/bin/env python3)
/// 4. Modeline (vim: ft=swift, emacs: -*- mode: python -*-)
public enum LanguageDetector {

    // MARK: - Public API

    /// Detect language from file URL and optional content
    /// - Parameters:
    ///   - fileURL: File URL for extension-based detection
    ///   - content: Optional file content for shebang/modeline detection
    ///   - manualOverride: User-specified language (takes precedence)
    /// - Returns: Detected language identifier
    public static func detect(
        fileURL: URL?,
        content: String? = nil,
        manualOverride: String? = nil
    ) -> String {
        // 1. Manual override takes precedence
        if let override = manualOverride, !override.isEmpty, override != "unknown" {
            return override
        }

        // 2. Try file extension
        if let ext = fileURL?.pathExtension, !ext.isEmpty {
            let detected = languageId(for: ext)
            if detected != "unknown" {
                return detected
            }
        }

        // 3. Try shebang (first line)
        if let content = content {
            if let shebangLang = detectShebang(content) {
                return shebangLang
            }

            // 4. Try modeline (first or last few lines)
            if let modelineLang = detectModeline(content) {
                return modelineLang
            }
        }

        return "unknown"
    }

    /// Detect language from NSString content (UTF-16 safe)
    public static func detect(
        fileURL: URL?,
        nsString: NSString?,
        manualOverride: String? = nil
    ) -> String {
        detect(
            fileURL: fileURL,
            content: nsString as String?,
            manualOverride: manualOverride
        )
    }

    // MARK: - Extension Mapping

    /// Map file extension to language ID
    /// Replicates SyntaxHighlighter.Language.from(extension:) logic
    public static func languageId(for ext: String) -> String {
        switch ext.lowercased() {
        case "swift": return "swift"
        case "py", "pyw", "pyi": return "python"
        case "js", "jsx", "mjs", "cjs": return "javascript"
        case "ts", "tsx", "mts", "cts": return "typescript"
        case "json", "jsonl", "json5": return "json"
        case "md", "markdown", "mdown", "mkd": return "markdown"
        case "sh", "bash", "zsh", "fish", "ksh", "csh", "tcsh": return "shell"
        case "yaml", "yml": return "yaml"
        case "css", "scss", "sass", "less": return "css"
        case "html", "htm", "xhtml": return "html"
        case "xml", "svg", "plist": return "xml"
        case "go": return "go"
        case "rs": return "rust"
        case "c", "h": return "c"
        case "cpp", "cc", "cxx", "hpp", "hxx", "hh": return "cpp"
        case "m": return "objc"
        case "mm": return "objcpp"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "rb", "rake", "gemspec": return "ruby"
        case "php", "phtml": return "php"
        case "sql": return "sql"
        case "r", "rmd": return "r"
        case "lua": return "lua"
        case "pl", "pm": return "perl"
        case "ex", "exs": return "elixir"
        case "erl", "hrl": return "erlang"
        case "hs", "lhs": return "haskell"
        case "scala", "sc": return "scala"
        case "clj", "cljs", "cljc", "edn": return "clojure"
        case "dockerfile": return "dockerfile"
        case "toml": return "toml"
        case "ini", "cfg", "conf": return "ini"
        case "makefile", "mk": return "makefile"
        case "cmake": return "cmake"
        case "tf", "tfvars": return "terraform"
        case "proto": return "protobuf"
        case "graphql", "gql": return "graphql"
        case "vue": return "vue"
        case "svelte": return "svelte"
        default: return "unknown"
        }
    }

    /// Get display name for a language ID
    public static func displayName(for languageId: String) -> String {
        switch languageId {
        case "swift": return "Swift"
        case "python": return "Python"
        case "javascript": return "JavaScript"
        case "typescript": return "TypeScript"
        case "json": return "JSON"
        case "markdown": return "Markdown"
        case "shell": return "Shell"
        case "yaml": return "YAML"
        case "css": return "CSS"
        case "html": return "HTML"
        case "xml": return "XML"
        case "go": return "Go"
        case "rust": return "Rust"
        case "c": return "C"
        case "cpp": return "C++"
        case "objc": return "Objective-C"
        case "objcpp": return "Objective-C++"
        case "java": return "Java"
        case "kotlin": return "Kotlin"
        case "ruby": return "Ruby"
        case "php": return "PHP"
        case "sql": return "SQL"
        case "r": return "R"
        case "lua": return "Lua"
        case "perl": return "Perl"
        case "elixir": return "Elixir"
        case "erlang": return "Erlang"
        case "haskell": return "Haskell"
        case "scala": return "Scala"
        case "clojure": return "Clojure"
        case "dockerfile": return "Dockerfile"
        case "toml": return "TOML"
        case "ini": return "INI"
        case "makefile": return "Makefile"
        case "cmake": return "CMake"
        case "terraform": return "Terraform"
        case "protobuf": return "Protocol Buffers"
        case "graphql": return "GraphQL"
        case "vue": return "Vue"
        case "svelte": return "Svelte"
        case "unknown": return "Plain Text"
        default: return languageId.capitalized
        }
    }

    // MARK: - Shebang Detection

    /// Detect language from shebang line (e.g., #!/usr/bin/env python3)
    private static func detectShebang(_ content: String) -> String? {
        // Get first line
        guard let firstNewline = content.firstIndex(of: "\n") else {
            // Single line content
            return parseShebang(String(content))
        }
        let firstLine = String(content[..<firstNewline])
        return parseShebang(firstLine)
    }

    private static func parseShebang(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#!") else { return nil }

        let shebang = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)

        // Handle /usr/bin/env <interpreter>
        if shebang.contains("env ") {
            let parts = shebang.split(separator: " ")
            if let envIndex = parts.firstIndex(where: { $0.hasSuffix("env") }),
               envIndex + 1 < parts.count {
                let interpreter = String(parts[envIndex + 1])
                return interpreterToLanguage(interpreter)
            }
        }

        // Handle direct path like /usr/bin/python3
        let pathComponents = shebang.split(separator: "/")
        if let last = pathComponents.last {
            // Handle interpreter with arguments (e.g., "python3 -u")
            let interpreter = String(last.split(separator: " ").first ?? last)
            return interpreterToLanguage(interpreter)
        }

        return nil
    }

    private static func interpreterToLanguage(_ interpreter: String) -> String? {
        let normalized = interpreter.lowercased()

        // Python variants
        if normalized.hasPrefix("python") || normalized == "pypy" || normalized == "pypy3" {
            return "python"
        }

        // Ruby variants
        if normalized.hasPrefix("ruby") || normalized == "jruby" {
            return "ruby"
        }

        // Node.js variants
        if normalized == "node" || normalized == "nodejs" || normalized.hasPrefix("node") {
            return "javascript"
        }

        // Shell variants
        if ["bash", "sh", "zsh", "fish", "ksh", "csh", "tcsh", "dash"].contains(normalized) {
            return "shell"
        }

        // Perl
        if normalized.hasPrefix("perl") {
            return "perl"
        }

        // PHP
        if normalized.hasPrefix("php") {
            return "php"
        }

        // Lua
        if normalized.hasPrefix("lua") {
            return "lua"
        }

        // Ruby
        if normalized.hasPrefix("ruby") {
            return "ruby"
        }

        // Elixir
        if normalized == "elixir" || normalized == "iex" {
            return "elixir"
        }

        // Awk
        if normalized == "awk" || normalized == "gawk" || normalized == "mawk" {
            return "awk"
        }

        return nil
    }

    // MARK: - Modeline Detection

    /// Detect language from vim/emacs modeline
    private static func detectModeline(_ content: String) -> String? {
        // Check first 5 lines and last 5 lines for modelines
        let lines = content.components(separatedBy: .newlines)
        let checkLines = Array(lines.prefix(5)) + Array(lines.suffix(5))

        for line in checkLines {
            if let lang = parseVimModeline(line) {
                return lang
            }
            if let lang = parseEmacsModeline(line) {
                return lang
            }
        }

        return nil
    }

    /// Parse vim modeline: // vim: ft=swift or /* vim: set filetype=python : */
    private static func parseVimModeline(_ line: String) -> String? {
        let lowered = line.lowercased()

        // Look for vim: or vi: marker
        guard lowered.contains("vim:") || lowered.contains("vi:") else {
            return nil
        }

        // Extract filetype/ft setting
        // Patterns: ft=swift, filetype=python, syntax=javascript
        let patterns = [
            "ft=([a-z0-9_+-]+)",
            "filetype=([a-z0-9_+-]+)",
            "syntax=([a-z0-9_+-]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: line) {
                return normalizeVimFiletype(String(line[range]))
            }
        }

        return nil
    }

    /// Normalize vim filetype to our language IDs
    private static func normalizeVimFiletype(_ filetype: String) -> String {
        switch filetype.lowercased() {
        case "javascript", "js": return "javascript"
        case "typescript", "ts": return "typescript"
        case "python", "py": return "python"
        case "swift": return "swift"
        case "ruby", "rb": return "ruby"
        case "rust", "rs": return "rust"
        case "go", "golang": return "go"
        case "sh", "bash", "zsh", "shell": return "shell"
        case "yaml", "yml": return "yaml"
        case "json": return "json"
        case "markdown", "md": return "markdown"
        case "html": return "html"
        case "css": return "css"
        case "c": return "c"
        case "cpp", "c++": return "cpp"
        case "objc": return "objc"
        case "java": return "java"
        case "kotlin", "kt": return "kotlin"
        case "php": return "php"
        case "sql": return "sql"
        case "lua": return "lua"
        case "perl": return "perl"
        case "elixir": return "elixir"
        case "erlang": return "erlang"
        case "haskell", "hs": return "haskell"
        case "scala": return "scala"
        case "clojure", "clj": return "clojure"
        case "dockerfile": return "dockerfile"
        case "toml": return "toml"
        case "xml": return "xml"
        case "make", "makefile": return "makefile"
        case "terraform", "tf": return "terraform"
        case "proto", "protobuf": return "protobuf"
        case "graphql": return "graphql"
        case "vue": return "vue"
        case "svelte": return "svelte"
        default: return filetype.lowercased()
        }
    }

    /// Parse emacs modeline: -*- mode: python -*- or -*- python -*-
    private static func parseEmacsModeline(_ line: String) -> String? {
        // Look for -*- ... -*- pattern
        guard let startRange = line.range(of: "-*-"),
              let endRange = line.range(of: "-*-", range: startRange.upperBound..<line.endIndex) else {
            return nil
        }

        let content = String(line[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)

        // Try "mode: python" format
        if let modeRange = content.range(of: "mode:", options: .caseInsensitive) {
            let afterMode = content[modeRange.upperBound...]
                .trimmingCharacters(in: .whitespaces)
            // Extract mode value (up to ; or end)
            let modeValue = afterMode.split(separator: ";").first ?? Substring(afterMode)
            return normalizeEmacsMode(String(modeValue).trimmingCharacters(in: .whitespaces))
        }

        // Try simple format: -*- python -*-
        if !content.contains(":") {
            return normalizeEmacsMode(content)
        }

        return nil
    }

    /// Normalize emacs mode to our language IDs
    private static func normalizeEmacsMode(_ mode: String) -> String {
        switch mode.lowercased() {
        case "python", "python-mode": return "python"
        case "javascript", "js", "js-mode", "js2-mode": return "javascript"
        case "typescript", "typescript-mode": return "typescript"
        case "swift", "swift-mode": return "swift"
        case "ruby", "ruby-mode": return "ruby"
        case "rust", "rust-mode", "rustic-mode": return "rust"
        case "go", "go-mode": return "go"
        case "shell-script", "sh-mode", "bash": return "shell"
        case "yaml", "yaml-mode": return "yaml"
        case "json", "json-mode": return "json"
        case "markdown", "markdown-mode", "gfm-mode": return "markdown"
        case "html", "html-mode", "mhtml-mode": return "html"
        case "css", "css-mode": return "css"
        case "c", "c-mode": return "c"
        case "c++", "c++-mode": return "cpp"
        case "objc", "objc-mode": return "objc"
        case "java", "java-mode": return "java"
        case "kotlin", "kotlin-mode": return "kotlin"
        case "php", "php-mode": return "php"
        case "sql", "sql-mode": return "sql"
        case "lua", "lua-mode": return "lua"
        case "perl", "perl-mode", "cperl-mode": return "perl"
        case "elixir", "elixir-mode": return "elixir"
        case "erlang", "erlang-mode": return "erlang"
        case "haskell", "haskell-mode": return "haskell"
        case "scala", "scala-mode": return "scala"
        case "clojure", "clojure-mode": return "clojure"
        case "dockerfile", "dockerfile-mode": return "dockerfile"
        case "toml", "toml-mode": return "toml"
        case "nxml", "xml-mode": return "xml"
        case "makefile", "makefile-mode": return "makefile"
        case "terraform", "terraform-mode": return "terraform"
        case "protobuf", "protobuf-mode": return "protobuf"
        case "graphql", "graphql-mode": return "graphql"
        case "vue", "vue-mode": return "vue"
        case "svelte", "svelte-mode": return "svelte"
        default: return mode.lowercased()
        }
    }
}
