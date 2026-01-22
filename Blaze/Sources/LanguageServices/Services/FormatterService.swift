import Foundation

/// Actor-based formatting service for code documents.
///
/// Formatting strategy (in order):
/// 1. If LSP server with `textDocument/formatting` is available → use LSP
/// 2. Else if external formatter is configured → run process
/// 3. Else → return `.unsupported` with user message
///
/// Thread Safety:
/// - Actor-isolated for safe concurrent access
/// - All process spawning happens off main thread
/// - Results are returned to caller for main-thread application
public actor FormatterService {
    // MARK: - Types

    /// Result of a formatting operation
    public enum FormatResult: Sendable {
        /// Successfully formatted with new text
        case formatted(text: String)

        /// No changes needed (content already formatted)
        case noChange

        /// No formatter available for this language
        case unsupported(message: String)

        /// Formatter failed with error
        case error(message: String)
    }

    /// Configuration for a language's formatter
    public struct FormatterConfig: Sendable {
        /// The executable path or name (e.g., "swift-format", "/usr/local/bin/swiftformat")
        public let command: String

        /// Arguments to pass before the file content
        /// Use "{file}" as placeholder for temp file path, or omit for stdin
        public let arguments: [String]

        /// Whether to use stdin/stdout (true) or temp file (false)
        public let usesStdin: Bool

        /// Timeout in seconds for formatter process
        public let timeout: TimeInterval

        public init(
            command: String,
            arguments: [String] = [],
            usesStdin: Bool = true,
            timeout: TimeInterval = 30
        ) {
            self.command = command
            self.arguments = arguments
            self.usesStdin = usesStdin
            self.timeout = timeout
        }
    }

    // MARK: - Properties

    /// Shared singleton instance
    public static let shared = FormatterService()

    /// Per-language formatter configurations
    private var formatters: [String: FormatterConfig] = FormatterService.defaultFormatters

    /// Cache of which formatters are actually available on the system
    private var formatterAvailability: [String: Bool] = [:]

    /// Default formatter configurations for common languages
    private static let defaultFormatters: [String: FormatterConfig] = [
        // Swift: swift-format (Apple's official) or swiftformat (nicklockwood's)
        "swift": FormatterConfig(
            command: "swift-format",
            arguments: ["format"],
            usesStdin: true,
            timeout: 30
        ),
        // Python: black
        "python": FormatterConfig(
            command: "black",
            arguments: ["-", "--quiet"],
            usesStdin: true,
            timeout: 30
        ),
        // JavaScript: prettier
        "javascript": FormatterConfig(
            command: "prettier",
            arguments: ["--stdin-filepath", "file.js"],
            usesStdin: true,
            timeout: 30
        ),
        // TypeScript: prettier
        "typescript": FormatterConfig(
            command: "prettier",
            arguments: ["--stdin-filepath", "file.ts"],
            usesStdin: true,
            timeout: 30
        ),
        // JSON: prettier
        "json": FormatterConfig(
            command: "prettier",
            arguments: ["--stdin-filepath", "file.json"],
            usesStdin: true,
            timeout: 30
        ),
        // Rust: rustfmt
        "rust": FormatterConfig(
            command: "rustfmt",
            arguments: [],
            usesStdin: true,
            timeout: 30
        ),
        // Go: gofmt
        "go": FormatterConfig(
            command: "gofmt",
            arguments: [],
            usesStdin: true,
            timeout: 30
        ),
        // C: clang-format
        "c": FormatterConfig(
            command: "clang-format",
            arguments: [],
            usesStdin: true,
            timeout: 30
        ),
        // C++: clang-format
        "cpp": FormatterConfig(
            command: "clang-format",
            arguments: [],
            usesStdin: true,
            timeout: 30
        )
    ]

    // MARK: - Initialization

    public init() {}

    // MARK: - Configuration

    /// Register a formatter for a language
    public func registerFormatter(_ config: FormatterConfig, forLanguage languageId: String) {
        formatters[languageId] = config
        formatterAvailability.removeValue(forKey: config.command) // Reset availability check
    }

    // MARK: - Formatting

    /// Format the given text for the specified language
    /// - Parameters:
    ///   - text: The source code to format
    ///   - fileURL: Optional file URL (for extension-based language detection)
    ///   - languageId: The language identifier (e.g., "swift", "python")
    /// - Returns: The formatting result
    public func format(text: String, fileURL: URL?, languageId: String) async -> FormatResult {
        // Look up formatter config
        guard let config = formatters[languageId] else {
            return .unsupported(message: "No formatter configured for \(languageId)")
        }

        // Check if formatter is available
        let isAvailable = await checkFormatterAvailable(config.command)
        guard isAvailable else {
            return .unsupported(message: "\(config.command) not found. Install it to enable formatting.")
        }

        // Run the formatter
        do {
            let formattedText = try await runFormatter(config: config, text: text, fileURL: fileURL)

            // Check if anything changed
            if formattedText == text {
                return .noChange
            }

            return .formatted(text: formattedText)
        } catch {
            return .error(message: error.localizedDescription)
        }
    }

    // MARK: - Formatter Execution

    /// Check if a formatter command is available on the system
    private func checkFormatterAvailable(_ command: String) async -> Bool {
        // Check cache first
        if let cached = formatterAvailability[command] {
            return cached
        }

        // Run `which` to check availability
        let result = await runProcess(
            executable: "/usr/bin/which",
            arguments: [command],
            input: nil,
            timeout: 5
        )

        let available = result.exitCode == 0
        formatterAvailability[command] = available
        return available
    }

    /// Run the formatter process
    private func runFormatter(config: FormatterConfig, text: String, fileURL: URL?) async throws -> String {
        if config.usesStdin {
            return try await runStdinFormatter(config: config, text: text)
        } else {
            return try await runFileFormatter(config: config, text: text, originalURL: fileURL)
        }
    }

    /// Run formatter using stdin/stdout
    private func runStdinFormatter(config: FormatterConfig, text: String) async throws -> String {
        let result = await runProcess(
            executable: config.command,
            arguments: config.arguments,
            input: text.data(using: .utf8),
            timeout: config.timeout
        )

        if result.exitCode != 0 {
            let stderr = String(data: result.stderr, encoding: .utf8) ?? "Unknown error"
            throw FormatterError.processError(exitCode: result.exitCode, message: stderr)
        }

        guard let output = String(data: result.stdout, encoding: .utf8) else {
            throw FormatterError.invalidOutput
        }

        return output
    }

    /// Run formatter using temp file
    private func runFileFormatter(config: FormatterConfig, text: String, originalURL: URL?) async throws -> String {
        // Create temp file with appropriate extension
        let ext = originalURL?.pathExtension ?? "txt"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Write content to temp file
        try text.write(to: tempURL, atomically: true, encoding: .utf8)

        // Build arguments, replacing {file} placeholder
        let args = config.arguments.map { arg -> String in
            if arg == "{file}" {
                return tempURL.path
            }
            return arg
        } + (config.arguments.contains("{file}") ? [] : [tempURL.path])

        // Run formatter
        let result = await runProcess(
            executable: config.command,
            arguments: args,
            input: nil,
            timeout: config.timeout
        )

        if result.exitCode != 0 {
            let stderr = String(data: result.stderr, encoding: .utf8) ?? "Unknown error"
            throw FormatterError.processError(exitCode: result.exitCode, message: stderr)
        }

        // Read back the formatted file
        return try String(contentsOf: tempURL, encoding: .utf8)
    }

    // MARK: - Process Execution

    /// Process execution result
    private struct ProcessResult {
        let exitCode: Int32
        let stdout: Data
        let stderr: Data
    }

    /// Run a process with optional stdin and timeout
    private func runProcess(
        executable: String,
        arguments: [String],
        input: Data?,
        timeout: TimeInterval
    ) async -> ProcessResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            // Find executable path
            if executable.hasPrefix("/") {
                process.executableURL = URL(fileURLWithPath: executable)
            } else {
                // Search in PATH
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [executable] + arguments
            }

            if !executable.hasPrefix("/") {
                // Already set above with /usr/bin/env
            } else {
                process.arguments = arguments
            }

            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Handle stdin if provided
            if let input = input {
                let stdinPipe = Pipe()
                process.standardInput = stdinPipe

                // Write input in background
                DispatchQueue.global().async {
                    stdinPipe.fileHandleForWriting.write(input)
                    stdinPipe.fileHandleForWriting.closeFile()
                }
            }

            // Setup timeout
            let timeoutItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            do {
                try process.run()
                process.waitUntilExit()
                timeoutItem.cancel()

                let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                continuation.resume(returning: ProcessResult(
                    exitCode: process.terminationStatus,
                    stdout: stdout,
                    stderr: stderr
                ))
            } catch {
                timeoutItem.cancel()
                continuation.resume(returning: ProcessResult(
                    exitCode: -1,
                    stdout: Data(),
                    stderr: error.localizedDescription.data(using: .utf8) ?? Data()
                ))
            }
        }
    }

    // MARK: - Errors

    public enum FormatterError: Error, LocalizedError {
        case processError(exitCode: Int32, message: String)
        case invalidOutput
        case timeout

        public var errorDescription: String? {
            switch self {
            case .processError(let code, let message):
                return "Formatter failed (exit \(code)): \(message)"
            case .invalidOutput:
                return "Formatter produced invalid UTF-8 output"
            case .timeout:
                return "Formatter timed out"
            }
        }
    }
}
