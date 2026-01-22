import Foundation

/// Non-blocking trace recorder for capturing raw NDJSON events.
///
/// Uses `AsyncStream` buffering to ensure `record*()` calls never block
/// the hot path. A background task drains entries to disk files.
///
/// Trace files are written to:
///   - `<traceDir>/claude.stdout.jsonl` - stdout from CLI
///   - `<traceDir>/claude.stderr.jsonl` - stderr from CLI
///   - `<traceDir>/claude.stdin.jsonl` - stdin we send to CLI
///
/// Example:
/// ```swift
/// let recorder = RawTraceRecorder(traceDir: traceURL)
/// recorder.recordStdout(data)  // non-blocking
/// await recorder.finalize()    // waits for all writes
/// ```
public actor RawTraceRecorder {
    public let traceDir: URL

    private var continuation: AsyncStream<TraceEntry>.Continuation?
    private var writerTask: Task<Void, Never>?
    private var fileHandles: [Source: FileHandle] = [:]

    /// Source of trace data
    public enum Source: String, Sendable {
        case stdout
        case stdin
        case stderr
    }

    /// A single trace entry to be written
    public struct TraceEntry: Sendable {
        public let source: Source
        public let data: Data
        public let timestamp: Date

        public init(source: Source, data: Data, timestamp: Date = Date()) {
            self.source = source
            self.data = data
            self.timestamp = timestamp
        }
    }

    /// Initialize the recorder.
    /// - Parameter traceDir: Directory to write trace files
    public init(traceDir: URL) {
        self.traceDir = traceDir

        // Create the AsyncStream for buffering
        let (stream, continuation) = AsyncStream.makeStream(
            of: TraceEntry.self,
            bufferingPolicy: .unbounded
        )
        self.continuation = continuation

        // Start background writer task
        self.writerTask = Task { [weak self, traceDir] in
            for await entry in stream {
                await self?.writeEntry(entry, traceDir: traceDir)
            }
        }
    }

    /// Record stdout data (non-blocking).
    public nonisolated func recordStdout(_ data: Data) {
        Task { await enqueue(TraceEntry(source: .stdout, data: data)) }
    }

    /// Record stderr data (non-blocking).
    public nonisolated func recordStderr(_ data: Data) {
        Task { await enqueue(TraceEntry(source: .stderr, data: data)) }
    }

    /// Record stdin data (non-blocking).
    public nonisolated func recordStdin(_ data: Data) {
        Task { await enqueue(TraceEntry(source: .stdin, data: data)) }
    }

    /// Record an entry with explicit source.
    public nonisolated func record(_ entry: TraceEntry) {
        Task { await enqueue(entry) }
    }

    /// Finalize the recorder - closes the stream and waits for all writes.
    public func finalize() async {
        continuation?.finish()
        await writerTask?.value

        // Close all file handles
        for handle in fileHandles.values {
            try? handle.close()
        }
        fileHandles.removeAll()
    }

    // MARK: - Private

    private func enqueue(_ entry: TraceEntry) {
        continuation?.yield(entry)
    }

    private func writeEntry(_ entry: TraceEntry, traceDir: URL) {
        let filename: String
        switch entry.source {
        case .stdout: filename = "claude.stdout.jsonl"
        case .stdin: filename = "claude.stdin.jsonl"
        case .stderr: filename = "claude.stderr.jsonl"
        }

        let fileURL = traceDir.appendingPathComponent(filename)

        // Get or create file handle
        let handle: FileHandle
        if let existing = fileHandles[entry.source] {
            handle = existing
        } else {
            // Ensure trace directory exists
            try? FileManager.default.createDirectory(
                at: traceDir,
                withIntermediateDirectories: true
            )

            // Create file if needed
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }

            guard let newHandle = try? FileHandle(forWritingTo: fileURL) else {
                return  // Silently fail - don't block hot path
            }

            // Seek to end for append
            try? newHandle.seekToEnd()
            fileHandles[entry.source] = newHandle
            handle = newHandle
        }

        // Write data (already includes newlines from NDJSON)
        do {
            try handle.write(contentsOf: entry.data)
        } catch {
            // Silently fail - trace is optional, don't crash hot path
        }
    }
}

// MARK: - Convenience Methods

extension RawTraceRecorder {
    /// Create a trace directory with timestamp in the given base directory.
    /// - Parameter baseDir: Base directory (e.g., `.blaze-traces/`)
    /// - Returns: URL to the timestamped trace directory
    public static func createTimestampedTraceDir(in baseDir: URL) throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime, .withDashSeparatorInDate]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let traceDir = baseDir.appendingPathComponent(timestamp)
        try FileManager.default.createDirectory(
            at: traceDir,
            withIntermediateDirectories: true
        )
        return traceDir
    }

    /// Write metadata JSON to the trace directory.
    /// - Parameter metadata: Dictionary to encode as JSON
    public func writeMetadata(_ metadata: [String: Any]) async throws {
        let metaURL = traceDir.appendingPathComponent("meta.json")
        let data = try JSONSerialization.data(
            withJSONObject: metadata,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: metaURL)
    }
}
