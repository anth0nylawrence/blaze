import SwiftUI
import Observation

// MARK: - Agent Detection Types

/// Represents a detected agent from Claude Code configuration.
public struct DetectedAgent: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String
    public let colorName: String  // Stored as string for simple color mapping
    public let model: String
    public let source: AgentSource
    public var isEnabled: Bool

    public enum AgentSource: String, Equatable {
        case global = "~/.claude/agents"
        case project = ".claude/agents"
        case builtin = "Built-in"
    }

    public init(
        id: String,
        name: String,
        description: String,
        icon: String,
        colorName: String,
        model: String,
        source: AgentSource,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.colorName = colorName
        self.model = model
        self.source = source
        self.isEnabled = isEnabled
    }

    /// Default icon based on agent type/name
    public static func iconFor(name: String) -> String {
        switch name.lowercased() {
        case "kraken": return "hammer.fill"
        case "scout": return "magnifyingglass"
        case "spark": return "bolt.fill"
        case "arbiter": return "checkmark.shield.fill"
        case "sleuth": return "ant.fill"
        case "oracle": return "globe"
        case "phoenix": return "flame.fill"
        case "architect": return "building.2.fill"
        case "atlas": return "map.fill"
        case "aegis": return "shield.fill"
        case "maestro": return "wand.and.stars"
        case "cto": return "person.crop.rectangle.badge.plus"
        case "herald": return "megaphone.fill"
        case "chronicler": return "book.fill"
        case "critic": return "eye.fill"
        case "judge": return "scalemass.fill"
        case "liaison": return "person.2.fill"
        default: return "cpu.fill"
        }
    }

    /// Default color name based on agent type/name
    public static func colorNameFor(name: String) -> String {
        switch name.lowercased() {
        case "kraken": return "purple"
        case "scout": return "blue"
        case "spark": return "orange"
        case "arbiter": return "green"
        case "sleuth": return "red"
        case "oracle": return "cyan"
        case "phoenix": return "orange"
        case "architect": return "indigo"
        case "atlas": return "teal"
        case "aegis": return "mint"
        case "maestro": return "pink"
        case "cto": return "yellow"
        case "herald": return "purple"
        case "chronicler": return "brown"
        case "critic": return "gray"
        case "judge": return "indigo"
        case "liaison": return "cyan"
        default: return "gray"
        }
    }
}

/// State for agent scanning.
public enum AgentScanState: Equatable {
    case idle
    case scanning
    case completed
    case error(String)
}

// MARK: - Skill Detection Types

/// Represents a detected skill from CLI configuration directories.
public struct DetectedSkill: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String
    public let sourceCLI: String  // "claude", "gemini", "codex"
    public let filePath: URL
    public var isEnabled: Bool

    public init(
        id: String,
        name: String,
        description: String,
        icon: String,
        sourceCLI: String,
        filePath: URL,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.sourceCLI = sourceCLI
        self.filePath = filePath
        self.isEnabled = isEnabled
    }

    /// Default icon based on skill name
    public static func iconFor(name: String) -> String {
        switch name.lowercased() {
        case "commit": return "arrow.triangle.branch"
        case "test": return "checkmark.diamond"
        case "debug": return "ladybug"
        case "review": return "eye"
        case "refactor": return "arrow.triangle.2.circlepath"
        case "explore": return "magnifyingglass"
        case "fix": return "wrench.and.screwdriver"
        case "security": return "lock.shield"
        case "release": return "shippingbox"
        case "tdd": return "testtube.2"
        case "migrate": return "arrow.left.arrow.right"
        case "research": return "book"
        case "help": return "questionmark.circle"
        case "plan": return "list.bullet.clipboard"
        case "implement": return "hammer"
        case "onboard": return "person.badge.plus"
        default: return "star"
        }
    }
}

/// Detection state for skill scan.
public enum SkillScanState: Equatable {
    case idle
    case scanning
    case completed
    case error(String)
}

// MARK: - CLI Detection Types

/// Represents a detected CLI tool with its metadata.
public struct DetectedCLI: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let command: String
    public let icon: String
    public var isDetected: Bool
    public var path: String?
    public var version: String?

    /// Custom detection command (e.g., "gh copilot --version" instead of "which gh")
    /// If nil, uses standard `which <command>` detection.
    public let detectionCommand: String?

    /// Install command for uninstalled CLIs (nil if no installer available)
    public let installCommand: String?

    /// Documentation URL for the CLI
    public let installUrl: String?

    public init(
        id: String,
        name: String,
        command: String,
        icon: String,
        isDetected: Bool = false,
        path: String? = nil,
        version: String? = nil,
        detectionCommand: String? = nil,
        installCommand: String? = nil,
        installUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.icon = icon
        self.isDetected = isDetected
        self.path = path
        self.version = version
        self.detectionCommand = detectionCommand
        self.installCommand = installCommand
        self.installUrl = installUrl
    }
}

/// Detection state for the CLI scan.
public enum CLIDetectionState: Equatable {
    case idle
    case scanning
    case completed
    case error(String)
}

// MARK: - MCP Detection Types

/// Represents a detected MCP server from CLI configuration.
public struct DetectedMCP: Identifiable, Equatable {
    /// Unique identifier combining sourceCLI and server name (e.g., "claude-filesystem")
    public let id: String
    /// Server name as configured (e.g., "filesystem")
    public let name: String
    public let command: String
    public let args: [String]
    public let sourceCLI: String  // "claude", "gemini", "codex"
    public var isEnabled: Bool

    public init(name: String, command: String, args: [String], sourceCLI: String, isEnabled: Bool = true) {
        self.id = "\(sourceCLI)-\(name)"  // Unique across CLIs
        self.name = name
        self.command = command
        self.args = args
        self.sourceCLI = sourceCLI
        self.isEnabled = isEnabled
    }

    /// Display-friendly server type based on command
    public var serverType: String {
        if command.contains("npx") || command.contains("node") {
            return "Node.js"
        } else if command.contains("python") || command.contains("uvx") || command.contains("uv") {
            return "Python"
        } else if command.contains("docker") {
            return "Docker"
        } else {
            return "Binary"
        }
    }

    /// Icon name based on server type
    public var icon: String {
        switch serverType {
        case "Node.js": return "curlybraces"
        case "Python": return "chevron.left.forwardslash.chevron.right"
        case "Docker": return "shippingbox"
        default: return "terminal"
        }
    }
}

/// Detection state for MCP scan.
public enum MCPDetectionState: Equatable {
    case idle
    case scanning
    case completed
    case error(String)
}

/// User experience level for tailoring the UI.
public enum ExperienceLevel: String, CaseIterable, Sendable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    public var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    public var description: String {
        switch self {
        case .beginner: return "New to AI coding assistants"
        case .intermediate: return "Some experience with AI tools"
        case .advanced: return "Power user, show me everything"
        }
    }
}

/// User's primary use case for Blaze.
public enum PrimaryUseCase: String, CaseIterable, Sendable {
    case personal = "personal"
    case professional = "professional"
    case learning = "learning"

    public var displayName: String {
        switch self {
        case .personal: return "Personal Projects"
        case .professional: return "Professional Work"
        case .learning: return "Learning & Exploration"
        }
    }
}

// MARK: - Onboarding View Model

/// Observable view model managing onboarding state and navigation.
///
/// Use via `@Environment(OnboardingViewModel.self)` in views.
@Observable
public final class OnboardingViewModel {
    // MARK: - Persisted State

    /// Whether the user has completed (or skipped) onboarding.
    /// Persisted in UserDefaults and checked at app launch.
    @ObservationIgnored
    @AppStorage("hasCompletedOnboarding") public var hasCompletedOnboarding: Bool = false

    // MARK: - Navigation State

    /// Current step in the onboarding flow.
    public var currentStep: OnboardingStep = .welcome

    // MARK: - User Profile State

    /// User's display name (optional, can be skipped).
    public var displayName: String = ""

    /// Alias for displayName to match spec naming.
    public var userName: String {
        get { displayName }
        set { displayName = newValue }
    }

    /// User's experience level with AI coding assistants.
    public var experienceLevel: ExperienceLevel = .intermediate

    /// Alias for experienceLevel to match spec naming.
    public var userExperienceLevel: ExperienceLevel {
        get { experienceLevel }
        set { experienceLevel = newValue }
    }

    /// User's primary use case for Blaze.
    public var primaryUseCase: PrimaryUseCase = .personal

    // MARK: - Onboarding State

    /// Whether the onboarding flow is complete (either finished or skipped).
    public private(set) var isComplete: Bool = false

    /// Whether the user explicitly skipped onboarding.
    public private(set) var wasSkipped: Bool = false

    /// Completion handler called when onboarding finishes.
    public var onComplete: (() -> Void)?

    // MARK: - CLI Detection State

    /// List of CLIs to detect.
    public private(set) var detectedCLIs: [DetectedCLI] = [
        // Primary CLIs (fully supported)
        DetectedCLI(
            id: "claude",
            name: "Claude Code",
            command: "claude",
            icon: "bubble.left.and.text.bubble.right",
            installUrl: "https://docs.anthropic.com/en/docs/claude-code"
        ),
        DetectedCLI(
            id: "gemini",
            name: "Gemini CLI",
            command: "gemini",
            icon: "sparkle",
            installUrl: "https://github.com/google-gemini/gemini-cli"
        ),
        DetectedCLI(
            id: "codex",
            name: "OpenAI Codex",
            command: "codex",
            icon: "brain.head.profile",
            installUrl: "https://github.com/openai/codex"
        ),
        // Additional CLIs
        DetectedCLI(
            id: "ampcode",
            name: "Ampcode",
            command: "amp",
            icon: "bolt.fill",
            installCommand: "curl -fsSL https://ampcode.com/install.sh | bash",
            installUrl: "https://ampcode.com"
        ),
        DetectedCLI(
            id: "copilot",
            name: "GitHub Copilot",
            command: "gh",
            icon: "chevron.left.forwardslash.chevron.right",
            detectionCommand: "gh copilot --version",
            installCommand: "curl -fsSL https://gh.io/copilot-install | bash",
            installUrl: "https://github.com/features/copilot"
        ),
        DetectedCLI(
            id: "kiro",
            name: "Kiro CLI",
            command: "kiro",
            icon: "cube",
            installCommand: "curl -fsSL https://cli.kiro.dev/install | bash",
            installUrl: "https://kiro.dev"
        ),
        DetectedCLI(
            id: "crush",
            name: "Crush",
            command: "mods",
            icon: "heart.fill",
            installCommand: "go install github.com/charmbracelet/mods@latest",
            installUrl: "https://github.com/charmbracelet/mods"
        ),
        DetectedCLI(
            id: "pimono",
            name: "Pi-Mono",
            command: "mono",
            icon: "circle.grid.3x3",
            installUrl: "https://github.com/pimono/mono"
        )
    ]

    /// Current state of CLI detection.
    public private(set) var cliDetectionState: CLIDetectionState = .idle

    /// Number of CLIs detected.
    public var detectedCLICount: Int {
        detectedCLIs.filter { $0.isDetected }.count
    }

    /// Whether CLI detection is in progress.
    public var isDetectingCLIs: Bool {
        cliDetectionState == .scanning
    }

    // MARK: - MCP Detection State

    /// List of detected MCP servers from Claude settings.
    public private(set) var detectedMCPs: [DetectedMCP] = []

    /// Current state of MCP detection.
    public private(set) var mcpDetectionState: MCPDetectionState = .idle

    /// Whether MCP detection is in progress.
    public var isDetectingMCPs: Bool {
        mcpDetectionState == .scanning
    }

    /// Number of MCPs enabled.
    public var enabledMCPCount: Int {
        detectedMCPs.filter { $0.isEnabled }.count
    }

    /// MCPs grouped by source CLI for display.
    public var mcpsByCLI: [String: [DetectedMCP]] {
        Dictionary(grouping: detectedMCPs, by: { $0.sourceCLI })
    }

    /// Summary of MCP counts per CLI (e.g., ["claude": 3, "gemini": 1, "codex": 0])
    public var mcpCountByCLI: [String: Int] {
        var counts: [String: Int] = [:]
        for cli in detectedCLIs where cli.isDetected {
            counts[cli.id] = detectedMCPs.filter { $0.sourceCLI == cli.id }.count
        }
        return counts
    }

    // MARK: - Agent Detection State

    /// List of detected agents from Claude Code configuration.
    public private(set) var detectedAgents: [DetectedAgent] = []

    /// Current state of agent detection.
    public private(set) var agentScanState: AgentScanState = .idle

    /// Whether agent detection is in progress.
    public var isDetectingAgents: Bool {
        agentScanState == .scanning
    }

    /// Number of agents enabled.
    public var enabledAgentCount: Int {
        detectedAgents.filter { $0.isEnabled }.count
    }

    // MARK: - Skill Detection State

    /// List of detected skills from CLI configuration directories.
    public private(set) var detectedSkills: [DetectedSkill] = []

    /// Current state of skill detection.
    public private(set) var skillScanState: SkillScanState = .idle

    /// Whether skill detection is in progress.
    public var isDetectingSkills: Bool {
        skillScanState == .scanning
    }

    /// Number of skills enabled.
    public var enabledSkillCount: Int {
        detectedSkills.filter { $0.isEnabled }.count
    }

    /// Skills grouped by source CLI for display.
    public var skillsByCLI: [String: [DetectedSkill]] {
        Dictionary(grouping: detectedSkills, by: { $0.sourceCLI })
    }

    /// Summary of skill counts per CLI (e.g., ["claude": 15, "gemini": 3])
    public var skillCountByCLI: [String: Int] {
        var counts: [String: Int] = [:]
        for cli in detectedCLIs where cli.isDetected {
            counts[cli.id] = detectedSkills.filter { $0.sourceCLI == cli.id }.count
        }
        return counts
    }

    // MARK: - Recommendations State

    public var selectedSkills: Set<String> = []
    public var selectedPlugins: Set<String> = []
    public var selectedAgents: Set<String> = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Navigation

    /// Advances to the next step if validation passes.
    public func goToNextStep() {
        guard canProceedFromCurrentStep() else { return }

        if let next = currentStep.next {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = next
            }
        } else {
            completeOnboarding()
        }
    }

    /// Goes back to the previous step. No validation needed.
    public func goToPreviousStep() {
        if let previous = currentStep.previous {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = previous
            }
        }
    }

    /// Legacy alias for `goToNextStep()`.
    public func nextStep() {
        goToNextStep()
    }

    /// Legacy alias for `goToPreviousStep()`.
    public func previousStep() {
        goToPreviousStep()
    }

    /// Jump to a specific step.
    public func goToStep(_ step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
    }

    /// Convenience alias for `goToNextStep()`.
    public func goForward() {
        goToNextStep()
    }

    /// Convenience alias for `goToPreviousStep()`.
    public func goBack() {
        goToPreviousStep()
    }

    /// Skip the onboarding flow entirely.
    /// Sets hasCompletedOnboarding immediately without going through other steps.
    public func skipOnboarding() {
        wasSkipped = true
        hasCompletedOnboarding = true
        withAnimation(.easeInOut(duration: 0.3)) {
            isComplete = true
        }
        onComplete?()
    }

    // MARK: - Completion

    /// Marks onboarding as complete. Called when user finishes the flow.
    public func completeOnboarding() {
        hasCompletedOnboarding = true
        withAnimation(.easeInOut(duration: 0.3)) {
            isComplete = true
        }
        onComplete?()
    }

    /// Reset the onboarding state for testing or re-onboarding.
    public func reset() {
        currentStep = .welcome
        isComplete = false
        wasSkipped = false
        hasCompletedOnboarding = false
        resetCLIDetection()
    }

    // MARK: - Validation

    /// Returns whether the user can proceed from the current step.
    /// Each step may have different validation requirements.
    public func canProceedFromCurrentStep() -> Bool {
        switch currentStep {
        case .welcome:
            // Welcome has no requirements - can always proceed
            return true

        case .userProfile:
            // User profile is optional - can skip with empty name
            return true

        case .cliDetection:
            // CLI detection can proceed even with no CLIs detected
            // (user might install later), but must wait for scan to complete
            return !isDetectingCLIs

        case .skillsRecommendations:
            // Skills are optional - can skip
            return true

        case .pluginsRecommendations:
            // Plugins are optional - can skip
            return true

        case .agentsRecommendations:
            // Agents are optional - can skip
            return true

        case .completion:
            // Completion always allows finishing
            return true
        }
    }

    /// Validation message if the user cannot proceed.
    public var validationMessage: String? {
        guard !canProceedFromCurrentStep() else { return nil }

        switch currentStep {
        case .cliDetection:
            return "Please wait for CLI detection to complete"
        default:
            return nil
        }
    }

    // MARK: - CLI Detection

    /// Scan for installed CLI tools using `which` command or custom detection.
    @MainActor
    public func scanForCLIs() async {
        cliDetectionState = .scanning

        // Reset detection state
        for index in detectedCLIs.indices {
            detectedCLIs[index].isDetected = false
            detectedCLIs[index].path = nil
            detectedCLIs[index].version = nil
        }

        // Check each CLI
        for index in detectedCLIs.indices {
            let cli = detectedCLIs[index]

            if let customDetection = cli.detectionCommand {
                // Use custom detection command (e.g., "gh copilot --version")
                if let version = await runCustomDetection(command: customDetection) {
                    detectedCLIs[index].isDetected = true
                    detectedCLIs[index].version = version
                    // For custom detection, try to get the path too
                    if let path = await detectCLIPath(command: cli.command) {
                        detectedCLIs[index].path = path
                    }
                }
            } else {
                // Standard `which <command>` detection
                if let path = await detectCLIPath(command: cli.command) {
                    detectedCLIs[index].isDetected = true
                    detectedCLIs[index].path = path
                }
            }
        }

        cliDetectionState = .completed
    }

    /// Detect a single CLI using the `which` command.
    private func detectCLIPath(command: String) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [command]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !path.isEmpty {
                        continuation.resume(returning: path)
                        return
                    }
                }
                continuation.resume(returning: nil)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    /// Run a custom detection command (e.g., "gh copilot --version").
    /// Returns the output if successful, nil otherwise.
    private func runCustomDetection(command: String) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !output.isEmpty {
                        continuation.resume(returning: output)
                        return
                    }
                }
                continuation.resume(returning: nil)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    /// Reset CLI detection state.
    public func resetCLIDetection() {
        cliDetectionState = .idle
        for index in detectedCLIs.indices {
            detectedCLIs[index].isDetected = false
            detectedCLIs[index].path = nil
        }
    }

    // MARK: - MCP Detection

    /// MCP config locations for each CLI
    private struct MCPConfigLocation {
        let cliId: String
        let path: URL
        let parser: MCPConfigParser

        enum MCPConfigParser {
            case claudeJSON  // ~/.claude/settings.json -> mcpServers
            case geminiJSON  // ~/.gemini/settings.json -> mcpServers (if supported)
            case codexTOML   // ~/.codex/config.toml -> [mcp] section (if supported)
        }
    }

    /// Scan for MCP servers configured across all detected CLIs.
    /// Scans multiple locations:
    /// - Claude Desktop: ~/Library/Application Support/Claude/claude_desktop_config.json
    /// - Claude Code CLI: ~/.claude/settings.json
    /// - Gemini: ~/.gemini/settings.json
    /// - Codex: ~/.codex/config.toml
    @MainActor
    public func scanForMCPs() async {
        mcpDetectionState = .scanning
        detectedMCPs = []

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        var allDetected: [DetectedMCP] = []

        // Scan Claude Desktop config (primary location for MCP servers)
        let claudeDesktopPath = homeDir
            .appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
        let claudeDesktopMCPs = await scanClaudeMCPs(at: claudeDesktopPath)
        allDetected.append(contentsOf: claudeDesktopMCPs)

        // Scan Claude Code CLI config (secondary location)
        let claudeCliMCPs = await scanClaudeMCPs(at: homeDir.appendingPathComponent(".claude/settings.json"))
        // Only add if not already found in Desktop config (avoid duplicates by name)
        for mcp in claudeCliMCPs {
            if !allDetected.contains(where: { $0.name == mcp.name && $0.sourceCLI == mcp.sourceCLI }) {
                allDetected.append(mcp)
            }
        }

        // Scan Gemini CLI config (JSON format, same structure as Claude if supported)
        let geminiMCPs = await scanGeminiMCPs(at: homeDir.appendingPathComponent(".gemini/settings.json"))
        allDetected.append(contentsOf: geminiMCPs)

        // Scan Codex CLI config (TOML format)
        let codexMCPs = await scanCodexMCPs(at: homeDir.appendingPathComponent(".codex/config.toml"))
        allDetected.append(contentsOf: codexMCPs)

        // Sort alphabetically by name within each CLI group
        detectedMCPs = allDetected.sorted {
            if $0.sourceCLI != $1.sourceCLI {
                return $0.sourceCLI < $1.sourceCLI
            }
            return $0.name.lowercased() < $1.name.lowercased()
        }
        mcpDetectionState = .completed
    }

    /// Scan Claude Code's settings.json for MCP servers
    private func scanClaudeMCPs(at path: URL) async -> [DetectedMCP] {
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }

        do {
            let data = try Data(contentsOf: path)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let mcpServers = json["mcpServers"] as? [String: Any] else {
                return []
            }

            return parseMCPServersJSON(mcpServers, sourceCLI: "claude")
        } catch {
            return []
        }
    }

    /// Scan Gemini CLI's settings.json for MCP servers (if supported)
    private func scanGeminiMCPs(at path: URL) async -> [DetectedMCP] {
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }

        do {
            let data = try Data(contentsOf: path)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let mcpServers = json["mcpServers"] as? [String: Any] else {
                return []
            }

            return parseMCPServersJSON(mcpServers, sourceCLI: "gemini")
        } catch {
            return []
        }
    }

    /// Scan Codex CLI's config.toml for MCP servers (if supported)
    private func scanCodexMCPs(at path: URL) async -> [DetectedMCP] {
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }

        // Codex uses TOML format. Parse [mcp.*] sections.
        // Simple TOML parsing for [mcp.servername] sections
        do {
            let content = try String(contentsOf: path, encoding: .utf8)
            return parseMCPServersTOML(content, sourceCLI: "codex")
        } catch {
            return []
        }
    }

    /// Parse MCP servers from JSON format (Claude/Gemini style)
    private func parseMCPServersJSON(_ mcpServers: [String: Any], sourceCLI: String) -> [DetectedMCP] {
        var detected: [DetectedMCP] = []

        for (serverName, serverConfig) in mcpServers {
            guard let config = serverConfig as? [String: Any],
                  let command = config["command"] as? String else {
                continue
            }

            let args = config["args"] as? [String] ?? []

            detected.append(DetectedMCP(
                name: serverName,
                command: command,
                args: args,
                sourceCLI: sourceCLI
            ))
        }

        return detected
    }

    /// Parse MCP servers from TOML format (Codex style)
    /// Looks for [mcp.servername] sections with command = "..." and args = [...]
    private func parseMCPServersTOML(_ content: String, sourceCLI: String) -> [DetectedMCP] {
        var detected: [DetectedMCP] = []

        // Simple regex-based TOML parsing for [mcp.*] sections
        let lines = content.components(separatedBy: .newlines)
        var currentServer: String? = nil
        var currentCommand: String? = nil
        var currentArgs: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for [mcp.servername] section header
            if trimmed.hasPrefix("[mcp.") && trimmed.hasSuffix("]") {
                // Save previous server if exists
                if let server = currentServer, let command = currentCommand {
                    detected.append(DetectedMCP(
                        name: server,
                        command: command,
                        args: currentArgs,
                        sourceCLI: sourceCLI
                    ))
                }

                // Start new server
                let start = trimmed.index(trimmed.startIndex, offsetBy: 5)
                let end = trimmed.index(trimmed.endIndex, offsetBy: -1)
                currentServer = String(trimmed[start..<end])
                currentCommand = nil
                currentArgs = []
            }
            // Check for command = "..."
            else if currentServer != nil && trimmed.hasPrefix("command") {
                // Parse: command = "some-command"
                if let eqIndex = trimmed.firstIndex(of: "=") {
                    var value = String(trimmed[trimmed.index(after: eqIndex)...])
                        .trimmingCharacters(in: .whitespaces)
                    // Remove surrounding quotes
                    if value.hasPrefix("\"") && value.hasSuffix("\"") {
                        value = String(value.dropFirst().dropLast())
                    }
                    if !value.isEmpty {
                        currentCommand = value
                    }
                }
            }
            // Check for args = [...]
            else if currentServer != nil && trimmed.hasPrefix("args") {
                // Parse: args = ["arg1", "arg2"]
                if let openBracket = trimmed.firstIndex(of: "["),
                   let closeBracket = trimmed.lastIndex(of: "]") {
                    let argsContent = String(trimmed[trimmed.index(after: openBracket)..<closeBracket])
                    currentArgs = argsContent
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
                        .filter { !$0.isEmpty }
                }
            }
            // Check for new section (ends current mcp section)
            else if trimmed.hasPrefix("[") && !trimmed.hasPrefix("[mcp.") {
                if let server = currentServer, let command = currentCommand {
                    detected.append(DetectedMCP(
                        name: server,
                        command: command,
                        args: currentArgs,
                        sourceCLI: sourceCLI
                    ))
                }
                currentServer = nil
                currentCommand = nil
                currentArgs = []
            }
        }

        // Don't forget the last server
        if let server = currentServer, let command = currentCommand {
            detected.append(DetectedMCP(
                name: server,
                command: command,
                args: currentArgs,
                sourceCLI: sourceCLI
            ))
        }

        return detected
    }

    /// Toggle an MCP server's enabled state.
    public func toggleMCP(id: String) {
        if let index = detectedMCPs.firstIndex(where: { $0.id == id }) {
            detectedMCPs[index].isEnabled.toggle()
            // Update selectedPlugins to reflect enabled MCPs
            if detectedMCPs[index].isEnabled {
                selectedPlugins.insert(id)
            } else {
                selectedPlugins.remove(id)
            }
        }
    }

    /// Reset MCP detection state.
    public func resetMCPDetection() {
        mcpDetectionState = .idle
        detectedMCPs = []
    }

    // MARK: - Agent Detection

    /// Scan for agents in ~/.claude/agents/ directory.
    /// Agents are markdown files with YAML frontmatter containing name, description, model.
    @MainActor
    public func scanForAgents() async {
        agentScanState = .scanning
        detectedAgents = []

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let globalAgentsPath = homeDir.appendingPathComponent(".claude/agents")

        var agents: [DetectedAgent] = []

        // Scan global agents directory
        if FileManager.default.fileExists(atPath: globalAgentsPath.path) {
            let globalAgents = await scanAgentsDirectory(at: globalAgentsPath, source: .global)
            agents.append(contentsOf: globalAgents)
        }

        // Sort alphabetically by name
        detectedAgents = agents.sorted { $0.name.lowercased() < $1.name.lowercased() }

        // Pre-select all detected agents
        selectedAgents = Set(detectedAgents.map { $0.id })

        agentScanState = .completed
    }

    /// Scan a directory for agent markdown files.
    private func scanAgentsDirectory(at path: URL, source: DetectedAgent.AgentSource) async -> [DetectedAgent] {
        var agents: [DetectedAgent] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: path,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return agents
        }

        for fileURL in contents where fileURL.pathExtension == "md" {
            if let agent = await parseAgentFile(at: fileURL, source: source) {
                agents.append(agent)
            }
        }

        return agents
    }

    /// Parse an agent markdown file with YAML frontmatter.
    private func parseAgentFile(at url: URL, source: DetectedAgent.AgentSource) async -> DetectedAgent? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        // Check for YAML frontmatter (starts with ---)
        guard content.hasPrefix("---") else {
            return nil
        }

        // Find end of frontmatter
        let lines = content.components(separatedBy: .newlines)
        var frontmatterEnd = -1
        for (index, line) in lines.enumerated() {
            if index > 0 && line == "---" {
                frontmatterEnd = index
                break
            }
        }

        guard frontmatterEnd > 0 else {
            return nil
        }

        // Parse YAML frontmatter (simple key: value parsing)
        let frontmatterLines = Array(lines[1..<frontmatterEnd])
        var frontmatter: [String: String] = [:]

        for line in frontmatterLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                frontmatter[key] = value
            }
        }

        // Extract agent properties
        guard let name = frontmatter["name"], !name.isEmpty else {
            return nil
        }

        let description = frontmatter["description"] ?? "No description"
        let model = frontmatter["model"] ?? "unknown"
        let id = url.deletingPathExtension().lastPathComponent

        return DetectedAgent(
            id: id,
            name: name.capitalized,
            description: description,
            icon: DetectedAgent.iconFor(name: name),
            colorName: DetectedAgent.colorNameFor(name: name),
            model: model,
            source: source,
            isEnabled: true
        )
    }

    /// Toggle an agent's enabled state.
    public func toggleAgent(id: String) {
        if let index = detectedAgents.firstIndex(where: { $0.id == id }) {
            detectedAgents[index].isEnabled.toggle()
            // Update selectedAgents to reflect enabled state
            if detectedAgents[index].isEnabled {
                selectedAgents.insert(id)
            } else {
                selectedAgents.remove(id)
            }
        }
    }

    /// Enable all detected agents.
    public func enableAllAgents() {
        for index in detectedAgents.indices {
            detectedAgents[index].isEnabled = true
        }
        selectedAgents = Set(detectedAgents.map { $0.id })
    }

    /// Disable all detected agents.
    public func disableAllAgents() {
        for index in detectedAgents.indices {
            detectedAgents[index].isEnabled = false
        }
        selectedAgents = []
    }

    /// Reset agent detection state.
    public func resetAgentDetection() {
        agentScanState = .idle
        detectedAgents = []
    }

    // MARK: - Skill Detection

    /// Defines a skill directory location with its CLI source and scan type.
    private struct SkillLocation {
        let cliId: String
        let cliDisplayName: String
        let path: URL
        let scanType: ScanType

        enum ScanType {
            case skillMdInSubdirs    // Look for SKILL.md in subdirectories (Claude/Codex/AmpCode)
            case mdFilesDirectly     // Look for *.md files directly (OpenCode)
            case geminiExtensions    // Look for gemini-extension.json files (Gemini)
        }

        /// Returns all global skill locations (expand ~ to home directory)
        static func globalLocations(homeDir: URL) -> [SkillLocation] {
            return [
                // Claude Code: ~/.claude/skills/*/SKILL.md
                SkillLocation(
                    cliId: "claude",
                    cliDisplayName: "Claude Code",
                    path: homeDir.appendingPathComponent(".claude/skills"),
                    scanType: .skillMdInSubdirs
                ),
                // OpenAI Codex CLI: ~/.codex/skills/*/SKILL.md
                SkillLocation(
                    cliId: "codex",
                    cliDisplayName: "OpenAI Codex",
                    path: homeDir.appendingPathComponent(".codex/skills"),
                    scanType: .skillMdInSubdirs
                ),
                // Gemini CLI: ~/.gemini/extensions/*/gemini-extension.json
                SkillLocation(
                    cliId: "gemini",
                    cliDisplayName: "Gemini CLI",
                    path: homeDir.appendingPathComponent(".gemini/extensions"),
                    scanType: .geminiExtensions
                ),
                // OpenCode: ~/.config/opencode/command/*.md
                SkillLocation(
                    cliId: "opencode",
                    cliDisplayName: "OpenCode",
                    path: homeDir.appendingPathComponent(".config/opencode/command"),
                    scanType: .mdFilesDirectly
                ),
                // AmpCode: ~/.config/agents/skills/*/SKILL.md
                SkillLocation(
                    cliId: "ampcode",
                    cliDisplayName: "AmpCode",
                    path: homeDir.appendingPathComponent(".config/agents/skills"),
                    scanType: .skillMdInSubdirs
                )
            ]
        }

        /// Returns project-local skill locations (relative to project root)
        static func projectLocations(projectRoot: URL) -> [SkillLocation] {
            return [
                SkillLocation(
                    cliId: "claude",
                    cliDisplayName: "Claude Code",
                    path: projectRoot.appendingPathComponent(".claude/skills"),
                    scanType: .skillMdInSubdirs
                ),
                SkillLocation(
                    cliId: "codex",
                    cliDisplayName: "OpenAI Codex",
                    path: projectRoot.appendingPathComponent(".codex/skills"),
                    scanType: .skillMdInSubdirs
                ),
                SkillLocation(
                    cliId: "gemini",
                    cliDisplayName: "Gemini CLI",
                    path: projectRoot.appendingPathComponent(".gemini/extensions"),
                    scanType: .geminiExtensions
                ),
                SkillLocation(
                    cliId: "opencode",
                    cliDisplayName: "OpenCode",
                    path: projectRoot.appendingPathComponent(".opencode/command"),
                    scanType: .mdFilesDirectly
                ),
                SkillLocation(
                    cliId: "ampcode",
                    cliDisplayName: "AmpCode",
                    path: projectRoot.appendingPathComponent(".agents/skills"),
                    scanType: .skillMdInSubdirs
                )
            ]
        }
    }

    /// Scan for skills in CLI configuration directories.
    /// Scans multiple directories for different skill formats:
    /// - Claude/Codex/AmpCode: SKILL.md files in subdirectories
    /// - OpenCode: *.md files directly in the command directory
    /// - Gemini: gemini-extension.json files in subdirectories
    @MainActor
    public func scanForSkills() async {
        skillScanState = .scanning
        detectedSkills = []

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        var allSkills: [DetectedSkill] = []

        // Scan all global skill directories
        for location in SkillLocation.globalLocations(homeDir: homeDir) {
            if FileManager.default.fileExists(atPath: location.path.path) {
                let skills = await scanSkillsLocation(location)
                allSkills.append(contentsOf: skills)
            }
        }

        // Sort alphabetically by name within each CLI group
        detectedSkills = allSkills.sorted {
            if $0.sourceCLI != $1.sourceCLI {
                // Order: claude, codex, gemini, opencode, ampcode, then others
                let order = ["claude", "codex", "gemini", "opencode", "ampcode"]
                let aIndex = order.firstIndex(of: $0.sourceCLI) ?? Int.max
                let bIndex = order.firstIndex(of: $1.sourceCLI) ?? Int.max
                if aIndex != bIndex {
                    return aIndex < bIndex
                }
                return $0.sourceCLI < $1.sourceCLI
            }
            return $0.name.lowercased() < $1.name.lowercased()
        }

        // Pre-select all detected skills (opt-out by default)
        selectedSkills = Set(detectedSkills.map { $0.id })

        skillScanState = .completed
    }

    /// Scan a skill location based on its scan type.
    private func scanSkillsLocation(_ location: SkillLocation) async -> [DetectedSkill] {
        switch location.scanType {
        case .skillMdInSubdirs:
            return await scanSkillMdInSubdirs(at: location.path, sourceCLI: location.cliId)
        case .mdFilesDirectly:
            return await scanMdFilesDirectly(at: location.path, sourceCLI: location.cliId)
        case .geminiExtensions:
            return await scanGeminiExtensions(at: location.path, sourceCLI: location.cliId)
        }
    }

    /// Scan for SKILL.md files inside subdirectories (Claude/Codex/AmpCode pattern).
    /// Structure: skills/skill-name/SKILL.md
    private func scanSkillMdInSubdirs(at path: URL, sourceCLI: String) async -> [DetectedSkill] {
        var skills: [DetectedSkill] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: path,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return skills
        }

        for itemURL in contents {
            // Check if it's a directory
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            // Skip special directories like archive, _sandbox
            let dirName = itemURL.lastPathComponent.lowercased()
            if dirName.hasPrefix("_") || dirName == "archive" {
                continue
            }

            // Look for SKILL.md in this subdirectory
            let skillMdPath = itemURL.appendingPathComponent("SKILL.md")
            if FileManager.default.fileExists(atPath: skillMdPath.path) {
                if let skill = await parseSkillFile(at: skillMdPath, sourceCLI: sourceCLI, skillDirName: itemURL.lastPathComponent) {
                    skills.append(skill)
                }
            }
        }

        return skills
    }

    /// Scan for *.md files directly in the directory (OpenCode pattern).
    /// Structure: command/skill-name.md
    private func scanMdFilesDirectly(at path: URL, sourceCLI: String) async -> [DetectedSkill] {
        var skills: [DetectedSkill] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: path,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return skills
        }

        for fileURL in contents where fileURL.pathExtension == "md" {
            // Skip README files
            let filename = fileURL.deletingPathExtension().lastPathComponent.lowercased()
            if filename == "readme" { continue }

            if let skill = await parseSkillFile(at: fileURL, sourceCLI: sourceCLI, skillDirName: nil) {
                skills.append(skill)
            }
        }

        return skills
    }

    /// Scan for gemini-extension.json files in subdirectories (Gemini pattern).
    /// Structure: extensions/extension-name/gemini-extension.json
    private func scanGeminiExtensions(at path: URL, sourceCLI: String) async -> [DetectedSkill] {
        var skills: [DetectedSkill] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: path,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return skills
        }

        for itemURL in contents {
            // Check if it's a directory
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            // Look for gemini-extension.json in this subdirectory
            let extensionJsonPath = itemURL.appendingPathComponent("gemini-extension.json")
            if FileManager.default.fileExists(atPath: extensionJsonPath.path) {
                if let skill = await parseGeminiExtensionFile(at: extensionJsonPath, sourceCLI: sourceCLI, extensionDirName: itemURL.lastPathComponent) {
                    skills.append(skill)
                }
            }
        }

        return skills
    }

    /// Parse a Gemini extension JSON file.
    private func parseGeminiExtensionFile(at url: URL, sourceCLI: String, extensionDirName: String) async -> DetectedSkill? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let name = json["name"] as? String ?? extensionDirName
        let description = json["description"] as? String ?? "Gemini extension"
        let id = "\(sourceCLI)-\(extensionDirName)"

        return DetectedSkill(
            id: id,
            name: name.capitalized,
            description: description,
            icon: DetectedSkill.iconFor(name: name),
            sourceCLI: sourceCLI,
            filePath: url,
            isEnabled: true
        )
    }

    /// Parse a skill markdown file with YAML frontmatter.
    /// - Parameters:
    ///   - url: Path to the SKILL.md or *.md file
    ///   - sourceCLI: The CLI this skill belongs to
    ///   - skillDirName: For SKILL.md format, the parent directory name (used as ID). Nil for direct .md files.
    private func parseSkillFile(at url: URL, sourceCLI: String, skillDirName: String?) async -> DetectedSkill? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        // Use directory name if provided (SKILL.md format), otherwise use filename
        let skillId = skillDirName ?? url.deletingPathExtension().lastPathComponent
        let id = "\(sourceCLI)-\(skillId)"

        // Check for YAML frontmatter (starts with ---)
        guard content.hasPrefix("---") else {
            // If no frontmatter, use skillId as name
            return DetectedSkill(
                id: id,
                name: skillId.replacingOccurrences(of: "-", with: " ").capitalized,
                description: "Skill from \(sourceCLI)",
                icon: DetectedSkill.iconFor(name: skillId),
                sourceCLI: sourceCLI,
                filePath: url,
                isEnabled: true
            )
        }

        // Find end of frontmatter
        let lines = content.components(separatedBy: .newlines)
        var frontmatterEnd = -1
        for (index, line) in lines.enumerated() {
            if index > 0 && line == "---" {
                frontmatterEnd = index
                break
            }
        }

        guard frontmatterEnd > 0 else {
            // Frontmatter not closed, use skillId as name
            return DetectedSkill(
                id: id,
                name: skillId.replacingOccurrences(of: "-", with: " ").capitalized,
                description: "Skill from \(sourceCLI)",
                icon: DetectedSkill.iconFor(name: skillId),
                sourceCLI: sourceCLI,
                filePath: url,
                isEnabled: true
            )
        }

        // Parse YAML frontmatter (simple key: value parsing)
        let frontmatterLines = Array(lines[1..<frontmatterEnd])
        var frontmatter: [String: String] = [:]

        for line in frontmatterLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                frontmatter[key] = value
            }
        }

        // Extract skill properties (prefer frontmatter name, fallback to skillId)
        let name = frontmatter["name"] ?? skillId.replacingOccurrences(of: "-", with: " ")
        let description = frontmatter["description"] ?? "Skill from \(sourceCLI)"

        return DetectedSkill(
            id: id,
            name: name.capitalized,
            description: description,
            icon: DetectedSkill.iconFor(name: name),
            sourceCLI: sourceCLI,
            filePath: url,
            isEnabled: true
        )
    }

    /// Toggle a skill's enabled state.
    public func toggleSkill(id: String) {
        if let index = detectedSkills.firstIndex(where: { $0.id == id }) {
            detectedSkills[index].isEnabled.toggle()
            // Update selectedSkills to reflect enabled state
            if detectedSkills[index].isEnabled {
                selectedSkills.insert(id)
            } else {
                selectedSkills.remove(id)
            }
        }
    }

    /// Enable all detected skills.
    public func enableAllSkills() {
        for index in detectedSkills.indices {
            detectedSkills[index].isEnabled = true
        }
        selectedSkills = Set(detectedSkills.map { $0.id })
    }

    /// Disable all detected skills.
    public func disableAllSkills() {
        for index in detectedSkills.indices {
            detectedSkills[index].isEnabled = false
        }
        selectedSkills = []
    }

    /// Reset skill detection state.
    public func resetSkillDetection() {
        skillScanState = .idle
        detectedSkills = []
        selectedSkills = []
    }
}

// MARK: - Environment Support

extension EnvironmentValues {
    @Entry public var onboardingViewModel: OnboardingViewModel = OnboardingViewModel()
}
