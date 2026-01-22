import Foundation

// MARK: - CLI Detection Result

/// Result of detecting a CLI tool installation
public struct CLIDetectionResult: Codable, Sendable, Equatable, Identifiable {
    public var id: String { cliName }

    /// Name of the CLI tool (e.g., "claude", "gemini", "codex")
    public let cliName: String

    /// Whether the CLI is installed and accessible
    public let isInstalled: Bool

    /// Version string if detected (e.g., "1.0.17")
    public let version: String?

    /// Absolute path to the CLI executable
    public let path: String?

    public init(
        cliName: String,
        isInstalled: Bool,
        version: String? = nil,
        path: String? = nil
    ) {
        self.cliName = cliName
        self.isInstalled = isInstalled
        self.version = version
        self.path = path
    }
}

// MARK: - Install Progress

/// Progress tracking for CLI installation
public struct InstallProgress: Codable, Sendable, Equatable {
    /// Current step number (1-indexed)
    public let currentStep: Int

    /// Total number of steps in installation
    public let totalSteps: Int

    /// Human-readable description of current step
    public let stepDescription: String

    /// Time elapsed since installation started
    public let elapsedTime: TimeInterval

    /// Log output lines from installation process
    public let output: [String]

    public init(
        currentStep: Int,
        totalSteps: Int,
        stepDescription: String,
        elapsedTime: TimeInterval = 0,
        output: [String] = []
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.stepDescription = stepDescription
        self.elapsedTime = elapsedTime
        self.output = output
    }

    /// Progress as a fraction from 0.0 to 1.0
    public var fractionComplete: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }

    /// Returns a new progress with an appended log line
    public func appendingOutput(_ line: String) -> InstallProgress {
        InstallProgress(
            currentStep: currentStep,
            totalSteps: totalSteps,
            stepDescription: stepDescription,
            elapsedTime: elapsedTime,
            output: output + [line]
        )
    }

    /// Returns a new progress advanced to the next step
    public func advancingTo(step: Int, description: String, elapsed: TimeInterval) -> InstallProgress {
        InstallProgress(
            currentStep: step,
            totalSteps: totalSteps,
            stepDescription: description,
            elapsedTime: elapsed,
            output: output
        )
    }
}

// MARK: - CLI Setup State

/// State machine for CLI setup flow
public enum CLISetupState: Sendable, Equatable {
    /// Initial state before any action
    case idle

    /// Currently scanning for installed CLIs
    case scanning

    /// Scan complete with detection results
    case detected(results: [CLIDetectionResult])

    /// Installation in progress for a specific CLI
    case installing(cli: String, progress: InstallProgress)

    /// Setup completed successfully
    case complete

    /// User skipped the setup flow
    case skipped

    /// An error occurred during setup
    case error(message: String)
}

// MARK: - CLISetupState Codable Conformance

extension CLISetupState: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case results
        case cli
        case progress
        case message
    }

    private enum StateType: String, Codable {
        case idle
        case scanning
        case detected
        case installing
        case complete
        case skipped
        case error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StateType.self, forKey: .type)

        switch type {
        case .idle:
            self = .idle
        case .scanning:
            self = .scanning
        case .detected:
            let results = try container.decode([CLIDetectionResult].self, forKey: .results)
            self = .detected(results: results)
        case .installing:
            let cli = try container.decode(String.self, forKey: .cli)
            let progress = try container.decode(InstallProgress.self, forKey: .progress)
            self = .installing(cli: cli, progress: progress)
        case .complete:
            self = .complete
        case .skipped:
            self = .skipped
        case .error:
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .idle:
            try container.encode(StateType.idle, forKey: .type)
        case .scanning:
            try container.encode(StateType.scanning, forKey: .type)
        case .detected(let results):
            try container.encode(StateType.detected, forKey: .type)
            try container.encode(results, forKey: .results)
        case .installing(let cli, let progress):
            try container.encode(StateType.installing, forKey: .type)
            try container.encode(cli, forKey: .cli)
            try container.encode(progress, forKey: .progress)
        case .complete:
            try container.encode(StateType.complete, forKey: .type)
        case .skipped:
            try container.encode(StateType.skipped, forKey: .type)
        case .error(let message):
            try container.encode(StateType.error, forKey: .type)
            try container.encode(message, forKey: .message)
        }
    }
}

// MARK: - Convenience Extensions

extension CLISetupState {
    /// Whether the state machine is in a terminal state
    public var isTerminal: Bool {
        switch self {
        case .complete, .skipped, .error:
            return true
        case .idle, .scanning, .detected, .installing:
            return false
        }
    }

    /// Whether the state allows user interaction
    public var isInteractive: Bool {
        switch self {
        case .idle, .detected, .error:
            return true
        case .scanning, .installing, .complete, .skipped:
            return false
        }
    }

    /// Human-readable description of current state
    public var statusDescription: String {
        switch self {
        case .idle:
            return "Ready to scan"
        case .scanning:
            return "Scanning for CLIs..."
        case .detected(let results):
            let installed = results.filter(\.isInstalled).count
            return "\(installed) of \(results.count) CLIs detected"
        case .installing(let cli, let progress):
            return "Installing \(cli) (\(progress.currentStep)/\(progress.totalSteps))"
        case .complete:
            return "Setup complete"
        case .skipped:
            return "Setup skipped"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

extension CLIDetectionResult {
    /// Display string for version, or "Not installed" if missing
    public var versionDisplay: String {
        if isInstalled {
            return version ?? "Unknown version"
        }
        return "Not installed"
    }
}
