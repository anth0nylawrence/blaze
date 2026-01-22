import Foundation

/// Centralized configuration for Language Services.
///
/// Maps language IDs to:
/// - Formatter commands
/// - Linter commands (future)
/// - LSP server configurations (future)
///
/// Configuration sources (in priority order):
/// 1. Project-local `.blaze/language-services.json`
/// 2. User-level `~/.blaze/language-services.json`
/// 3. Built-in defaults
public struct LanguageServicesConfig: Codable, Sendable {
    // MARK: - Types

    /// Configuration for a language
    public struct LanguageConfig: Codable, Sendable {
        /// Formatter configuration
        public var formatter: FormatterConfig?

        /// Linter configuration (future)
        public var linter: LinterConfig?

        /// LSP server configuration (future)
        public var lsp: LSPConfig?

        public init(
            formatter: FormatterConfig? = nil,
            linter: LinterConfig? = nil,
            lsp: LSPConfig? = nil
        ) {
            self.formatter = formatter
            self.linter = linter
            self.lsp = lsp
        }
    }

    /// Formatter configuration
    public struct FormatterConfig: Codable, Sendable {
        /// Command to run (path or name in PATH)
        public let command: String

        /// Arguments (use "{file}" for temp file path)
        public let arguments: [String]

        /// Use stdin/stdout (true) or temp file (false)
        public let usesStdin: Bool

        /// Enable format on save
        public var formatOnSave: Bool

        public init(
            command: String,
            arguments: [String] = [],
            usesStdin: Bool = true,
            formatOnSave: Bool = false
        ) {
            self.command = command
            self.arguments = arguments
            self.usesStdin = usesStdin
            self.formatOnSave = formatOnSave
        }
    }

    /// Linter configuration (future)
    public struct LinterConfig: Codable, Sendable {
        public let command: String
        public let arguments: [String]

        public init(command: String, arguments: [String] = []) {
            self.command = command
            self.arguments = arguments
        }
    }

    /// LSP server configuration (future)
    public struct LSPConfig: Codable, Sendable {
        public let command: String
        public let arguments: [String]

        public init(command: String, arguments: [String] = []) {
            self.command = command
            self.arguments = arguments
        }
    }

    // MARK: - Properties

    /// Per-language configurations
    public var languages: [String: LanguageConfig]

    /// Global settings
    public var globalSettings: GlobalSettings

    /// Global settings that apply across languages
    public struct GlobalSettings: Codable, Sendable {
        /// Enable syntax highlighting
        public var enableHighlighting: Bool

        /// Enable diagnostics
        public var enableDiagnostics: Bool

        /// Enable format on save for all languages
        public var formatOnSave: Bool

        /// Highlight debounce in milliseconds
        public var highlightDebounceMs: Int

        /// Diagnostics debounce in milliseconds
        public var diagnosticsDebounceMs: Int

        public init(
            enableHighlighting: Bool = true,
            enableDiagnostics: Bool = true,
            formatOnSave: Bool = false,
            highlightDebounceMs: Int = 150,
            diagnosticsDebounceMs: Int = 500
        ) {
            self.enableHighlighting = enableHighlighting
            self.enableDiagnostics = enableDiagnostics
            self.formatOnSave = formatOnSave
            self.highlightDebounceMs = highlightDebounceMs
            self.diagnosticsDebounceMs = diagnosticsDebounceMs
        }
    }

    // MARK: - Initialization

    public init(
        languages: [String: LanguageConfig] = [:],
        globalSettings: GlobalSettings = GlobalSettings()
    ) {
        self.languages = languages
        self.globalSettings = globalSettings
    }

    // MARK: - Default Configuration

    /// Built-in default configuration
    public static let defaults: LanguageServicesConfig = {
        var config = LanguageServicesConfig()

        // Swift
        config.languages["swift"] = LanguageConfig(
            formatter: FormatterConfig(
                command: "swift-format",
                arguments: ["format"],
                usesStdin: true
            ),
            linter: LinterConfig(command: "swiftlint"),
            lsp: LSPConfig(command: "sourcekit-lsp")
        )

        // Python
        config.languages["python"] = LanguageConfig(
            formatter: FormatterConfig(
                command: "black",
                arguments: ["-", "--quiet"],
                usesStdin: true
            ),
            linter: LinterConfig(command: "ruff", arguments: ["check", "--stdin-filename", "{file}"]),
            lsp: LSPConfig(command: "pyright-langserver", arguments: ["--stdio"])
        )

        // JavaScript
        config.languages["javascript"] = LanguageConfig(
            formatter: FormatterConfig(
                command: "prettier",
                arguments: ["--stdin-filepath", "{file}"],
                usesStdin: true
            ),
            linter: LinterConfig(command: "eslint", arguments: ["--stdin", "--stdin-filename", "{file}"]),
            lsp: LSPConfig(command: "typescript-language-server", arguments: ["--stdio"])
        )

        // TypeScript
        config.languages["typescript"] = LanguageConfig(
            formatter: FormatterConfig(
                command: "prettier",
                arguments: ["--stdin-filepath", "{file}"],
                usesStdin: true
            ),
            linter: LinterConfig(command: "eslint", arguments: ["--stdin", "--stdin-filename", "{file}"]),
            lsp: LSPConfig(command: "typescript-language-server", arguments: ["--stdio"])
        )

        // Rust
        config.languages["rust"] = LanguageConfig(
            formatter: FormatterConfig(command: "rustfmt", usesStdin: true),
            linter: LinterConfig(command: "clippy-driver"),
            lsp: LSPConfig(command: "rust-analyzer")
        )

        // Go
        config.languages["go"] = LanguageConfig(
            formatter: FormatterConfig(command: "gofmt", usesStdin: true),
            lsp: LSPConfig(command: "gopls")
        )

        // JSON
        config.languages["json"] = LanguageConfig(
            formatter: FormatterConfig(
                command: "prettier",
                arguments: ["--stdin-filepath", "file.json"],
                usesStdin: true
            )
        )

        // YAML
        config.languages["yaml"] = LanguageConfig(
            formatter: FormatterConfig(
                command: "prettier",
                arguments: ["--stdin-filepath", "file.yaml"],
                usesStdin: true
            )
        )

        // Markdown
        config.languages["markdown"] = LanguageConfig(
            formatter: FormatterConfig(
                command: "prettier",
                arguments: ["--stdin-filepath", "file.md"],
                usesStdin: true
            )
        )

        // C/C++
        config.languages["c"] = LanguageConfig(
            formatter: FormatterConfig(command: "clang-format", usesStdin: true),
            lsp: LSPConfig(command: "clangd")
        )
        config.languages["cpp"] = LanguageConfig(
            formatter: FormatterConfig(command: "clang-format", usesStdin: true),
            lsp: LSPConfig(command: "clangd")
        )

        return config
    }()

    // MARK: - Loading

    /// Load configuration from files, merging with defaults
    public static func load(projectDirectory: URL?) async -> LanguageServicesConfig {
        var config = defaults

        // Try user-level config
        let userConfigURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".blaze")
            .appendingPathComponent("language-services.json")

        if let userConfig = try? await loadFromFile(userConfigURL) {
            config = config.merging(with: userConfig)
        }

        // Try project-level config (overrides user-level)
        if let projectDir = projectDirectory {
            let projectConfigURL = projectDir
                .appendingPathComponent(".blaze")
                .appendingPathComponent("language-services.json")

            if let projectConfig = try? await loadFromFile(projectConfigURL) {
                config = config.merging(with: projectConfig)
            }
        }

        return config
    }

    /// Load configuration from a JSON file
    private static func loadFromFile(_ url: URL) async throws -> LanguageServicesConfig {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(LanguageServicesConfig.self, from: data)
    }

    /// Merge this configuration with another (other takes precedence)
    public func merging(with other: LanguageServicesConfig) -> LanguageServicesConfig {
        var merged = self

        // Merge languages
        for (languageId, otherConfig) in other.languages {
            if var existing = merged.languages[languageId] {
                // Merge individual settings
                if let formatter = otherConfig.formatter {
                    existing.formatter = formatter
                }
                if let linter = otherConfig.linter {
                    existing.linter = linter
                }
                if let lsp = otherConfig.lsp {
                    existing.lsp = lsp
                }
                merged.languages[languageId] = existing
            } else {
                merged.languages[languageId] = otherConfig
            }
        }

        // Override global settings from other
        merged.globalSettings = other.globalSettings

        return merged
    }

    // MARK: - Saving

    /// Save configuration to a file
    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
}
