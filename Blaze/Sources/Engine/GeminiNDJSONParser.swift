import Foundation

// MARK: - Gemini NDJSON Parser

/// Parses newline-delimited JSON from Gemini CLI output.
/// Similar to NDJSONParser but decodes GeminiStreamEvent instead of ClaudeStreamEvent.
///
/// **Key Differences from NDJSONParser:**
/// - Decodes to `GeminiStreamEvent` (not `ClaudeStreamEvent`)
/// - Uses `convertFromSnakeCase` for Gemini's JSON format
/// - Handles Gemini-specific parsing quirks
actor GeminiNDJSONParser {
    private var buffer = Data()
    private let decoder: JSONDecoder

    /// Tracks total lines parsed for error reporting
    private var lineCount: Int = 0

    /// Parse errors encountered during this session
    private(set) var parseErrors: [String] = []

    /// Maximum errors to retain in memory
    private let maxErrorsRetained = 50

    init() {
        decoder = JSONDecoder()
        // Gemini CLI uses snake_case JSON keys
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    /// Parse a chunk of data, returning any complete events found.
    /// Buffers partial lines until a newline is received.
    func parse(chunk: Data) -> [GeminiStreamEvent] {
        buffer.append(chunk)
        var events: [GeminiStreamEvent] = []

        // Process complete lines (terminated by newline)
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer[..<newlineIndex]
            buffer = Data(buffer[(newlineIndex + 1)...])
            lineCount += 1

            // Skip empty lines
            guard !lineData.isEmpty else { continue }

            // Handle concatenated JSON objects (like NDJSONParser does)
            let jsonChunks = splitConcatenatedJSON(Data(lineData))
            for jsonData in jsonChunks {
                if let event = parseEvent(from: jsonData) {
                    events.append(event)
                }
            }
        }

        return events
    }

    /// Split concatenated JSON objects (e.g., `{...}{...}`) into individual objects.
    /// Gemini CLI may write multiple events without newlines between them.
    private func splitConcatenatedJSON(_ data: Data) -> [Data] {
        guard let string = String(data: data, encoding: .utf8) else {
            return [data]
        }

        var results: [Data] = []
        var depth = 0
        var inString = false
        var escape = false
        var objectStart = string.startIndex

        for i in string.indices {
            let char = string[i]

            if escape {
                escape = false
                continue
            }

            if char == "\\" && inString {
                escape = true
                continue
            }

            if char == "\"" {
                inString = !inString
                continue
            }

            if inString {
                continue
            }

            if char == "{" {
                if depth == 0 {
                    objectStart = i
                }
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    let endIndex = string.index(after: i)
                    let objectString = String(string[objectStart..<endIndex])
                    if let objectData = objectString.data(using: .utf8) {
                        results.append(objectData)
                    }
                }
            }
        }

        return results.isEmpty ? [data] : results
    }

    /// Flush any remaining buffered data as a final event.
    func flush() -> GeminiStreamEvent? {
        guard !buffer.isEmpty else { return nil }

        let remaining = buffer
        buffer = Data()
        lineCount += 1

        return parseEvent(from: remaining)
    }

    /// Reset the parser state.
    func reset() {
        buffer = Data()
        lineCount = 0
        parseErrors.removeAll()
    }

    /// Get the current buffer size (for monitoring/debugging)
    var bufferSize: Int {
        buffer.count
    }

    /// Check if there's pending buffered data
    var hasPendingData: Bool {
        !buffer.isEmpty
    }

    private func parseEvent(from data: Data) -> GeminiStreamEvent? {
        do {
            return try decoder.decode(GeminiStreamEvent.self, from: data)
        } catch {
            // Log parse error
            let rawString = String(data: data, encoding: .utf8) ?? "<binary data>"
            let errorMsg = "[GeminiNDJSONParser] Parse error at line \(lineCount): \(error.localizedDescription)"

            // Store error for debugging (bounded)
            if parseErrors.count < maxErrorsRetained {
                parseErrors.append(errorMsg)
            }

            print(errorMsg)
            print("[GeminiNDJSONParser] Raw: \(rawString.prefix(200))")

            // Return unknown event to preserve emission order
            return .unknown(GeminiRawEvent(type: "parse_error", timestamp: Date()))
        }
    }
}
