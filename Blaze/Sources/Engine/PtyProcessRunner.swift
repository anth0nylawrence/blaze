import Foundation
import Darwin

// MARK: - PTY Process Runner

/// Spawns a process with a pseudo-terminal to avoid stdout buffering issues.
///
/// When Claude CLI's stdin is connected to a pipe (not TTY), the CLI waits for stdin
/// input before producing any stdout output. Using `forkpty()` gives the CLI a TTY,
/// allowing bidirectional streaming without deadlock.
///
/// ## Usage
/// ```swift
/// let runner = PtyProcessRunner()
/// try runner.spawn(executable: "/usr/local/bin/claude", arguments: [...])
/// let lines = runner.readLines()  // NDJSON lines
/// try runner.write(envelope)      // Send tool_result
/// runner.terminate()
/// ```
///
/// ## Key Differences from ProcessRunner
/// - Uses `forkpty()` instead of `Pipe` for stdin/stdout
/// - Single merged stream (stdout+stderr combined via PTY)
/// - Non-blocking reads with line buffering
/// - Direct write to PTY master FD
public final class PtyProcessRunner: @unchecked Sendable {
    private var masterFD: Int32 = -1
    private var pid: pid_t = 0
    private var buffer = Data()
    private let lock = NSLock()

    public init() {}

    /// Spawn a process with a pseudo-terminal
    /// - Parameters:
    ///   - executable: Path to the executable
    ///   - arguments: Command-line arguments
    ///   - workingDirectory: Optional working directory
    ///   - environment: Optional environment variables (merged with current)
    public func spawn(
        executable: String,
        arguments: [String],
        workingDirectory: String?,
        environment: [String: String]? = nil
    ) throws {
        // Prepare argv (C strings)
        var argv = [executable] + arguments
        let cArgv = argv.map { strdup($0) } + [nil]
        defer { cArgv.compactMap { $0 }.forEach { free($0) } }

        // Prepare environment if specified
        var cEnvp: [UnsafeMutablePointer<CChar>?]?
        if let env = environment {
            var mergedEnv = ProcessInfo.processInfo.environment
            for (key, value) in env {
                mergedEnv[key] = value
            }
            cEnvp = mergedEnv.map { strdup("\($0.key)=\($0.value)") } + [nil]
        }
        defer { cEnvp?.compactMap { $0 }.forEach { free($0) } }

        // Fork with PTY
        var ws = winsize(ws_row: 40, ws_col: 120, ws_xpixel: 0, ws_ypixel: 0)

        pid = forkpty(&masterFD, nil, nil, &ws)

        if pid == -1 {
            throw PtyProcessError.forkFailed(errno: errno, message: String(cString: strerror(errno)))
        }

        if pid == 0 {
            // Child process

            // Change working directory if specified
            if let wd = workingDirectory {
                if chdir(wd) != 0 {
                    _exit(126) // Cannot change directory
                }
            }

            // Disable echo to avoid seeing our input
            var tio = termios()
            if tcgetattr(STDIN_FILENO, &tio) == 0 {
                tio.c_lflag &= ~UInt(ECHO)
                tcsetattr(STDIN_FILENO, TCSANOW, &tio)
            }

            // Execute
            if let envp = cEnvp {
                execve(executable, cArgv, envp)
            } else {
                execvp(executable, cArgv)
            }

            // If we get here, exec failed
            _exit(127)
        }

        // Parent process - set non-blocking for reads
        let flags = fcntl(masterFD, F_GETFL)
        fcntl(masterFD, F_SETFL, flags | O_NONBLOCK)
    }

    /// Read available data (non-blocking)
    /// - Returns: Raw data available on the PTY
    public func readAvailable() -> Data {
        lock.lock()
        defer { lock.unlock() }

        guard masterFD >= 0 else { return Data() }

        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)

        while true {
            let n = read(masterFD, &chunk, chunk.count)
            if n > 0 {
                data.append(contentsOf: chunk[0..<n])
            } else {
                break
            }
        }

        return data
    }

    /// Read complete lines from the PTY output
    ///
    /// Accumulates data internally and returns only complete lines (newline-terminated).
    /// This is ideal for NDJSON parsing where each line is a complete JSON object.
    ///
    /// - Returns: Array of complete lines (without newline characters)
    public func readLines() -> [String] {
        lock.lock()
        defer { lock.unlock() }

        buffer.append(readAvailableUnlocked())

        var lines: [String] = []
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer[..<newlineIndex]
            buffer = Data(buffer[(newlineIndex + 1)...])

            // Handle \r\n (PTY may use CRLF)
            var cleanData = lineData
            if cleanData.last == UInt8(ascii: "\r") {
                cleanData = cleanData.dropLast()
            }

            if let line = String(data: cleanData, encoding: .utf8)?.trimmingCharacters(in: .whitespaces),
               !line.isEmpty {
                lines.append(line)
            }
        }

        return lines
    }

    /// Read available data without locking (internal use)
    private func readAvailableUnlocked() -> Data {
        guard masterFD >= 0 else { return Data() }

        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)

        while true {
            let n = read(masterFD, &chunk, chunk.count)
            if n > 0 {
                data.append(contentsOf: chunk[0..<n])
            } else {
                break
            }
        }

        return data
    }

    /// Write data to the process stdin (via PTY master)
    /// - Parameter data: Data to write
    /// - Throws: `PtyProcessError.writeFailed` if write fails
    public func write(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }

        guard masterFD >= 0 else {
            throw PtyProcessError.notRunning
        }

        var remaining = data
        while !remaining.isEmpty {
            let n = remaining.withUnsafeBytes { ptr in
                Darwin.write(masterFD, ptr.baseAddress, remaining.count)
            }

            if n <= 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    // Non-blocking - retry after short delay
                    usleep(1000) // 1ms
                    continue
                }

                // Check for EPIPE (process closed stdin)
                if errno == EPIPE || errno == EIO {
                    throw PtyProcessError.epipe
                }

                throw PtyProcessError.writeFailed(errno: errno, message: String(cString: strerror(errno)))
            }

            remaining = Data(remaining[n...])
        }
    }

    /// Check if the process is still running
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }

        guard pid > 0 else {
            print("[PTY] isRunning: false (pid <= 0)")
            return false
        }

        var status: Int32 = 0
        let result = waitpid(pid, &status, WNOHANG)

        if result != 0 {
            // Process has exited - log details
            let exitedNormally = (status & 0x7f) == 0
            let exitCode = exitedNormally ? (status >> 8) & 0xff : -1
            print("[PTY] isRunning: false - waitpid=\(result), status=\(status), exitCode=\(exitCode)")
        }

        return result == 0
    }

    /// Get the exit status if process has terminated
    /// - Returns: Exit status or nil if still running
    public var exitStatus: Int32? {
        lock.lock()
        defer { lock.unlock() }

        guard pid > 0 else { return nil }

        var status: Int32 = 0
        let result = waitpid(pid, &status, WNOHANG)

        if result > 0 {
            // WIFEXITED and WEXITSTATUS are C macros, reimplemented here
            let exitedNormally = (status & 0x7f) == 0
            if exitedNormally {
                let exitCode = (status >> 8) & 0xff
                return exitCode
            }
            return -1 // Terminated abnormally
        }

        return nil // Still running
    }

    /// Terminate the process with timeout to prevent blocking
    public func terminate() {
        lock.lock()
        defer { lock.unlock() }

        if pid > 0 {
            // Close the PTY master first to signal EOF to the child
            // This helps Claude CLI exit cleanly when in stream-json mode
            if masterFD >= 0 {
                close(masterFD)
                masterFD = -1
            }

            // First try SIGTERM for graceful shutdown
            kill(pid, SIGTERM)

            // Wait up to 500ms for graceful exit (non-blocking checks)
            var status: Int32 = 0
            for _ in 0..<50 {
                if waitpid(pid, &status, WNOHANG) != 0 {
                    // Process exited or error (already reaped)
                    pid = 0
                    return
                }
                usleep(10_000) // 10ms
            }

            // Still running after SIGTERM - force kill
            kill(pid, SIGKILL)

            // Wait up to 500ms for forced exit (non-blocking checks)
            for _ in 0..<50 {
                if waitpid(pid, &status, WNOHANG) != 0 {
                    pid = 0
                    return
                }
                usleep(10_000) // 10ms
            }

            // If still not dead after SIGKILL + 500ms, give up (shouldn't happen)
            // Don't block indefinitely - just mark as cleaned up
            pid = 0
        }

        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }
    }

    deinit {
        terminate()
    }
}

// MARK: - Errors

/// Errors from PTY process operations
public enum PtyProcessError: Error, LocalizedError {
    case forkFailed(errno: Int32, message: String)
    case notRunning
    case writeFailed(errno: Int32, message: String)
    case epipe  // Process closed stdin - fail fast, no retry

    public var errorDescription: String? {
        switch self {
        case .forkFailed(let errno, let message):
            return "forkpty failed (errno \(errno)): \(message)"
        case .notRunning:
            return "Process is not running"
        case .writeFailed(let errno, let message):
            return "Write failed (errno \(errno)): \(message)"
        case .epipe:
            return "Process closed stdin (EPIPE)"
        }
    }
}
