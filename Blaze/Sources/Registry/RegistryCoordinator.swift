import Foundation
import os.log

// MARK: - Registry Coordinator

/// Central coordinator for registry operations: fetching, caching, and installing items.
///
/// Orchestrates between cache, network fetcher, and installer components.
/// Published state drives SwiftUI views for skills, plugins, and agents browsing.
@MainActor
@Observable
public final class RegistryCoordinator {

    // MARK: - Type Aliases (resolve ambiguity with stub types)

    public typealias Skill = Blaze.SkillItem
    public typealias Plugin = Blaze.PluginItem
    public typealias Agent = Blaze.AgentItem

    // MARK: - Published State

    /// All available skills from the registry
    public private(set) var skills: [Skill] = []

    /// All available plugins from the registry
    public private(set) var plugins: [Plugin] = []

    /// All available agents from the registry
    public private(set) var agents: [Agent] = []

    /// Whether a load/refresh operation is in progress
    public private(set) var isLoading: Bool = false

    /// Last error encountered during load or install
    public private(set) var error: Error?

    /// Installation progress per item (itemId -> progress 0.0...1.0)
    public private(set) var installProgress: [String: Double] = [:]

    // MARK: - Dependencies

    @ObservationIgnored
    private let fetcher: RegistryFetcher

    @ObservationIgnored
    private let cache: RegistryCache

    @ObservationIgnored
    private let installer: RegistryInstaller

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.cogit0.Blaze", category: "RegistryCoordinator")

    // MARK: - Configuration

    /// How long before cached data is considered stale
    @ObservationIgnored
    private let cacheStaleInterval: TimeInterval

    // MARK: - Initialization

    /// Creates a new registry coordinator with dependencies.
    /// - Parameters:
    ///   - fetcher: Network fetcher for registry API
    ///   - cache: Local cache for registry data
    ///   - installer: Handles item installation to disk
    ///   - cacheStaleInterval: Seconds before cache is stale (default: 1 hour)
    init(
        fetcher: RegistryFetcher,
        cache: RegistryCache,
        installer: RegistryInstaller,
        cacheStaleInterval: TimeInterval = 3600
    ) {
        self.fetcher = fetcher
        self.cache = cache
        self.installer = installer
        self.cacheStaleInterval = cacheStaleInterval
    }

    // MARK: - Public API

    /// Loads registry data, using cache if fresh or fetching from network.
    ///
    /// Updates published arrays on success. Sets error on failure.
    public func loadRegistry() async {
        guard !isLoading else {
            logger.debug("Load already in progress, skipping")
            return
        }

        isLoading = true
        error = nil

        do {
            // Try cache first
            if let cached = await cache.load(), !isCacheStale(cached) {
                logger.debug("Using cached registry data")
                applyResponse(cached)
                isLoading = false
                return
            }

            // Cache miss or stale - fetch from network
            logger.debug("Fetching registry from network")
            let response = try await fetcher.fetchRegistry()

            // Update cache
            await cache.save(response)

            // Update published state
            applyResponse(response)
            logger.info("Registry loaded: \(self.skills.count) skills, \(self.plugins.count) plugins, \(self.agents.count) agents")

        } catch {
            logger.error("Failed to load registry: \(error.localizedDescription)")
            self.error = error

            // Try to use stale cache as fallback
            if let stale = await cache.load() {
                logger.warning("Using stale cache as fallback")
                applyResponse(stale)
            }
        }

        isLoading = false
    }

    /// Forces a refresh from network, ignoring cache.
    public func refresh() async {
        guard !isLoading else {
            logger.debug("Refresh skipped - load in progress")
            return
        }

        isLoading = true
        error = nil

        do {
            logger.debug("Force refreshing registry from network")
            let response = try await fetcher.fetchRegistry()

            await cache.save(response)
            applyResponse(response)
            logger.info("Registry refreshed: \(self.skills.count) skills, \(self.plugins.count) plugins, \(self.agents.count) agents")

        } catch {
            logger.error("Failed to refresh registry: \(error.localizedDescription)")
            self.error = error
        }

        isLoading = false
    }

    /// Installs a skill from the registry.
    /// - Parameter skill: The skill to install
    /// - Parameter cli: Target CLI (default: "claude")
    /// - Throws: Installation errors
    public func install(skill: Skill, cli: String = "claude") async throws {
        logger.info("Installing skill: \(skill.name)")
        installProgress[skill.id] = 0.0

        do {
            try await installer.install(
                skill: skill,
                cli: cli,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.installProgress[skill.id] = progress
                    }
                }
            )
            installProgress[skill.id] = 1.0
            logger.info("Skill installed: \(skill.name)")
        } catch {
            installProgress.removeValue(forKey: skill.id)
            logger.error("Failed to install skill \(skill.name): \(error.localizedDescription)")
            throw error
        }
    }

    /// Installs a plugin from the registry.
    /// - Parameter plugin: The plugin to install
    /// - Parameter cli: Target CLI (default: plugin's forCLI)
    /// - Throws: Installation errors
    public func install(plugin: Plugin, cli: String? = nil) async throws {
        logger.info("Installing plugin: \(plugin.name)")
        installProgress[plugin.id] = 0.0

        do {
            try await installer.install(
                plugin: plugin,
                cli: cli,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.installProgress[plugin.id] = progress
                    }
                }
            )
            installProgress[plugin.id] = 1.0
            logger.info("Plugin installed: \(plugin.name)")
        } catch {
            installProgress.removeValue(forKey: plugin.id)
            logger.error("Failed to install plugin \(plugin.name): \(error.localizedDescription)")
            throw error
        }
    }

    /// Installs an agent from the registry.
    /// - Parameter agent: The agent to install
    /// - Parameter cli: Target CLI (default: "claude")
    /// - Throws: Installation errors
    public func install(agent: Agent, cli: String = "claude") async throws {
        logger.info("Installing agent: \(agent.name)")
        installProgress[agent.id] = 0.0

        do {
            try await installer.install(
                agent: agent,
                cli: cli,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.installProgress[agent.id] = progress
                    }
                }
            )
            installProgress[agent.id] = 1.0
            logger.info("Agent installed: \(agent.name)")
        } catch {
            installProgress.removeValue(forKey: agent.id)
            logger.error("Failed to install agent \(agent.name): \(error.localizedDescription)")
            throw error
        }
    }

    /// Clears the current error state.
    public func clearError() {
        error = nil
    }

    // MARK: - Private Helpers

    private func applyResponse(_ response: RegistryResponse) {
        skills = response.skills
        plugins = response.plugins
        agents = response.agents
    }

    private func isCacheStale(_ response: RegistryResponse) -> Bool {
        let age = Date().timeIntervalSince(response.lastUpdated)
        return age > cacheStaleInterval
    }
}

// MARK: - Registry Cache Protocol

/// Protocol for caching registry data locally.
/// Implementations should handle disk persistence.
public protocol RegistryCache: Sendable {
    /// Load cached registry data, if available.
    func load() async -> RegistryResponse?

    /// Save registry data to cache.
    func save(_ response: RegistryResponse) async

    /// Clear all cached data.
    func clear() async
}
