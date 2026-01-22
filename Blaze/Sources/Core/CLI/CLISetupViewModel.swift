import Foundation
import SwiftUI

// MARK: - CLISetupViewModel

/// ViewModel for CLI setup flow, bridging SwiftUI and CLIInstallationService.
///
/// Manages state transitions:
/// - idle → scanning → detected
/// - detected → installing → detected (or error)
/// - Any → complete/skipped
///
/// **E005-F005-S001-T006-A001**
@MainActor
@Observable
public final class CLISetupViewModel {

    // MARK: - Published State

    /// Current state machine state
    public private(set) var state: CLISetupState = .idle

    /// Cached detection results (available after scan completes)
    public private(set) var detectionResults: [CLIDetectionResult] = []

    // MARK: - Private

    /// Current installation task (for cancellation)
    private var installationTask: Task<Void, Never>?

    /// Service for CLI detection and installation
    private let service: CLIInstallationService

    // MARK: - Initialization

    public init(service: CLIInstallationService = .shared) {
        self.service = service
    }

    // MARK: - Actions

    /// Scans for installed CLIs.
    ///
    /// Transitions: idle → scanning → detected (or error)
    public func scan() {
        guard case .idle = state else { return }

        state = .scanning

        Task {
            let results = await service.detectAllCLIs()
            detectionResults = results
            state = .detected(results: results)
        }
    }

    /// Installs a specific CLI.
    ///
    /// Transitions: detected → installing → detected (or error)
    ///
    /// - Parameter cli: The CLI type to install
    public func install(_ cli: CLIType) {
        // Only allow installation from detected state
        guard case .detected = state else { return }

        let initialProgress = InstallProgress(
            currentStep: 0,
            totalSteps: 3,
            stepDescription: "Starting installation...",
            elapsedTime: 0,
            output: []
        )
        state = .installing(cli: cli.executable, progress: initialProgress)

        installationTask = Task {
            do {
                try await service.install(cli) { [weak self] progress in
                    Task { @MainActor in
                        guard let self = self else { return }
                        // Only update if still installing this CLI
                        if case .installing(let currentCli, _) = self.state,
                           currentCli == cli.executable {
                            self.state = .installing(cli: cli.executable, progress: progress)
                        }
                    }
                }

                // Re-scan to update detection results
                let results = await service.detectAllCLIs()
                detectionResults = results
                state = .detected(results: results)

            } catch is CancellationError {
                // Restore to detected state on cancellation
                state = .detected(results: detectionResults)

            } catch let error as CLIInstallationError {
                state = .error(message: error.localizedDescription)

            } catch {
                state = .error(message: error.localizedDescription)
            }
        }
    }

    /// Skips the setup flow.
    ///
    /// Transitions: Any → skipped
    public func skip() {
        cancelInstallation()
        state = .skipped
    }

    /// Cancels any in-progress installation.
    public func cancelInstallation() {
        installationTask?.cancel()
        installationTask = nil
    }

    /// Marks setup as complete.
    ///
    /// Typically called when at least one CLI is installed and user proceeds.
    public func complete() {
        cancelInstallation()
        state = .complete
    }

    /// Resets to idle state for re-scanning.
    public func reset() {
        cancelInstallation()
        detectionResults = []
        state = .idle
    }

    /// Dismisses an error and returns to detected state (or idle if no results).
    public func dismissError() {
        if detectionResults.isEmpty {
            state = .idle
        } else {
            state = .detected(results: detectionResults)
        }
    }

    // MARK: - Computed Properties

    /// Whether any CLI is currently installed
    public var hasInstalledCLI: Bool {
        detectionResults.contains { $0.isInstalled }
    }

    /// The recommended CLI if available and installed
    public var recommendedCLI: CLIDetectionResult? {
        detectionResults.first { result in
            CLIType.allCases.first { $0.executable == result.cliName }?.isRecommended == true
                && result.isInstalled
        }
    }

    /// CLIs that can be installed (not currently installed)
    public var installableCLIs: [CLIType] {
        CLIType.allCases.filter { cli in
            !detectionResults.contains { $0.cliName == cli.executable && $0.isInstalled }
        }
    }

    /// Whether user can proceed (has at least one CLI installed)
    public var canProceed: Bool {
        hasInstalledCLI && state.isInteractive
    }
}
