# E005: Session Creation UX + Onboarding + Multi-CLI Epic

**Version**: 2.0
**Created**: 2026-01-11
**Last Updated**: 2026-01-11
**Schema Compliance**: v2

## Executive Summary

This epic transforms Blaze from a Claude-focused harness into a **universal multi-CLI orchestrator** supporting Claude Code, OpenAI Codex, Gemini CLI, and emerging tools (Aider, OpenCode, Amp). Key capabilities:

1. **Multi-provider session creation** with model/provider selection per worktree
2. **One-click CLI installation** with dependency management
3. **Plugin/skill/agent marketplaces** via remote registries
4. **Provider-segregated hooks** for concurrent multi-CLI workflows
5. **Gantt-style hook visualization** for debugging and understanding
6. **Codex app-server integration** for advanced deployment scenarios
7. **7-screen onboarding wizard** with dynamic recommendations

---

## Feature Index

| ID | Feature | Atoms | Status | Effort |
|----|---------|-------|--------|--------|
| F001 | Enhanced Session Creation Dialog | 8 | Planned | Medium |
| F002 | Sidebar Enhancements | 4 | Planned | Small |
| F003 | Onboarding + Tutorial | 18 | Planned | Large |
| F004 | Multi-CLI Hooks Support | 9 | Planned | Large |
| F005 | CLI Detection & Installation | 6 | NEW | Medium |
| F006 | Plugin/Skill/Agent Registries | 8 | NEW | Large |
| F007 | Hooks Visualization (Gantt) | 7 | NEW | Large |
| F008 | Codex App-Server Integration | 5 | NEW | Medium |
| F009 | Advanced Hooks Builder | 14 | NEW | Large |

**Total Atoms**: 79
**Estimated Effort**: 8-10 weeks

---

## CLI Ecosystem Reference

### Supported CLIs

| CLI | Vendor | Install Command | Binary | Structured Output | Hooks? |
|-----|--------|-----------------|--------|-------------------|--------|
| **Claude Code** | Anthropic | `npm i -g @anthropic-ai/claude-code` | `claude` | `--output-format stream-json` | Yes (12 events) |
| **Codex CLI** | OpenAI | `npm i -g @openai/codex` | `codex` | `--output-schema` + JSONL | Limited (notify only) |
| **Gemini CLI** | Google | `npm i -g @google/gemini-cli` | `gemini` | `--output-format stream-json` | Yes (11 events) |
| **Aider** | Community | `pip install aider-chat` | `aider` | Text-based | No |
| **OpenCode** | Anomaly | `brew install anomalyco/tap/opencode` | `opencode` | JSON | Limited |
| **Amp** | Sourcegraph | `npm i -g @sourcegraph/amp` | `amp` | Stream-JSON | Limited |
| **Goose** | Block/LF | `curl -fsSL ... \| bash` | `goose` | Text | No |
| **Cline** | Community | `npm i cline` | `cline` | JSON/text | No |
| **Cursor** | Cursor Inc | `brew install --cask cursor` | `cursor` | Limited | No |

### Detection Commands

```bash
# Find CLI in PATH
which claude && claude --version
which codex && codex --version
which gemini && gemini --version
which aider && aider --version

# Check dependencies
node --version  # For npm-based CLIs
python3 --version  # For Aider
rustc --version  # For some tools
brew --version  # For Homebrew CLIs
```

---

## Plugin Ecosystem Reference

### Claude Code Plugins

| Plugin | Description | Install | Stars |
|--------|-------------|---------|-------|
| **Gastown** | Multi-agent workspace orchestrator | `npm i -g @gastown/cli` | 2k |
| **Continuous-Claude-v2** | Context ledger for session continuity | Git clone + config | 800 |
| **Braintrust Plugin** | Observability/tracing integration | `npm i -g @braintrustdata/claude` | 400 |
| **claude-plugins.dev** | Community plugin registry (243+ plugins) | Browse + install | N/A |

### Gemini CLI Extensions

| Extension | Description | Install | Source |
|-----------|-------------|---------|--------|
| **Figma Extension** | Design file integration | `gemini ext install figma` | Google |
| **Stripe Extension** | Payment API integration | `gemini ext install stripe` | Google |
| **34+ Official** | Growing ecosystem | `gemini ext list` | gemini-cli-extensions |

### Codex CLI Extensions

| Extension | Description | Install | Notes |
|-----------|-------------|---------|-------|
| **MCP Servers** | Model Context Protocol | Config in `~/.codex/config.toml` | Growing |
| **AGENTS.md** | Agent prompt injection | File-based | Standard |

---

## Hook Schema Reference

### Claude Code Events (12 total)

| Event | Description | Matchers | Can Block? |
|-------|-------------|----------|------------|
| `SessionStart` | Session begins | `startup`, `resume`, `clear`, `compact` | No |
| `SessionEnd` | Session concludes | - | No |
| `UserPromptSubmit` | User submits prompt | - | Yes |
| `PreToolUse` | Before tool execution | Tool patterns | Yes |
| `PostToolUse` | After tool completion | Tool patterns | No |
| `Stop` | Main agent stopping | - | No |
| `SubagentStop` | Subagent finished | - | No |
| `PreCompact` | Before context compaction | - | No |
| `Notification` | Generic notification | - | No |
| `PermissionRequest` | Permission dialog (v2.1.0+) | - | Yes |

### Gemini CLI Events (11 total)

| Event | Description | Matchers | Can Block? |
|-------|-------------|----------|------------|
| `BeforeTool` | Before tool execution | Tool patterns | Yes |
| `AfterTool` | After tool completion | Tool patterns | No |
| `BeforeAgent` | Pre-planning after prompt | - | Yes |
| `AfterAgent` | Agent loop completion | - | No |
| `BeforeModel` | Before LLM request | - | Yes |
| `AfterModel` | After LLM response | - | No |
| `BeforeToolSelection` | Pre-tool filtering | - | Yes |
| `SessionStart` | Session initialization | `startup`, `resume`, `clear` | No |
| `SessionEnd` | Session termination | `exit`, `clear`, `logout`, `other` | No |
| `PreCompress` | Before context compression | `manual`, `auto` | No |
| `Notification` | Permission notifications | `ToolPermission` | No |

### Codex CLI Events (Limited)

| Event | Description | Notes |
|-------|-------------|-------|
| `agent-turn-complete` | Turn completed | Notify only |
| `approval-requested` | Approval needed | Notify only |

**Note**: Codex CLI uses `notify` configuration, not hooks. Config: `~/.codex/config.toml` (TOML, not JSON).

### Tool Name Mapping

| Operation | Claude | Gemini | Codex |
|-----------|--------|--------|-------|
| Shell | `Bash` | `run_shell_command` | `shell` |
| File read | `Read` | `read_file` | `read_file` |
| File edit | `Edit` | `replace` | `apply_patch` |
| File write | `Write` | `write_file` | `write_file` |
| Search | `Grep` | `search_file_content` | `rg` |
| Glob | `Glob` | `glob` | `glob` |

---

## Codex App-Server vs Headless Comparison

### Architecture Comparison

| Aspect | Headless (`codex exec`) | App-Server (`codex app-server`) |
|--------|-------------------------|----------------------------------|
| **Process Model** | One process per task | Long-running daemon |
| **Communication** | stdin/stdout JSONL | JSON-RPC over stdio |
| **Session Resume** | `codex exec resume <id>` | Persistent by default |
| **Memory Footprint** | Lower (per-task) | Higher (continuous) |

### Concurrent Multi-Agent Support

| Capability | Headless | App-Server |
|------------|----------|------------|
| **5+ parallel agents** | Yes (spawn multiple) | Yes (thread forking) |
| **Session isolation** | Process-level | Thread-level |
| **Resource sharing** | None | Shared context |

### Recommendation for Blaze

**MVP**: Use headless mode (`codex exec --json`) - matches existing Claude Code adapter pattern.

**Future**: Add app-server support for continuous editing workflows requiring persistent state.

```bash
# Headless (recommended for MVP)
codex exec --json "implement feature X" --cd /path/to/worktree

# App-server (future)
codex app-server --port 8080
curl -X POST http://localhost:8080/exec -d '{"prompt": "..."}'
```

---

## F001: Enhanced Session Creation Dialog

### Overview

Enhance `NewSessionModal` with directory source options (Browse/Clone/Create), provider/model selection, and CLI validation.

### Atoms

#### A001-MODEL: Data Model Enhancements

**Problem**: Session model lacks provider/model association needed for multi-CLI support.

**Scope In**:
- Add `AIProvider`, `AIModel`, `AIModelRegistry`, `DirectorySource` enums
- Extend `Session` with `provider` and `modelId` fields
- Add migration v7 for new columns

**Scope Out**:
- Runtime model switching (defer to F009)
- Model cost estimation

**Files to Modify**:
- `Blaze/Sources/Core/Models.swift`
- `Blaze/Sources/Data/SessionStore.swift`
- `Blaze/Sources/Data/Migrations.swift`

**Full Implementation**:

```swift
// MARK: - Blaze/Sources/Core/AIProvider.swift

import Foundation

/// AI provider representing the vendor behind a CLI tool.
/// Maps 1:1 with EngineType but represents the business entity.
public enum AIProvider: String, Codable, CaseIterable, Sendable, Identifiable {
    case anthropic
    case openai
    case google
    case community  // For Aider, OpenCode, etc.

    public var id: String { rawValue }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .google: return "Google"
        case .community: return "Community"
        }
    }

    /// Brand color for UI theming (hex)
    public var brandColor: String {
        switch self {
        case .anthropic: return "#D97757"  // Anthropic orange
        case .openai: return "#10A37F"     // OpenAI green
        case .google: return "#4285F4"     // Google blue
        case .community: return "#8B5CF6"  // Purple for community
        }
    }

    /// Asset catalog image name for vendor logo
    public var logoAssetName: String {
        switch self {
        case .anthropic: return "logo-anthropic"
        case .openai: return "logo-openai"
        case .google: return "logo-google"
        case .community: return "logo-community"
        }
    }

    /// SF Symbol fallback if logo asset missing
    public var fallbackSymbol: String {
        switch self {
        case .anthropic: return "brain.head.profile"
        case .openai: return "sparkles"
        case .google: return "g.circle.fill"
        case .community: return "person.3.fill"
        }
    }

    /// Map to EngineType for adapter routing
    public var engineType: EngineType {
        switch self {
        case .anthropic: return .claude
        case .openai: return .codex
        case .google: return .gemini
        case .community: return .claude  // Default to Claude adapter pattern
        }
    }

    /// CLI binary name
    public var cliBinary: String {
        switch self {
        case .anthropic: return "claude"
        case .openai: return "codex"
        case .google: return "gemini"
        case .community: return "aider"  // Default community tool
        }
    }

    /// Whether this provider supports the hooks system
    public var supportsHooks: Bool {
        switch self {
        case .anthropic, .google: return true
        case .openai, .community: return false
        }
    }

    /// Number of hook events supported
    public var hookEventCount: Int {
        switch self {
        case .anthropic: return 12
        case .google: return 11
        case .openai, .community: return 0
        }
    }
}

// MARK: - Blaze/Sources/Core/ModelTier.swift

/// Performance tier classification for AI models
public enum ModelTier: String, Codable, CaseIterable, Sendable {
    case flagship   // Most capable, highest cost
    case balanced   // Good balance of capability and cost
    case fast       // Fastest response, lower capability

    public var displayName: String {
        switch self {
        case .flagship: return "Flagship"
        case .balanced: return "Balanced"
        case .fast: return "Fast"
        }
    }

    public var icon: String {
        switch self {
        case .flagship: return "star.fill"
        case .balanced: return "scale.3d"
        case .fast: return "bolt.fill"
        }
    }

    public var badgeColor: String {
        switch self {
        case .flagship: return "#FFD700"  // Gold
        case .balanced: return "#C0C0C0"  // Silver
        case .fast: return "#CD7F32"      // Bronze
        }
    }

    /// Relative cost multiplier (1.0 = baseline)
    public var costMultiplier: Double {
        switch self {
        case .flagship: return 3.0
        case .balanced: return 1.0
        case .fast: return 0.3
        }
    }
}

// MARK: - Blaze/Sources/Core/AIModel.swift

/// Represents a specific AI model available from a provider
public struct AIModel: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let provider: AIProvider
    public let tier: ModelTier
    public let contextWindow: Int
    public let isDefault: Bool
    public let releaseDate: Date?
    public let deprecationDate: Date?

    /// Input token cost per million tokens (USD)
    public let inputCostPerMillion: Decimal?

    /// Output token cost per million tokens (USD)
    public let outputCostPerMillion: Decimal?

    /// Maximum output tokens
    public let maxOutputTokens: Int?

    /// Whether model supports vision/images
    public let supportsVision: Bool

    /// Whether model supports tool use
    public let supportsToolUse: Bool

    /// Model-specific CLI flags
    public let cliFlags: [String]

    public init(
        id: String,
        name: String,
        provider: AIProvider,
        tier: ModelTier,
        contextWindow: Int,
        isDefault: Bool = false,
        releaseDate: Date? = nil,
        deprecationDate: Date? = nil,
        inputCostPerMillion: Decimal? = nil,
        outputCostPerMillion: Decimal? = nil,
        maxOutputTokens: Int? = nil,
        supportsVision: Bool = true,
        supportsToolUse: Bool = true,
        cliFlags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.tier = tier
        self.contextWindow = contextWindow
        self.isDefault = isDefault
        self.releaseDate = releaseDate
        self.deprecationDate = deprecationDate
        self.inputCostPerMillion = inputCostPerMillion
        self.outputCostPerMillion = outputCostPerMillion
        self.maxOutputTokens = maxOutputTokens
        self.supportsVision = supportsVision
        self.supportsToolUse = supportsToolUse
        self.cliFlags = cliFlags
    }

    /// Human-readable context window (e.g., "200K")
    public var contextWindowFormatted: String {
        if contextWindow >= 1_000_000 {
            return "\(contextWindow / 1_000_000)M"
        } else if contextWindow >= 1_000 {
            return "\(contextWindow / 1_000)K"
        }
        return "\(contextWindow)"
    }

    /// Whether model is deprecated
    public var isDeprecated: Bool {
        guard let deprecation = deprecationDate else { return false }
        return Date() > deprecation
    }

    /// Full display name with provider
    public var fullDisplayName: String {
        "\(provider.displayName) \(name)"
    }
}

// MARK: - Blaze/Sources/Core/AIModelRegistry.swift

/// Static registry of available AI models per provider.
/// This is the source of truth for model metadata until we implement
/// dynamic registry fetching in F006.
public enum AIModelRegistry {

    // MARK: - Anthropic Models

    public static let anthropic: [AIModel] = [
        AIModel(
            id: "claude-opus-4-5-20251101",
            name: "Opus 4.5",
            provider: .anthropic,
            tier: .flagship,
            contextWindow: 200_000,
            isDefault: false,
            inputCostPerMillion: 15.00,
            outputCostPerMillion: 75.00,
            maxOutputTokens: 32_000,
            cliFlags: ["--model", "claude-opus-4-5-20251101"]
        ),
        AIModel(
            id: "claude-sonnet-4-5-20251101",
            name: "Sonnet 4.5",
            provider: .anthropic,
            tier: .balanced,
            contextWindow: 200_000,
            isDefault: true,
            inputCostPerMillion: 3.00,
            outputCostPerMillion: 15.00,
            maxOutputTokens: 16_000,
            cliFlags: ["--model", "claude-sonnet-4-5-20251101"]
        ),
        AIModel(
            id: "claude-haiku-4-5-20251101",
            name: "Haiku 4.5",
            provider: .anthropic,
            tier: .fast,
            contextWindow: 200_000,
            isDefault: false,
            inputCostPerMillion: 0.80,
            outputCostPerMillion: 4.00,
            maxOutputTokens: 8_000,
            cliFlags: ["--model", "claude-haiku-4-5-20251101"]
        )
    ]

    // MARK: - OpenAI Models

    public static let openai: [AIModel] = [
        AIModel(
            id: "codex-5.2-xhigh",
            name: "Codex 5.2 X-High",
            provider: .openai,
            tier: .flagship,
            contextWindow: 192_000,
            isDefault: false,
            inputCostPerMillion: 10.00,
            outputCostPerMillion: 30.00,
            maxOutputTokens: 32_000,
            cliFlags: ["--model", "codex-5.2-xhigh"]
        ),
        AIModel(
            id: "codex-5.2-high",
            name: "Codex 5.2 High",
            provider: .openai,
            tier: .balanced,
            contextWindow: 192_000,
            isDefault: true,
            inputCostPerMillion: 2.50,
            outputCostPerMillion: 10.00,
            maxOutputTokens: 16_000,
            cliFlags: ["--model", "codex-5.2-high"]
        ),
        AIModel(
            id: "codex-5.2-medium",
            name: "Codex 5.2 Medium",
            provider: .openai,
            tier: .fast,
            contextWindow: 192_000,
            isDefault: false,
            inputCostPerMillion: 0.50,
            outputCostPerMillion: 2.00,
            maxOutputTokens: 8_000,
            cliFlags: ["--model", "codex-5.2-medium"]
        )
    ]

    // MARK: - Google Models

    public static let google: [AIModel] = [
        AIModel(
            id: "gemini-3.0-pro",
            name: "Gemini 3.0 Pro",
            provider: .google,
            tier: .flagship,
            contextWindow: 1_000_000,
            isDefault: true,
            inputCostPerMillion: 1.25,
            outputCostPerMillion: 5.00,
            maxOutputTokens: 65_536,
            cliFlags: ["--model", "gemini-3.0-pro"]
        ),
        AIModel(
            id: "gemini-3.0-flash",
            name: "Gemini 3.0 Flash",
            provider: .google,
            tier: .fast,
            contextWindow: 1_000_000,
            isDefault: false,
            inputCostPerMillion: 0.075,
            outputCostPerMillion: 0.30,
            maxOutputTokens: 32_768,
            cliFlags: ["--model", "gemini-3.0-flash"]
        ),
        AIModel(
            id: "gemini-3.0-flash-thinking",
            name: "Gemini 3.0 Flash Thinking",
            provider: .google,
            tier: .balanced,
            contextWindow: 1_000_000,
            isDefault: false,
            inputCostPerMillion: 0.15,
            outputCostPerMillion: 0.60,
            maxOutputTokens: 65_536,
            supportsVision: true,
            cliFlags: ["--model", "gemini-3.0-flash-thinking"]
        )
    ]

    // MARK: - Lookup Methods

    /// All models across all providers
    public static var all: [AIModel] {
        anthropic + openai + google
    }

    /// Get models for a specific provider
    public static func models(for provider: AIProvider) -> [AIModel] {
        switch provider {
        case .anthropic: return anthropic
        case .openai: return openai
        case .google: return google
        case .community: return []
        }
    }

    /// Get default model for a provider
    public static func defaultModel(for provider: AIProvider) -> AIModel? {
        models(for: provider).first { $0.isDefault }
    }

    /// Find model by ID
    public static func model(byId id: String) -> AIModel? {
        all.first { $0.id == id }
    }

    /// Find models by tier
    public static func models(byTier tier: ModelTier) -> [AIModel] {
        all.filter { $0.tier == tier }
    }

    /// Get provider from model ID
    public static func provider(forModelId id: String) -> AIProvider? {
        model(byId: id)?.provider
    }
}

// MARK: - Blaze/Sources/Core/DirectorySource.swift

/// How the user specifies the project directory for a new session
public enum DirectorySource: String, Codable, CaseIterable, Sendable {
    case browse   // Select existing directory via NSOpenPanel
    case clone    // Clone from Git repository URL
    case create   // Create new empty project directory

    public var displayName: String {
        switch self {
        case .browse: return "Browse"
        case .clone: return "Clone"
        case .create: return "Create"
        }
    }

    public var icon: String {
        switch self {
        case .browse: return "folder"
        case .clone: return "arrow.down.circle"
        case .create: return "plus.rectangle.on.folder"
        }
    }

    public var description: String {
        switch self {
        case .browse: return "Select an existing project folder"
        case .clone: return "Clone a Git repository"
        case .create: return "Create a new project"
        }
    }
}
```

**Database Schema (Migration v7)**:

```sql
-- Blaze/Sources/Data/Migrations/v7_add_provider_model.sql

-- Add provider and model columns to sessions table
ALTER TABLE sessions ADD COLUMN provider TEXT NOT NULL DEFAULT 'anthropic';
ALTER TABLE sessions ADD COLUMN model_id TEXT NOT NULL DEFAULT 'claude-sonnet-4-5-20251101';

-- Add index for filtering by provider
CREATE INDEX idx_sessions_provider ON sessions(provider);

-- Add constraint to ensure valid provider values
-- Note: SQLite doesn't support CHECK constraints well, validate in Swift
```

**Swift Migration Code**:

```swift
// Blaze/Sources/Data/Migrations.swift (additions)

extension DatabaseMigrator {
    static func registerV7Migration(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v7_add_provider_model") { db in
            // Add provider column with default
            try db.alter(table: "sessions") { t in
                t.add(column: "provider", .text)
                    .notNull()
                    .defaults(to: "anthropic")
            }

            // Add model_id column with default
            try db.alter(table: "sessions") { t in
                t.add(column: "model_id", .text)
                    .notNull()
                    .defaults(to: "claude-sonnet-4-5-20251101")
            }

            // Create index
            try db.create(
                index: "idx_sessions_provider",
                on: "sessions",
                columns: ["provider"]
            )

            // Backfill existing sessions based on engine_type
            try db.execute(sql: """
                UPDATE sessions
                SET provider = CASE engine_type
                    WHEN 'Claude Code' THEN 'anthropic'
                    WHEN 'Gemini CLI' THEN 'google'
                    WHEN 'Codex CLI' THEN 'openai'
                    ELSE 'anthropic'
                END
                WHERE provider = 'anthropic'
            """)
        }
    }
}
```

**Session Model Updates**:

```swift
// Blaze/Sources/Core/Models.swift (Session struct additions)

extension Session {
    /// AI provider for this session
    var provider: AIProvider {
        get { _provider ?? .anthropic }
        set { _provider = newValue }
    }
    private var _provider: AIProvider?

    /// Selected model ID
    var modelId: String {
        get { _modelId ?? "claude-sonnet-4-5-20251101" }
        set { _modelId = newValue }
    }
    private var _modelId: String?

    /// Resolved AIModel from registry
    var model: AIModel? {
        AIModelRegistry.model(byId: modelId)
    }

    /// CLI flags for the selected model
    var modelCliFlags: [String] {
        model?.cliFlags ?? []
    }
}
```

**Test Suite**:

```swift
// Blaze/Tests/Core/AIProviderTests.swift

import XCTest
@testable import Blaze

final class AIProviderTests: XCTestCase {

    // MARK: - Provider Tests

    func testProviderDisplayNames() {
        XCTAssertEqual(AIProvider.anthropic.displayName, "Anthropic")
        XCTAssertEqual(AIProvider.openai.displayName, "OpenAI")
        XCTAssertEqual(AIProvider.google.displayName, "Google")
    }

    func testProviderEngineTypeMapping() {
        XCTAssertEqual(AIProvider.anthropic.engineType, .claude)
        XCTAssertEqual(AIProvider.openai.engineType, .codex)
        XCTAssertEqual(AIProvider.google.engineType, .gemini)
    }

    func testProviderHooksSupport() {
        XCTAssertTrue(AIProvider.anthropic.supportsHooks)
        XCTAssertTrue(AIProvider.google.supportsHooks)
        XCTAssertFalse(AIProvider.openai.supportsHooks)
    }

    func testProviderCodable() throws {
        let provider = AIProvider.anthropic
        let encoded = try JSONEncoder().encode(provider)
        let decoded = try JSONDecoder().decode(AIProvider.self, from: encoded)
        XCTAssertEqual(provider, decoded)
    }

    // MARK: - Model Registry Tests

    func testRegistryReturnsModelsForProvider() {
        let anthropicModels = AIModelRegistry.models(for: .anthropic)
        XCTAssertEqual(anthropicModels.count, 3)
        XCTAssertTrue(anthropicModels.allSatisfy { $0.provider == .anthropic })

        let googleModels = AIModelRegistry.models(for: .google)
        XCTAssertEqual(googleModels.count, 3)
        XCTAssertTrue(googleModels.allSatisfy { $0.provider == .google })
    }

    func testRegistryDefaultModel() {
        let defaultAnthropic = AIModelRegistry.defaultModel(for: .anthropic)
        XCTAssertNotNil(defaultAnthropic)
        XCTAssertEqual(defaultAnthropic?.id, "claude-sonnet-4-5-20251101")
        XCTAssertTrue(defaultAnthropic?.isDefault == true)

        let defaultGoogle = AIModelRegistry.defaultModel(for: .google)
        XCTAssertNotNil(defaultGoogle)
        XCTAssertEqual(defaultGoogle?.id, "gemini-3.0-pro")
    }

    func testRegistryLookupById() {
        let model = AIModelRegistry.model(byId: "claude-opus-4-5-20251101")
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.name, "Opus 4.5")
        XCTAssertEqual(model?.tier, .flagship)

        let notFound = AIModelRegistry.model(byId: "nonexistent-model")
        XCTAssertNil(notFound)
    }

    func testRegistryModelsByTier() {
        let flagshipModels = AIModelRegistry.models(byTier: .flagship)
        XCTAssertEqual(flagshipModels.count, 3)  // One per provider
        XCTAssertTrue(flagshipModels.allSatisfy { $0.tier == .flagship })
    }

    // MARK: - Model Tests

    func testModelContextWindowFormatting() {
        let largeContext = AIModel(
            id: "test", name: "Test", provider: .google,
            tier: .flagship, contextWindow: 1_000_000, isDefault: false
        )
        XCTAssertEqual(largeContext.contextWindowFormatted, "1M")

        let mediumContext = AIModel(
            id: "test", name: "Test", provider: .anthropic,
            tier: .balanced, contextWindow: 200_000, isDefault: false
        )
        XCTAssertEqual(mediumContext.contextWindowFormatted, "200K")
    }

    func testModelDeprecation() {
        let activeModel = AIModel(
            id: "test", name: "Test", provider: .anthropic,
            tier: .balanced, contextWindow: 200_000, isDefault: false,
            deprecationDate: Date().addingTimeInterval(86400 * 30)  // 30 days from now
        )
        XCTAssertFalse(activeModel.isDeprecated)

        let deprecatedModel = AIModel(
            id: "test", name: "Test", provider: .anthropic,
            tier: .balanced, contextWindow: 200_000, isDefault: false,
            deprecationDate: Date().addingTimeInterval(-86400)  // Yesterday
        )
        XCTAssertTrue(deprecatedModel.isDeprecated)
    }

    func testModelCodable() throws {
        let model = AIModelRegistry.anthropic[0]
        let encoded = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(AIModel.self, from: encoded)
        XCTAssertEqual(model.id, decoded.id)
        XCTAssertEqual(model.provider, decoded.provider)
        XCTAssertEqual(model.tier, decoded.tier)
    }

    // MARK: - Session Provider Tests

    func testSessionProviderDefault() {
        let session = Session(name: "Test")
        XCTAssertEqual(session.provider, .anthropic)
        XCTAssertEqual(session.modelId, "claude-sonnet-4-5-20251101")
    }

    func testSessionModelResolution() {
        var session = Session(name: "Test")
        session.modelId = "gemini-3.0-pro"

        XCTAssertNotNil(session.model)
        XCTAssertEqual(session.model?.provider, .google)
        XCTAssertEqual(session.model?.tier, .flagship)
    }
}

// Blaze/Tests/Data/MigrationV7Tests.swift

import XCTest
import GRDB
@testable import Blaze

final class MigrationV7Tests: XCTestCase {

    var dbQueue: DatabaseQueue!

    override func setUp() async throws {
        dbQueue = try DatabaseQueue()
        // Apply migrations v1-v6 first
        var migrator = DatabaseMigrator()
        DatabaseMigrator.registerV1toV6Migrations(&migrator)
        try migrator.migrate(dbQueue)
    }

    func testMigrationAddsProviderColumn() throws {
        // Insert a session before migration
        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO sessions (id, name, created_at, updated_at, engine_type)
                VALUES ('test-id', 'Test Session', datetime('now'), datetime('now'), 'Claude Code')
            """)
        }

        // Apply v7 migration
        var migrator = DatabaseMigrator()
        DatabaseMigrator.registerV7Migration(&migrator)
        try migrator.migrate(dbQueue)

        // Verify columns exist and have correct defaults
        try dbQueue.read { db in
            let row = try Row.fetchOne(db, sql: "SELECT provider, model_id FROM sessions WHERE id = 'test-id'")
            XCTAssertEqual(row?["provider"] as? String, "anthropic")
            XCTAssertEqual(row?["model_id"] as? String, "claude-sonnet-4-5-20251101")
        }
    }

    func testMigrationBackfillsFromEngineType() throws {
        // Insert sessions with different engine types
        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO sessions (id, name, created_at, updated_at, engine_type)
                VALUES
                    ('claude-session', 'Claude', datetime('now'), datetime('now'), 'Claude Code'),
                    ('gemini-session', 'Gemini', datetime('now'), datetime('now'), 'Gemini CLI'),
                    ('codex-session', 'Codex', datetime('now'), datetime('now'), 'Codex CLI')
            """)
        }

        // Apply v7 migration
        var migrator = DatabaseMigrator()
        DatabaseMigrator.registerV7Migration(&migrator)
        try migrator.migrate(dbQueue)

        // Verify backfill
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT id, provider FROM sessions ORDER BY id")
            XCTAssertEqual(rows[0]["provider"] as? String, "anthropic")
            XCTAssertEqual(rows[1]["provider"] as? String, "openai")
            XCTAssertEqual(rows[2]["provider"] as? String, "google")
        }
    }

    func testMigrationCreatesIndex() throws {
        var migrator = DatabaseMigrator()
        DatabaseMigrator.registerV7Migration(&migrator)
        try migrator.migrate(dbQueue)

        try dbQueue.read { db in
            let indexes = try db.indexes(on: "sessions")
            XCTAssertTrue(indexes.contains { $0.name == "idx_sessions_provider" })
        }
    }
}
```

**Functional Requirements**:
1. `AIProvider` enum maps to `EngineType` for adapter routing
2. `AIModel` stores all model metadata needed for display and API calls
3. `AIModelRegistry` provides static model lists (updateable in future releases)
4. `Session.provider` persists selected provider
5. `Session.modelId` persists selected model ID
6. **NEW**: Cost tracking per model for budget estimation
7. **NEW**: Deprecation date tracking for model lifecycle management
8. **NEW**: Vision and tool use capability flags per model
9. **NEW**: CLI flags stored per model for correct invocation

**Test Plan**:
- Unit: Model registry returns correct models per provider
- Unit: Session serialization round-trips provider/modelId
- Unit: Model deprecation detection works correctly
- Unit: Context window formatting handles M/K suffixes
- Integration: Migration v7 adds columns without data loss
- Integration: Migration v7 backfills provider from engine_type
- Integration: Migration v7 creates index

**Verification Steps**:
1. `swift build` compiles without errors
2. `swift test --filter AIProviderTests` passes
3. `swift test --filter MigrationV7Tests` passes
4. Create session → query DB → verify provider/modelId columns exist
5. Verify `idx_sessions_provider` index exists in SQLite

**Risk Register**:
- Risk: Migration breaks existing sessions
- Mitigation: Default provider to `.anthropic`, modelId to `claude-sonnet-4-5-20251101`
- Blast Radius: SessionStore, all session-dependent views
- Fallback: Revert migration, restore from backup

**Error Handling**:
```swift
enum AIProviderError: LocalizedError {
    case modelNotFound(id: String)
    case providerMismatch(expected: AIProvider, got: AIProvider)
    case unsupportedFeature(feature: String, provider: AIProvider)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let id):
            return "Model '\(id)' not found in registry"
        case .providerMismatch(let expected, let got):
            return "Expected provider \(expected.displayName) but got \(got.displayName)"
        case .unsupportedFeature(let feature, let provider):
            return "\(feature) is not supported by \(provider.displayName)"
        }
    }
}
```

---

#### A002-CLONE: Git Clone Support

**Problem**: Users can only browse existing directories; need to clone repos directly from session creation.

**Scope In**:
- Add `cloneRepository(url:destination:shallow:)` to `GitWorktreeManager`
- Support HTTPS and SSH URLs
- Optional shallow clone for faster setup
- Progress reporting

**Scope Out**:
- Git LFS support
- Submodule handling (defer)
- Authentication UI (use system git credentials)

**Files to Modify**:
- `Blaze/Sources/Core/GitWorktreeManager.swift`

**Implementation**:
```swift
extension GitWorktreeManager {
    /// Clone a repository to a destination directory
    func cloneRepository(
        url: String,
        destination: String,
        shallow: Bool = false,
        progress: @escaping (CloneProgress) -> Void
    ) async throws -> String {
        // Validate URL
        guard url.hasPrefix("https://") || url.hasPrefix("git@") else {
            throw GitError.invalidURL(url)
        }

        // Build command
        var args = ["clone"]
        if shallow { args.append("--depth=1") }
        args.append(contentsOf: ["--progress", url, destination])

        // Execute with progress parsing
        let result = try await runGitCommand(args, progressHandler: { line in
            if let parsed = parseCloneProgress(line) {
                progress(parsed)
            }
        })

        return destination
    }

    struct CloneProgress: Sendable {
        let phase: ClonePhase
        let percent: Int
        let message: String
    }

    enum ClonePhase: Sendable {
        case counting, compressing, receiving, resolving
    }
}
```

**Functional Requirements**:
1. Clone from HTTPS URL succeeds
2. Clone from SSH URL succeeds (using system ssh-agent)
3. Shallow clone creates valid repo
4. Progress callback fires during clone
5. Error on invalid URL or network failure

**Test Plan**:
- Unit: URL validation rejects malformed URLs
- Integration: Clone public GitHub repo (e.g., `https://github.com/anthropics/anthropic-cookbook`)
- Integration: Verify cloned repo is valid git repo

**Verification Steps**:
1. Launch app → New Session → Clone tab
2. Enter `https://github.com/anthropics/anthropic-cookbook`
3. Click Clone → verify progress bar updates
4. Verify directory created with `.git` folder

**Risk Register**:
- Risk: Network timeout on large repos
- Mitigation: 5-minute timeout, shallow clone option, cancel button
- Blast Radius: NewSessionModal, GitWorktreeManager
- Fallback: Remove clone feature, user clones externally

---

#### A003-DIRSRC: Directory Source UI

**Problem**: Current UI only has Browse; need segmented picker for Browse/Clone/Create.

**Scope In**:
- Add `DirectorySourcePicker` segmented control
- Conditional views for each source type
- `BrowseDirectoryView` (existing NSOpenPanel)
- `CloneRepositoryView` (URL input + progress)
- `CreateProjectView` (name input + git init toggle)

**Scope Out**:
- Template selection for Create
- Organization/team directory presets

**Files to Modify**:
- `Blaze/Sources/UI/NewSessionModal.swift`

**UI Structure**:
```
DirectorySourcePicker (Segmented)
├── [Browse] - Select existing directory
├── [Clone] - Pull from Git repository
└── [Create] - New empty project

When Browse selected:
  └── PathDisplay + [Browse...] button

When Clone selected:
  └── TextField: Repository URL
  └── TextField: Destination folder
  └── Checkbox: Shallow clone (faster)
  └── ProgressBar (during clone)

When Create selected:
  └── TextField: Project name
  └── PathDisplay: Parent folder + [Change...]
  └── Checkbox: Initialize git repository
```

**Functional Requirements**:
1. Segmented control switches views without losing state
2. Browse opens NSOpenPanel for directory selection
3. Clone shows URL input with validation indicator
4. Create shows name input with auto-generated path
5. Selected source persists during provider/model selection

**Test Plan**:
- UI: Segment switching shows correct views
- UI: Clone URL validation shows red/green indicator
- UI: Create shows computed path as user types name

**Verification Steps**:
1. Open New Session modal
2. Click each segment → verify correct view appears
3. Enter clone URL → verify validation indicator
4. Enter project name → verify path updates

---

#### A004-PROVMOD: Provider/Model Selector

**Problem**: No way to select which CLI/model to use for a session.

**Scope In**:
- Provider picker (segmented: Anthropic | OpenAI | Google)
- Model list (radio buttons with tier badges)
- CLI availability indicator (installed/not installed)

**Scope Out**:
- Custom model endpoints
- API key management (use system keychain)

**Files to Modify**:
- `Blaze/Sources/UI/NewSessionModal.swift`

**UI Structure**:
```
ProviderModelSection
├── Provider Picker (Segmented)
│   ├── [Anthropic] - Claude models
│   ├── [OpenAI] - Codex models
│   └── [Google] - Gemini models
│
└── Model List (filtered by provider)
    ├── [●] Claude Opus 4.5 [flagship] - Most capable
    ├── [○] Claude Sonnet 4.5 [balanced] - Balanced (default)
    └── [○] Claude Haiku 4.5 [fast] - Fastest

CLI Status Badge:
├── ✓ Installed (green) - CLI detected in PATH
└── ⚠ Not installed (yellow) - Click to install
```

**Functional Requirements**:
1. Provider selection updates model list
2. Default model auto-selected per provider
3. CLI status checked asynchronously on provider change
4. "Not installed" badge links to F005 install flow
5. Selection persists in `@State` during modal session

**Test Plan**:
- UI: Provider change updates model list correctly
- UI: Default model highlighted per provider
- Integration: CLI detection shows correct status

**Verification Steps**:
1. Open New Session → select each provider
2. Verify model list updates per provider
3. Verify CLI status badge accuracy

---

#### A005-CREATE: Session Creation Flow Update

**Problem**: Need to wire new directory source and provider options into session creation.

**Files to Modify**:
- `Blaze/Sources/UI/NewSessionModal.swift`
- `Blaze/Sources/App/BlazeApp.swift`

**Implementation Updates**:
```swift
// NewSessionModal
struct NewSessionModal: View {
    @State private var directorySource: DirectorySource = .browse
    @State private var selectedProvider: AIProvider = .anthropic
    @State private var selectedModelId: String = "claude-sonnet-4.5"
    @State private var repoURL: String = ""
    @State private var projectName: String = ""
    @State private var initGit: Bool = true

    func createSession() {
        switch directorySource {
        case .browse:
            // Use existing selectedDirectory
            createSessionWithDirectory(selectedDirectory)
        case .clone:
            Task {
                let path = try await gitManager.cloneRepository(url: repoURL, ...)
                createSessionWithDirectory(path)
            }
        case .create:
            let path = createNewProject(name: projectName, initGit: initGit)
            createSessionWithDirectory(path)
        }
    }

    func createSessionWithDirectory(_ path: String) {
        appState.createSessionWithWorktree(
            directory: path,
            provider: selectedProvider,
            modelId: selectedModelId,
            trustMode: selectedTrustMode
        )
    }
}
```

**Functional Requirements**:
1. Browse: Uses existing directory selection logic
2. Clone: Awaits clone completion before creating session
3. Create: Creates directory, optionally runs `git init`
4. All paths: Pass provider/modelId to session creation

**Test Plan**:
- E2E: Create session via Browse → session created with provider
- E2E: Create session via Clone → clone completes, session created
- E2E: Create session via Create → directory created, session created

**Verification Steps**:
1. Create session with each directory source type
2. Verify session appears in sidebar with correct provider logo
3. Query DB → verify provider/modelId stored

---

#### A006-ENGINE: Engine Adapter Wiring

**Problem**: EngineManager needs to use session's provider for adapter selection.

**Files to Modify**:
- `Blaze/Sources/Engine/EngineManager.swift`

**Implementation**:
```swift
extension EngineManager {
    func getAdapter(for session: Session) -> EngineAdapter {
        switch session.provider {
        case .anthropic:
            return ClaudeCodeAdapter()
        case .openai:
            return CodexCLIAdapter()
        case .google:
            return GeminiCLIAdapter()
        }
    }
}
```

**Verification Steps**:
1. Create session with Anthropic → verify Claude CLI spawned
2. Create session with OpenAI → verify Codex CLI spawned
3. Create session with Google → verify Gemini CLI spawned

---

#### A007-CLIVAL: CLI Validation Pre-Check

**Problem**: User might select provider whose CLI isn't installed.

**Scope In**:
- Check CLI availability before enabling provider
- Show install prompt for missing CLIs
- Link to F005 installation flow

**Files to Modify**:
- `Blaze/Sources/UI/NewSessionModal.swift`
- Add `CLIAvailabilityChecker` service

**Functional Requirements**:
1. On modal open, check all CLI availability
2. Disable provider if CLI not found
3. Show "Install" button that navigates to onboarding CLI screen

**Verification Steps**:
1. Uninstall a CLI (e.g., `npm uninstall -g @google/gemini-cli`)
2. Open New Session → verify Google provider shows "Not installed"
3. Click Install → verify navigation to installation flow

---

#### A008-DEFAULTS: Provider Defaults & Persistence

**Problem**: Need sensible defaults and persistence for provider preferences.

**Scope In**:
- Store last-used provider in UserDefaults
- Auto-select last-used provider on modal open
- Per-directory provider hints (if `.claude/` exists, default to Claude)

**Files to Modify**:
- `Blaze/Sources/UI/NewSessionModal.swift`
- `Blaze/Sources/App/AppSettings.swift`

**Functional Requirements**:
1. Last-used provider persists across app restarts
2. Directory hints: `.claude/` → Anthropic, `.gemini/` → Google, `.codex/` → OpenAI
3. Directory hint takes precedence over last-used

**Verification Steps**:
1. Select OpenAI provider → create session → quit app
2. Relaunch → open New Session → verify OpenAI selected
3. Browse to directory with `.claude/` → verify Anthropic selected

---

## F002: Sidebar Enhancements

### Overview

Add notification badges for unread events and vendor logos to session rows.

### Atoms

#### S001-UNREAD: Unread Badge State Management

**Problem**: No way to know if background worktrees have new events.

**Scope In**:
- `ReadStateStore` actor for tracking read positions
- `session_read_states` table in SQLite
- `unreadCounts` dictionary in app state
- `markSessionAsRead()` method

**Schema**:
```sql
CREATE TABLE session_read_states (
    session_id TEXT PRIMARY KEY,
    last_read_sequence INTEGER NOT NULL DEFAULT 0,
    last_read_at DATETIME NOT NULL
);
```

**Files to Create**:
- `Blaze/Sources/Data/ReadStateStore.swift`

**Files to Modify**:
- `Blaze/Sources/Core/Models.swift`
- `Blaze/Sources/Data/Migrations.swift`
- `Blaze/Sources/App/BlazeApp.swift`

**Functional Requirements**:
1. Track last-read event sequence per session
2. Calculate unread count: total events - last read sequence
3. Reset count when session becomes active
4. Persist across app restarts

**Verification Steps**:
1. Create two sessions, send events to Session B while viewing Session A
2. Verify Session B shows unread badge
3. Switch to Session B → badge clears
4. Quit/relaunch → badge state persisted

---

#### S002-BADGE: Unread Badge UI

**Problem**: No visual indicator for unread events.

**Files to Modify**:
- `Blaze/Sources/UI/Sidebar/SessionsSidebarView.swift`

**UI**:
```
SessionRow
├── StatusIndicator (●/○)
├── VendorLogo (16px)
├── Name/Time
├── [Spacer]
├── CountBadge (if unread > 0)
└── HoverButtons (edit/delete)
```

**Functional Requirements**:
1. Badge shows count when unread > 0
2. Badge hidden for current session
3. Badge hidden when count = 0
4. Badge uses design system `CountBadge` component

**Verification Steps**:
1. Generate events in background session
2. Verify badge appears with correct count
3. Switch sessions → badge clears

---

#### S003-LOGOS: Vendor Brand Logos

**Problem**: Hard to tell which CLI a session is using.

**Files to Create**:
- `Blaze/Sources/DesignSystem/Components/VendorLogo.swift`

**Assets to Add**:
- `Blaze/Resources/Assets.xcassets/logo-anthropic.imageset/`
- `Blaze/Resources/Assets.xcassets/logo-google.imageset/`
- `Blaze/Resources/Assets.xcassets/logo-openai.imageset/`

**Implementation**:
```swift
struct VendorLogo: View {
    let provider: AIProvider
    let size: CGFloat = 16

    var body: some View {
        Image(provider.logoAssetName)
            .resizable()
            .frame(width: size, height: size)
            .renderingMode(.template)  // For theme adaptation
    }
}

extension AIProvider {
    var logoAssetName: String {
        switch self {
        case .anthropic: return "logo-anthropic"
        case .openai: return "logo-openai"
        case .google: return "logo-google"
        }
    }
}
```

**Functional Requirements**:
1. Logos render at 16px
2. Logos adapt to light/dark theme (template rendering)
3. Fallback to SF Symbol if asset missing

**Verification Steps**:
1. Create sessions with each provider
2. Verify correct logo appears in sidebar
3. Toggle dark mode → verify logo adapts

---

#### S004-ANIMATION: Badge Animation

**Problem**: New events should draw attention.

**Scope In**:
- Subtle pulse animation when count increases
- Animation respects `accessibilityReduceMotion`

**Verification Steps**:
1. Receive event in background session
2. Verify badge pulses once
3. Enable Reduce Motion → verify no animation

---

## F003: Onboarding + Tutorial (Expanded)

### Overview

7-screen first-launch onboarding wizard with CLI detection, one-click installation, skill/plugin/agent recommendations, and interactive tutorial overlay. Significantly expanded from original spec to include dynamic recommendations based on installed CLIs.

### Screen Flow

```
Screen 1: Welcome
    ↓
Screen 2: User Profile (name, email, skip)
    ↓
Screen 3: CLI Detection & Installation
    ↓
Screen 4: Skills Recommendations
    ↓
Screen 5: Plugins Recommendations (per CLI)
    ↓
Screen 6: Agents Recommendations
    ↓
Screen 7: Completion (Close or Tutorial)
    ↓ (if Tutorial)
Tutorial Overlay (7 areas)
```

### Atoms

#### O001-INFRA: Onboarding Infrastructure

**Files to Create**:
- `Blaze/Sources/Onboarding/OnboardingStep.swift`
- `Blaze/Sources/Onboarding/OnboardingViewModel.swift`
- `Blaze/Sources/Onboarding/OnboardingRootView.swift`
- `Blaze/Sources/Onboarding/OnboardingNavigationBar.swift`

**State Machine**:
```swift
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case userProfile
    case cliDetection
    case skillsRecommendations
    case pluginsRecommendations
    case agentsRecommendations
    case completion
}

@Observable
class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var hasCompletedOnboarding: Bool { get/set via AppStorage }
    var userName: String = ""
    var userEmail: String = ""
    var installedCLIs: Set<CLIType> = []
    var selectedSkills: Set<SkillItem> = []
    var selectedPlugins: Set<PluginItem> = []
    var selectedAgents: Set<AgentItem> = []

    func canProceedFromCurrentStep() -> Bool
    func goToNextStep()
    func goToPreviousStep()
    func skipStep()
    func completeOnboarding()
}
```

---

#### O002-WELCOME: Welcome Screen

**File**: `Blaze/Sources/Onboarding/Screens/WelcomeOnboardingView.swift`

**Design**:
- Animated Blaze logo (scale + fade, 1.2s)
- "Welcome to Blaze" headline
- Brief value prop (3 bullets)
- [Get Started] button

**Functional Requirements**:
1. Animation plays on appear
2. Animation respects `accessibilityReduceMotion`
3. [Get Started] advances to Screen 2

---

#### O003-PROFILE: User Profile Screen

**File**: `Blaze/Sources/Onboarding/Screens/UserProfileOnboardingView.swift`

**Design**:
- First name field
- Last name field
- Email field (optional)
- Tooltip: "Used to personalize your experience"
- [Skip] and [Next] buttons

**Functional Requirements**:
1. Fields validate as user types
2. Skip stores empty strings
3. Data persists to AppStorage
4. Welcome back toast on subsequent launches: "Welcome back, {firstName}!"

---

#### O004-CLIDETECT: CLI Detection Screen

**File**: `Blaze/Sources/Onboarding/Screens/CLIDetectionOnboardingView.swift`

This is a major screen implementing the full CLI detection and one-click installation flow. See F005 for detailed implementation.

**UI Summary**:
```
┌─────────────────────────────────────────────────────┐
│  CLI Detection & Installation                       │
├─────────────────────────────────────────────────────┤
│ ✓ Claude Code    v2.1.0    [Installed] [Recommended]│
│ ✗ Codex CLI      ---       [Install]                │
│ ✓ Gemini CLI     v1.0.3    [Installed]              │
│ ✗ Aider          ---       [Install]   [Recommended]│
│ ✗ OpenCode       ---       [Install]                │
│ ✗ Amp            ---       [Install]                │
├─────────────────────────────────────────────────────┤
│ [Install All Missing]        [Skip]      [Next →]   │
└─────────────────────────────────────────────────────┘
```

**One-Click Installation Flow**:
1. Check dependencies (Node.js, Python, Rust)
2. Install missing dependencies via Homebrew
3. Install CLI via npm/pip/brew
4. Configure PATH in .zshrc
5. Verify installation

---

#### O005-SKILLS: Skills Recommendations Screen

**File**: `Blaze/Sources/Onboarding/Screens/SkillsRecommendationsView.swift`

**Design**:
- Grid of skill cards (fetched from remote registry)
- Filter by installed CLIs
- Search/category filter
- Checkbox selection
- [Skip] and [Next] buttons

**Dynamic Logic**:
- Filter skills by `for_cli` field matching installed CLIs
- Sort by popularity (stars/downloads)
- Highlight "Recommended" skills

---

#### O006-PLUGINS: Plugins Recommendations Screen

**File**: `Blaze/Sources/Onboarding/Screens/PluginsRecommendationsView.swift`

**Design**:
- Grouped by CLI (e.g., "Claude Code Plugins", "Gemini Extensions")
- Only show sections for installed CLIs
- Plugin cards with install button

**Dynamic Recommendations**:
| If Installed | Show Plugins |
|--------------|--------------|
| Claude Code | Gastown, Continuous-Claude-v2, Braintrust |
| Gemini CLI | Official extensions catalog |
| Codex CLI | MCP servers, AGENTS.md guide |
| Aider | Git integration tips |

---

#### O007-AGENTS: Agents Recommendations Screen

**File**: `Blaze/Sources/Onboarding/Screens/AgentsRecommendationsView.swift`

**Design**:
- Grid of agent cards
- Filter by use case (Planning, Debugging, Security, etc.)
- Checkbox selection

---

#### O008-COMPLETION: Completion Screen

**File**: `Blaze/Sources/Onboarding/Screens/CompletionOnboardingView.swift`

**Design**:
- Success animation
- Summary of installed items
- [Close] and [Start Tutorial] buttons

**Functional Requirements**:
1. Set `hasCompletedOnboarding = true`
2. Trigger selected item installation
3. [Tutorial] opens tutorial overlay

---

#### O009-TUTORIAL-INFRA: Tutorial Overlay Infrastructure

**Files to Create**:
- `Blaze/Sources/Tutorial/TutorialTarget.swift`
- `Blaze/Sources/Tutorial/TutorialViewModel.swift`
- `Blaze/Sources/Tutorial/TutorialOverlayView.swift`
- `Blaze/Sources/Tutorial/TutorialBackdrop.swift`
- `Blaze/Sources/Tutorial/TutorialCallout.swift`
- `Blaze/Sources/Tutorial/TutorialAnchorPreferenceKey.swift`

**Tutorial Targets** (7 areas):
1. New Session button
2. Worktree sidebar
3. File tree
4. Terminal panel
5. Chat area
6. Chat input
7. Right sidebar (Timeline, Tools, Tasks, Tokens, Hooks)

---

#### O010-O016: Individual Tutorial Step Views

One atom per tutorial step, each with:
- Target area anchor
- Callout text
- Next/Previous buttons
- Spotlight cutout

---

#### O017-INTEGRATE: App Integration

**Files to Modify**:
- `Blaze/Sources/App/BlazeApp.swift`
- `Blaze/Sources/App/ContentView.swift`

**Logic**:
```swift
@main
struct BlazeApp: App {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @State private var showTutorial = false
    @State private var showWelcomeBack = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingRootView()
                }
                .overlay {
                    if showTutorial {
                        TutorialOverlayView()
                    }
                }
                .onAppear {
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    } else if !userName.isEmpty {
                        showWelcomeBack = true
                    }
                }
        }
    }
}
```

---

#### O018-POLISH: Animation Polish

**Deliverables**:
- Welcome logo: scale 0.8→1.0 + fade, 1.2s spring
- Page transitions: horizontal slide, 0.35s spring
- Callout entrance: scale 0.9→1.0 + opacity, 0.35s
- Toast slide-down: 0.3s ease-out
- All animations respect `accessibilityReduceMotion`

---

## F004: Multi-CLI Hooks Support (Expanded)

### Overview

Comprehensive multi-CLI hooks architecture supporting concurrent worktrees with different providers (Claude in worktree A, Codex in worktree B, Gemini in worktree C), provider selector in Hooks Builder, hook descriptions, and Gantt visualization.

### Architecture

```
Project Directory/
├── .claude/settings.json      # Claude Code hooks
├── .gemini/settings.json      # Gemini CLI hooks
├── .codex/settings.json       # Codex CLI config (notify only)
└── .blaze-worktrees/
    └── <worktree-uuid>/
        └── .blaze-hooks.json  # Worktree-specific overrides
```

### Atoms

#### H001-PROVIDER: HookProvider Enum

**File**: `Blaze/Sources/Core/Hooks/HookProvider.swift`

```swift
enum HookProvider: String, Codable, CaseIterable {
    case claude, gemini, codex

    var supportsHooks: Bool {
        self != .codex
    }

    var configDirectoryName: String {
        switch self {
        case .claude: return ".claude"
        case .gemini: return ".gemini"
        case .codex: return ".codex"
        }
    }

    var settingsFilename: String { "settings.json" }

    var events: [HookEventDefinition] {
        switch self {
        case .claude: return ClaudeHookEvents.all
        case .gemini: return GeminiHookEvents.all
        case .codex: return []
        }
    }
}
```

---

#### H002-SCHEMA: Per-Provider Event Definitions

**File**: `Blaze/Sources/Core/Hooks/HookSchema.swift`

See "Hook Schema Reference" section above for complete event definitions.

---

#### H003-SERVICE: MultiProviderHooksService

**File**: `Blaze/Sources/Engine/MultiProviderHooksService.swift`

Actor service for loading, saving, and merging hooks across providers.

**Key Methods**:
```swift
actor MultiProviderHooksService {
    func resolveConfigPath(provider:, scope:, worktreeId:) -> URL
    func loadHooks(provider:, scope:, worktreeId:) async throws -> HookConfiguration
    func saveHooks(_:, projectPath:) async throws
    func getEffectiveHooks(provider:, worktreeContext:) -> HookConfiguration
}
```

---

#### H004-RUNNER: Provider-Aware HookRunner

**File**: `Blaze/Sources/Engine/HookRunner.swift` (modification)

Add provider parameter to execution:
```swift
func executeHooks(
    for eventType: HookEventType,
    provider: HookProvider,  // NEW
    worktreeId: UUID?        // NEW
) async -> [HookExecutionResult]
```

---

#### H005-UIPROVIDER: Provider Selector UI

**File**: `Blaze/Sources/Settings/Hooks/ProviderSelectorView.swift`

Segmented control at top of Hooks Builder:
- [Claude Code] - All 12 events
- [Gemini] - 11 events
- [Codex] - Disabled with tooltip

---

#### H006-DESCRIPTION: Hook Description Field

**Problem**: Current UI shows "PostToolUse, PostToolUse, PostToolUse" with no way to distinguish.

**Solution**: Add required `description` field to hook entries:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "description": "Log all tool calls to trace file",
        "matcher": ["Write", "Edit"],
        "hooks": [{"type": "command", "command": "..."}]
      }
    ]
  }
}
```

**UI**: Table shows Event | Description | Scope | Status columns.

---

#### H007-MIGRATE: Hook Migration Utilities

**File**: `Blaze/Sources/Core/Hooks/HookMigrator.swift`

```swift
struct HookMigrator {
    func migrateHook(from: HookProvider, to: HookProvider, hook: HookNode) -> HookNode?
    func mapEventName(from: HookProvider, to: HookProvider, event: String) -> String?
    func mapToolName(from: HookProvider, to: HookProvider, tool: String) -> String?
}
```

**Event Mapping (Claude → Gemini)**:
- `PreToolUse` → `BeforeTool`
- `PostToolUse` → `AfterTool`
- `UserPromptSubmit` → `BeforeAgent`
- `Stop` → `AfterAgent`
- `PreCompact` → `PreCompress`

---

#### H008-EXPORT: Provider-Specific Export

**File**: `Blaze/Sources/Settings/Hooks/HooksInstallationService.swift`

Export to correct config path:
- Claude: `<project>/.claude/settings.json`
- Gemini: `<project>/.gemini/settings.json`
- Codex: `<project>/.codex/config.toml` (TOML format)

---

#### H009-CONTEXT: Session-Aware Hook Context

**File**: `Blaze/Sources/Engine/HookRunner.swift`

Pass session's provider to hook execution:
```swift
func startSession(_ session: Session) {
    let provider = HookProvider(from: session.engineType)
    hookRunner.setActiveProvider(provider)
}
```

---

## F005: CLI Detection & Installation (NEW)

### Overview

Full automation for detecting and installing agentic coding CLIs during onboarding.

### Atoms

#### C001-TYPES: CLI Type Definitions

**File**: `Blaze/Sources/Onboarding/Models/CLITypes.swift`

```swift
enum CLIType: String, CaseIterable {
    case claude, codex, gemini, aider, cursor, cody, opencode, amp

    var displayName: String
    var executable: String
    var versionFlag: String
    var description: String
    var isRecommended: Bool
    var dependencies: [DependencyType]
    var installCommand: InstallCommand
}

enum DependencyType: String {
    case nodejs, python, rust
}

enum InstallCommand {
    case npm(package: String)
    case pip(package: String)
    case brew(formula: String)
    case cask(name: String)
    case shell(script: String)
}
```

---

#### C002-SERVICE: CLIInstallationService

**File**: `Blaze/Sources/Onboarding/Services/CLIInstallationService.swift`

Actor service for detection and installation.

---

#### C003-STATE: Installation State Machine

**File**: `Blaze/Sources/Onboarding/Services/CLIInstallationState.swift`

```swift
enum CLISetupState {
    case scanning
    case detected(results: [CLIDetectionResult])
    case installing(cli: CLIType, progress: InstallProgress, queue: [CLIType])
    case complete(installed: [CLIType], failed: [(CLIType, CLIInstallError)])
    case skipped
    case error(SetupError)
}
```

---

#### C004-VIEW: CLI Setup View

**File**: `Blaze/Sources/Onboarding/Views/OnboardingCLISetupView.swift`

See O004-CLIDETECT for UI details.

---

#### C005-PROGRESS: Installation Progress View

**File**: `Blaze/Sources/Onboarding/Views/InstallationProgressView.swift`

Step-by-step progress with cancel button.

---

#### C006-VIEWMODEL: CLI Setup ViewModel

**File**: `Blaze/Sources/Onboarding/ViewModels/CLISetupViewModel.swift`

Orchestrates detection, installation, and state transitions.

---

## F006: Plugin/Skill/Agent Registries (NEW)

### Overview

Remote registry system for discovering and installing skills, plugins, and agents.

### Architecture

```
Remote Sources                      Local Cache
┌─────────────────┐                ┌──────────────────┐
│ Cogit0 API      │──────┐         │ SQLite Cache     │
│ (primary)       │      │         │ (24h TTL)        │
└─────────────────┘      │         └──────────────────┘
                         ▼                    │
┌─────────────────┐   ┌──────────┐           │
│ GitHub Raw      │──▶│ Registry │◀──────────┘
│ (fallback)      │   │ Fetcher  │
└─────────────────┘   └──────────┘
                         │
                         ▼
                  ┌──────────────────┐
                  │ Registry         │
                  │ Coordinator      │
                  │ (ObservableObject)│
                  └──────────────────┘
                         │
                         ▼
                  ┌──────────────────┐
                  │ Onboarding UI    │
                  │ Screens 4, 5, 6  │
                  └──────────────────┘
```

### Atoms

#### R001-MODELS: Registry Data Models

**File**: `Blaze/Sources/Registry/Models/RegistryModels.swift`

```swift
struct RegistryResponse: Codable {
    let schemaVersion: String
    let updatedAt: Date
    let skills: [SkillItem]
    let plugins: [PluginItem]
    let agents: [AgentItem]
}

struct SkillItem: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let version: String
    let forCli: [String]
    let installUrl: String
    let metadata: RegistryMetadata
    let permissions: RegistryPermissions
}
// Similar for PluginItem, AgentItem
```

---

#### R002-FETCHER: Registry Fetcher

**File**: `Blaze/Sources/Registry/RegistryFetcher.swift`

Network layer with signature verification.

---

#### R003-CACHE: Registry Cache

**File**: `Blaze/Sources/Registry/RegistryCache.swift`

SQLite cache with 24h TTL.

---

#### R004-INSTALLER: Registry Installer

**File**: `Blaze/Sources/Registry/RegistryInstaller.swift`

File system operations for installing items.

---

#### R005-COORDINATOR: Registry Coordinator

**File**: `Blaze/Sources/Registry/RegistryCoordinator.swift`

Main orchestrator exposing skills, plugins, agents to UI.

---

#### R006-SKILLSUI: Skills Selection View

**File**: `Blaze/Sources/Onboarding/SkillsSelectionView.swift`

Grid view with search, filter, selection.

---

#### R007-PLUGINSUI: Plugins Selection View

**File**: `Blaze/Sources/Onboarding/PluginsSelectionView.swift`

Grouped by CLI.

---

#### R008-AGENTSUI: Agents Selection View

**File**: `Blaze/Sources/Onboarding/AgentsSelectionView.swift`

Filtered by use case.

---

## F007: Hooks Visualization - Gantt Chart (NEW)

### Overview

Gantt-style timeline visualization for hook execution, with turn-level and session-level views.

### Visual Design

**Turn-Level View**:
```
Time →   0ms      500ms     1s        1.5s
         │─────────│─────────│─────────│
● UserPromptSubmit
   ██████  142ms

▼ PreToolUse (Bash)
   ████████████████████  832ms
   └─ continuity.sh
     ███████████  489ms

  PostToolUse (Bash)
   ██████  98ms

● Stop
   ████  52ms
```

### Atoms

#### G001-MODEL: Timeline Event Model

**File**: `Blaze/Sources/Core/HookTimeline/HookTimelineEvent.swift`

```swift
struct HookTimelineEvent: Identifiable {
    let id: UUID
    let name: String
    let category: HookTimelineCategory
    let startTime: Date
    let endTime: Date?
    let depth: Int
    let children: [HookTimelineEvent]
    let status: HookTimelineStatus
}

enum HookTimelineCategory {
    case session  // Blue
    case turn     // Purple
    case tool     // Orange
    case file     // Green
    case git      // Cyan
}
```

---

#### G002-BUILDER: Timeline Builder

**File**: `Blaze/Sources/Core/HookTimeline/HookTimelineBuilder.swift`

Converts HookExecution arrays to timeline events.

---

#### G003-VIEWMODEL: Gantt ViewModel

**File**: `Blaze/Sources/UI/Hooks/HookGanttViewModel.swift`

Observable state with real-time updates.

---

#### G004-CONTAINER: Gantt Container View

**File**: `Blaze/Sources/UI/Hooks/HookGanttView.swift`

Main container with mode toggle.

---

#### G005-ROW: Gantt Row Component

**File**: `Blaze/Sources/UI/Hooks/GanttRow.swift`

Individual hook row with bar.

---

#### G006-BAR: Gantt Bar Component

**File**: `Blaze/Sources/UI/Hooks/GanttBar.swift`

Animated timeline bar.

---

#### G007-TOOLTIP: Hook Tooltip

**File**: `Blaze/Sources/UI/Hooks/HookTooltip.swift`

Hover tooltip with full details.

---

## F008: Codex App-Server Integration (NEW)

### Overview

Support for Codex CLI in app-server mode for advanced scenarios.

### Atoms

#### X001-ADAPTER: App-Server Adapter

**File**: `Blaze/Sources/Engine/CodexAppServerAdapter.swift`

JSON-RPC communication with app-server daemon.

---

#### X002-MANAGER: App-Server Lifecycle Manager

**File**: `Blaze/Sources/Engine/CodexAppServerManager.swift`

Start/stop app-server, health checks.

---

#### X003-EVENTS: App-Server Event Stream

**File**: `Blaze/Sources/Engine/CodexAppServerEvents.swift`

Parse event stream from app-server.

---

#### X004-SESSION: App-Server Session Persistence

**File**: `Blaze/Sources/Engine/CodexAppServerSession.swift`

Session state management.

---

#### X005-CONFIG: App-Server Configuration

**File**: `Blaze/Sources/Engine/CodexAppServerConfig.swift`

Port, auth, and startup configuration.

---

## F009: Advanced Hooks Builder (NEW)

### Overview

Comprehensive visual hook builder with all Claude Code hook features: multiple hook types (prompt, command, agent), pattern matching, input/output schema visualization, environment variable reference, testing, and debugging. Based on the complete [Claude Code Hooks reference](https://gist.github.com/alexfazio/653c5164d726987569ee8229a19f451f).

### Hook Types Reference

The hooks builder supports three hook types with distinct use cases:

| Type | Use Case | Execution | Timeout |
|------|----------|-----------|---------|
| `prompt` | Context-aware decisions, complex reasoning | LLM evaluation | 30s |
| `command` | Deterministic validation, file operations | Bash script | 60s |
| `agent` | Agent/subagent lifecycle integration | Agent invocation | - |

### Atoms

#### B001-TYPES: Hook Type System

**File**: `Blaze/Sources/Core/Hooks/HookTypes.swift`

```swift
import Foundation

// MARK: - Hook Type

/// The type of hook execution
public enum HookType: String, Codable, CaseIterable, Sendable {
    case prompt   // LLM-based reasoning
    case command  // Bash script execution
    case agent    // Agent lifecycle hook (v2.1.0+)

    public var displayName: String {
        switch self {
        case .prompt: return "Prompt"
        case .command: return "Command"
        case .agent: return "Agent"
        }
    }

    public var icon: String {
        switch self {
        case .prompt: return "brain"
        case .command: return "terminal"
        case .agent: return "person.crop.circle"
        }
    }

    public var description: String {
        switch self {
        case .prompt:
            return "Use LLM reasoning for context-aware decisions. Best for complex validation that requires understanding code semantics."
        case .command:
            return "Execute bash scripts for deterministic validation. Best for fast checks, file operations, and external tool integration."
        case .agent:
            return "Tie into agent/subagent lifecycle events. Available in v2.1.0+ for advanced orchestration."
        }
    }

    public var defaultTimeout: Int {
        switch self {
        case .prompt: return 30
        case .command: return 60
        case .agent: return 120
        }
    }

    /// Available template variables for this hook type
    public var templateVariables: [TemplateVariable] {
        switch self {
        case .prompt:
            return [
                TemplateVariable(name: "$TOOL_INPUT", description: "Full tool input object"),
                TemplateVariable(name: "$TOOL_INPUT.command", description: "Command for Bash tool"),
                TemplateVariable(name: "$TOOL_INPUT.file_path", description: "File path for Write/Edit"),
                TemplateVariable(name: "$TOOL_INPUT.content", description: "File content"),
                TemplateVariable(name: "$TOOL_RESULT", description: "Tool execution result"),
                TemplateVariable(name: "$USER_PROMPT", description: "User's submitted prompt"),
                TemplateVariable(name: "$TRANSCRIPT_PATH", description: "Path to session transcript")
            ]
        case .command:
            return [
                TemplateVariable(name: "$CLAUDE_PROJECT_DIR", description: "Project root path"),
                TemplateVariable(name: "$CLAUDE_PLUGIN_ROOT", description: "Plugin directory (portable paths)"),
                TemplateVariable(name: "$CLAUDE_ENV_FILE", description: "SessionStart only: persist env vars here"),
                TemplateVariable(name: "$CLAUDE_CODE_REMOTE", description: "Set if running remotely")
            ]
        case .agent:
            return []
        }
    }
}

public struct TemplateVariable: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let description: String
}

// MARK: - Hook Definition

/// A single hook definition that can be executed
public struct HookDefinition: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID = UUID()
    public var type: HookType
    public var timeout: Int?

    // For prompt type
    public var prompt: String?

    // For command type
    public var command: String?

    // For agent type (v2.1.0+)
    public var agent: String?

    // Only execute once per session (skills/slash commands only)
    public var once: Bool?

    public init(type: HookType) {
        self.type = type
        self.timeout = type.defaultTimeout
    }

    /// Validate the hook definition
    public func validate() -> [HookValidationError] {
        var errors: [HookValidationError] = []

        switch type {
        case .prompt:
            if prompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                errors.append(.missingPrompt)
            }
        case .command:
            if command?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                errors.append(.missingCommand)
            }
            if let cmd = command, !cmd.contains("$CLAUDE_PLUGIN_ROOT") && !cmd.hasPrefix("/") {
                errors.append(.relativePathWarning)
            }
        case .agent:
            if agent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                errors.append(.missingAgent)
            }
        }

        if let timeout = timeout, timeout < 1 || timeout > 600 {
            errors.append(.invalidTimeout(timeout))
        }

        return errors
    }
}

public enum HookValidationError: LocalizedError, Sendable {
    case missingPrompt
    case missingCommand
    case missingAgent
    case relativePathWarning
    case invalidTimeout(Int)

    public var errorDescription: String? {
        switch self {
        case .missingPrompt:
            return "Prompt hook requires a prompt string"
        case .missingCommand:
            return "Command hook requires a command string"
        case .missingAgent:
            return "Agent hook requires an agent name"
        case .relativePathWarning:
            return "Use $CLAUDE_PLUGIN_ROOT for portable paths"
        case .invalidTimeout(let value):
            return "Timeout must be 1-600 seconds (got \(value))"
        }
    }

    public var isWarning: Bool {
        switch self {
        case .relativePathWarning: return true
        default: return false
        }
    }
}
```

---

#### B002-MATCHERS: Pattern Matching System

**File**: `Blaze/Sources/Core/Hooks/HookMatchers.swift`

```swift
import Foundation

// MARK: - Matcher

/// Pattern for matching tool names or events
public struct HookMatcher: Codable, Sendable, Hashable {
    public let pattern: String
    public let type: MatcherType

    public init(pattern: String) {
        self.pattern = pattern
        self.type = MatcherType.detect(from: pattern)
    }

    /// Test if this matcher matches a given tool name
    public func matches(_ toolName: String) -> Bool {
        switch type {
        case .exact:
            return pattern == toolName
        case .multiple:
            let options = pattern.split(separator: "|").map(String.init)
            return options.contains(toolName)
        case .wildcard:
            return true  // "*" matches everything
        case .regex:
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }
            let range = NSRange(toolName.startIndex..., in: toolName)
            return regex.firstMatch(in: toolName, range: range) != nil
        }
    }
}

public enum MatcherType: String, Codable, Sendable {
    case exact      // "Write"
    case multiple   // "Read|Write|Edit"
    case wildcard   // "*"
    case regex      // "mcp__.*__delete.*"

    public static func detect(from pattern: String) -> MatcherType {
        if pattern == "*" {
            return .wildcard
        } else if pattern.contains("|") {
            return .multiple
        } else if pattern.contains(".*") || pattern.contains("[") || pattern.contains("\\") {
            return .regex
        } else {
            return .exact
        }
    }

    public var displayName: String {
        switch self {
        case .exact: return "Exact"
        case .multiple: return "Multiple"
        case .wildcard: return "All"
        case .regex: return "Regex"
        }
    }

    public var icon: String {
        switch self {
        case .exact: return "equal"
        case .multiple: return "list.bullet"
        case .wildcard: return "asterisk"
        case .regex: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Session Start Matchers

/// Matchers specific to SessionStart event
public enum SessionStartMatcher: String, Codable, CaseIterable, Sendable {
    case startup   // First session start
    case resume    // Session resumed from saved state
    case clear     // Session cleared by user
    case compact   // Session compacted

    public var description: String {
        switch self {
        case .startup: return "Fires on first session start"
        case .resume: return "Fires when session resumes from saved state"
        case .clear: return "Fires when user clears session"
        case .compact: return "Fires after context compaction"
        }
    }
}

// MARK: - PreCompact Matchers

/// Matchers specific to PreCompact event
public enum PreCompactMatcher: String, Codable, CaseIterable, Sendable {
    case manual  // User-triggered compaction
    case auto    // Automatic compaction

    public var description: String {
        switch self {
        case .manual: return "User triggered context compaction"
        case .auto: return "Automatic context compaction due to limit"
        }
    }
}

// MARK: - Matcher Suggestions

/// Provides intelligent matcher suggestions based on event type
public struct MatcherSuggestions {
    /// Common tool patterns for PreToolUse/PostToolUse
    public static let toolPatterns: [(pattern: String, description: String)] = [
        ("Bash", "Match shell command execution"),
        ("Write", "Match file creation"),
        ("Edit", "Match file modifications"),
        ("Read", "Match file reads"),
        ("Write|Edit", "Match any file modification"),
        ("Read|Write|Edit", "Match all file operations"),
        ("Grep|Glob", "Match search operations"),
        ("*", "Match all tools"),
        ("mcp__.*", "Match all MCP tool calls"),
        ("mcp__.*__delete.*", "Match MCP delete operations"),
        ("Task", "Match agent spawning"),
        ("WebFetch|WebSearch", "Match web operations")
    ]

    /// Get suggestions for a given event type
    public static func suggestions(for event: String) -> [(pattern: String, description: String)] {
        switch event {
        case "PreToolUse", "PostToolUse":
            return toolPatterns
        case "SessionStart":
            return SessionStartMatcher.allCases.map { ($0.rawValue, $0.description) }
        case "PreCompact":
            return PreCompactMatcher.allCases.map { ($0.rawValue, $0.description) }
        default:
            return [("*", "Match all")]
        }
    }
}
```

---

#### B003-INPUT: Hook Input Schema

**File**: `Blaze/Sources/Core/Hooks/HookInputSchema.swift`

```swift
import Foundation

// MARK: - Hook Input

/// Input passed to hooks via stdin (JSON)
public struct HookInput: Codable, Sendable {
    /// Unique session identifier
    public let sessionId: String

    /// Path to session transcript file
    public let transcriptPath: String

    /// Current working directory
    public let cwd: String

    /// Permission mode: "ask" or "allow"
    public let permissionMode: String

    /// Name of the hook event
    public let hookEventName: String

    /// Tool name (PreToolUse/PostToolUse only)
    public let toolName: String?

    /// Tool input object (PreToolUse/PostToolUse only)
    public let toolInput: [String: AnyCodable]?

    /// Tool execution result (PostToolUse only)
    public let toolResult: AnyCodable?

    /// User's prompt text (UserPromptSubmit only)
    public let userPrompt: String?

    /// Reason for stopping (Stop/SubagentStop only)
    public let reason: String?

    /// Type of session start (SessionStart only)
    public let startType: String?

    /// Type of compaction (PreCompact only)
    public let compactType: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
        case permissionMode = "permission_mode"
        case hookEventName = "hook_event_name"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolResult = "tool_result"
        case userPrompt = "user_prompt"
        case reason
        case startType = "start_type"
        case compactType = "compact_type"
    }
}

/// Type-erased Codable wrapper for dynamic JSON values
public struct AnyCodable: Codable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map(AnyCodable.init))
        case let dict as [String: Any]:
            try container.encode(dict.mapValues(AnyCodable.init))
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Input Examples

/// Example inputs for testing hooks in the builder
public enum HookInputExamples {

    public static func example(for event: String, toolName: String? = nil) -> HookInput {
        let base = HookInput(
            sessionId: "example-session-\(UUID().uuidString.prefix(8))",
            transcriptPath: "/tmp/claude-transcript-example.json",
            cwd: "/Users/developer/my-project",
            permissionMode: "ask",
            hookEventName: event,
            toolName: nil,
            toolInput: nil,
            toolResult: nil,
            userPrompt: nil,
            reason: nil,
            startType: nil,
            compactType: nil
        )

        switch event {
        case "PreToolUse":
            return HookInput(
                sessionId: base.sessionId,
                transcriptPath: base.transcriptPath,
                cwd: base.cwd,
                permissionMode: base.permissionMode,
                hookEventName: event,
                toolName: toolName ?? "Write",
                toolInput: [
                    "file_path": AnyCodable("/Users/developer/my-project/src/main.swift"),
                    "content": AnyCodable("import Foundation\n\nprint(\"Hello\")")
                ],
                toolResult: nil,
                userPrompt: nil,
                reason: nil,
                startType: nil,
                compactType: nil
            )
        case "PostToolUse":
            return HookInput(
                sessionId: base.sessionId,
                transcriptPath: base.transcriptPath,
                cwd: base.cwd,
                permissionMode: base.permissionMode,
                hookEventName: event,
                toolName: toolName ?? "Bash",
                toolInput: ["command": AnyCodable("npm test")],
                toolResult: AnyCodable("All 42 tests passed"),
                userPrompt: nil,
                reason: nil,
                startType: nil,
                compactType: nil
            )
        case "UserPromptSubmit":
            return HookInput(
                sessionId: base.sessionId,
                transcriptPath: base.transcriptPath,
                cwd: base.cwd,
                permissionMode: base.permissionMode,
                hookEventName: event,
                toolName: nil,
                toolInput: nil,
                toolResult: nil,
                userPrompt: "Please implement the login feature with OAuth2 support",
                reason: nil,
                startType: nil,
                compactType: nil
            )
        case "SessionStart":
            return HookInput(
                sessionId: base.sessionId,
                transcriptPath: base.transcriptPath,
                cwd: base.cwd,
                permissionMode: base.permissionMode,
                hookEventName: event,
                toolName: nil,
                toolInput: nil,
                toolResult: nil,
                userPrompt: nil,
                reason: nil,
                startType: "startup",
                compactType: nil
            )
        case "Stop":
            return HookInput(
                sessionId: base.sessionId,
                transcriptPath: base.transcriptPath,
                cwd: base.cwd,
                permissionMode: base.permissionMode,
                hookEventName: event,
                toolName: nil,
                toolInput: nil,
                toolResult: nil,
                userPrompt: nil,
                reason: "Task completed successfully",
                startType: nil,
                compactType: nil
            )
        default:
            return base
        }
    }
}
```

---

#### B004-OUTPUT: Hook Output Schema

**File**: `Blaze/Sources/Core/Hooks/HookOutputSchema.swift`

```swift
import Foundation

// MARK: - Hook Output

/// Standard output structure for all hooks
public struct HookOutput: Codable, Sendable {
    /// Whether to continue processing (default: true)
    public var `continue`: Bool = true

    /// Whether to suppress hook output in logs
    public var suppressOutput: Bool = false

    /// Message to inject into Claude's system context
    public var systemMessage: String?

    /// Hook-specific output (PreToolUse/PermissionRequest)
    public var hookSpecificOutput: HookSpecificOutput?

    public init() {}
}

/// Hook-specific output for PreToolUse and PermissionRequest
public struct HookSpecificOutput: Codable, Sendable {
    /// Permission decision
    public var permissionDecision: PermissionDecision?

    /// Modified tool input (middleware pattern)
    public var updatedInput: [String: AnyCodable]?

    /// Decision for Stop/SubagentStop hooks
    public var decision: StopDecision?

    /// Reason for the decision
    public var reason: String?
}

/// Permission decisions for blocking hooks
public enum PermissionDecision: String, Codable, Sendable, CaseIterable {
    case allow  // Auto-approve the action
    case deny   // Auto-reject the action
    case ask    // Defer to user (default Claude behavior)

    public var displayName: String {
        switch self {
        case .allow: return "Allow"
        case .deny: return "Deny"
        case .ask: return "Ask User"
        }
    }

    public var icon: String {
        switch self {
        case .allow: return "checkmark.circle.fill"
        case .deny: return "xmark.circle.fill"
        case .ask: return "questionmark.circle"
        }
    }

    public var color: String {
        switch self {
        case .allow: return "#10B981"  // Green
        case .deny: return "#EF4444"   // Red
        case .ask: return "#F59E0B"    // Yellow
        }
    }
}

/// Stop decisions for Stop/SubagentStop hooks
public enum StopDecision: String, Codable, Sendable, CaseIterable {
    case approve  // Allow agent to stop
    case block    // Force agent to continue

    public var displayName: String {
        switch self {
        case .approve: return "Approve Stop"
        case .block: return "Block Stop"
        }
    }
}

// MARK: - Exit Codes

/// Exit code behavior for command hooks
public enum HookExitCode: Int, Sendable {
    case success = 0           // Success, stdout shown to Claude
    case blockingError = 2     // Blocking error, stderr returned
    case nonBlockingError = 1  // Non-blocking error (or any other code)

    public var description: String {
        switch self {
        case .success:
            return "Success - stdout is shown to Claude"
        case .blockingError:
            return "Blocking error - stderr returned, stops processing"
        case .nonBlockingError:
            return "Non-blocking error - logged but continues"
        }
    }
}

// MARK: - Output Builder

/// Fluent builder for constructing hook outputs
public struct HookOutputBuilder {
    private var output = HookOutput()

    public init() {}

    public func continue_(_ value: Bool) -> Self {
        var copy = self
        copy.output.continue = value
        return copy
    }

    public func suppressOutput(_ value: Bool) -> Self {
        var copy = self
        copy.output.suppressOutput = value
        return copy
    }

    public func systemMessage(_ message: String) -> Self {
        var copy = self
        copy.output.systemMessage = message
        return copy
    }

    public func allow() -> Self {
        var copy = self
        if copy.output.hookSpecificOutput == nil {
            copy.output.hookSpecificOutput = HookSpecificOutput()
        }
        copy.output.hookSpecificOutput?.permissionDecision = .allow
        return copy
    }

    public func deny(reason: String? = nil) -> Self {
        var copy = self
        if copy.output.hookSpecificOutput == nil {
            copy.output.hookSpecificOutput = HookSpecificOutput()
        }
        copy.output.hookSpecificOutput?.permissionDecision = .deny
        if let reason = reason {
            copy.output.hookSpecificOutput?.reason = reason
        }
        return copy
    }

    public func ask() -> Self {
        var copy = self
        if copy.output.hookSpecificOutput == nil {
            copy.output.hookSpecificOutput = HookSpecificOutput()
        }
        copy.output.hookSpecificOutput?.permissionDecision = .ask
        return copy
    }

    public func updatedInput(_ input: [String: AnyCodable]) -> Self {
        var copy = self
        if copy.output.hookSpecificOutput == nil {
            copy.output.hookSpecificOutput = HookSpecificOutput()
        }
        copy.output.hookSpecificOutput?.updatedInput = input
        return copy
    }

    public func build() -> HookOutput {
        return output
    }

    public func buildJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(output)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
```

---

#### B005-TEMPLATES: Common Hook Templates

**File**: `Blaze/Sources/Core/Hooks/HookTemplates.swift`

```swift
import Foundation

// MARK: - Hook Templates

/// Pre-built hook templates for common use cases
public enum HookTemplates {

    public struct Template: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let description: String
        public let category: TemplateCategory
        public let event: String
        public let matcher: String
        public let hookType: HookType
        public let content: String
        public let outputExample: String
    }

    public enum TemplateCategory: String, CaseIterable, Sendable {
        case security = "Security"
        case testing = "Testing"
        case logging = "Logging"
        case context = "Context"
        case workflow = "Workflow"
    }

    // MARK: - Security Templates

    public static let securityFileProtection = Template(
        id: "security-file-protection",
        name: "File Path Protection",
        description: "Block writes to sensitive paths like /etc, credentials, or path traversal attempts",
        category: .security,
        event: "PreToolUse",
        matcher: "Write|Edit",
        hookType: .prompt,
        content: """
        Verify this file operation is safe:
        - NOT in /etc or other system directories
        - NOT a credentials file (.env, secrets.*, credentials.*)
        - NO path traversal (no '..' in path)
        - NOT overwriting protected config

        If unsafe, deny with specific reason.
        Tool input: $TOOL_INPUT
        """,
        outputExample: """
        {
          "continue": true,
          "hookSpecificOutput": {
            "permissionDecision": "allow"
          },
          "systemMessage": "File path verified safe"
        }
        """
    )

    public static let securityCommandValidation = Template(
        id: "security-command-validation",
        name: "Dangerous Command Blocker",
        description: "Block dangerous shell commands like rm -rf, chmod 777, or curl | bash",
        category: .security,
        event: "PreToolUse",
        matcher: "Bash",
        hookType: .command,
        content: """
        #!/bin/bash
        set -euo pipefail

        # Read input from stdin
        INPUT=$(cat)
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

        # Dangerous patterns
        if echo "$COMMAND" | grep -qE 'rm\\s+(-rf|--recursive)\\s+(/|~|\\$HOME)'; then
            echo '{"continue":false,"hookSpecificOutput":{"permissionDecision":"deny","reason":"Blocked: recursive delete on root/home"}}'
            exit 0
        fi

        if echo "$COMMAND" | grep -qE 'chmod\\s+(777|\\+rwx)'; then
            echo '{"continue":false,"hookSpecificOutput":{"permissionDecision":"deny","reason":"Blocked: overly permissive chmod"}}'
            exit 0
        fi

        if echo "$COMMAND" | grep -qE 'curl.*\\|.*bash'; then
            echo '{"continue":false,"hookSpecificOutput":{"permissionDecision":"deny","reason":"Blocked: curl piped to bash"}}'
            exit 0
        fi

        # Allow if no dangerous patterns
        echo '{"continue":true}'
        """,
        outputExample: """
        {"continue":true}
        """
    )

    // MARK: - Testing Templates

    public static let testEnforcement = Template(
        id: "test-enforcement",
        name: "Test Before Stop",
        description: "Ensure tests were run before allowing agent to stop after code changes",
        category: .testing,
        event: "Stop",
        matcher: "*",
        hookType: .prompt,
        content: """
        Before approving stop, verify:
        1. If code was modified in this session, tests must have been executed
        2. Tests must have passed (or failures explicitly addressed)
        3. Build must succeed

        Review the transcript at $TRANSCRIPT_PATH to verify.
        If tests weren't run after code changes, block with instruction to run tests.
        """,
        outputExample: """
        {
          "hookSpecificOutput": {
            "decision": "block",
            "reason": "Code was modified but tests were not run. Please run the test suite."
          },
          "systemMessage": "Tests required before completing task"
        }
        """
    )

    // MARK: - Context Templates

    public static let contextLoader = Template(
        id: "context-loader",
        name: "Project Context Loader",
        description: "Load project-specific context (CLAUDE.md, .env, patterns) on session start",
        category: .context,
        event: "SessionStart",
        matcher: "startup",
        hookType: .command,
        content: """
        #!/bin/bash
        set -euo pipefail

        PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
        CONTEXT=""

        # Load CLAUDE.md if exists
        if [[ -f "$PROJECT_DIR/CLAUDE.md" ]]; then
            CONTEXT+="\\n## Project Instructions\\n$(cat "$PROJECT_DIR/CLAUDE.md")"
        fi

        # Load recent git context
        if [[ -d "$PROJECT_DIR/.git" ]]; then
            BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
            RECENT=$(git -C "$PROJECT_DIR" log --oneline -5 2>/dev/null || echo "no commits")
            CONTEXT+="\\n## Git Context\\nBranch: $BRANCH\\nRecent commits:\\n$RECENT"
        fi

        # Output context as system message
        if [[ -n "$CONTEXT" ]]; then
            jq -n --arg msg "$CONTEXT" '{continue: true, systemMessage: $msg}'
        else
            echo '{"continue": true}'
        fi
        """,
        outputExample: """
        {
          "continue": true,
          "systemMessage": "## Project Instructions\\n[CLAUDE.md content]\\n## Git Context\\nBranch: main"
        }
        """
    )

    // MARK: - Logging Templates

    public static let toolLogger = Template(
        id: "tool-logger",
        name: "Tool Execution Logger",
        description: "Log all tool executions to a trace file for debugging and auditing",
        category: .logging,
        event: "PostToolUse",
        matcher: "*",
        hookType: .command,
        content: """
        #!/bin/bash
        set -euo pipefail

        INPUT=$(cat)
        LOG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/tool-trace.jsonl"

        mkdir -p "$(dirname "$LOG_FILE")"

        # Append tool execution to log
        echo "$INPUT" | jq -c '{
            timestamp: (now | todate),
            tool: .tool_name,
            input: .tool_input,
            result_preview: (.tool_result | tostring | .[0:200])
        }' >> "$LOG_FILE"

        echo '{"continue": true, "suppressOutput": true}'
        """,
        outputExample: """
        {"continue": true, "suppressOutput": true}
        """
    )

    // MARK: - All Templates

    public static let all: [Template] = [
        securityFileProtection,
        securityCommandValidation,
        testEnforcement,
        contextLoader,
        toolLogger
    ]

    public static func templates(for category: TemplateCategory) -> [Template] {
        all.filter { $0.category == category }
    }
}
```

---

#### B006-TESTING: Hook Test Runner

**File**: `Blaze/Sources/Settings/Hooks/HookTestRunner.swift`

```swift
import Foundation

// MARK: - Hook Test Runner

/// Service for testing hooks with sample input before deployment
public actor HookTestRunner {

    public struct TestResult: Sendable {
        public let success: Bool
        public let output: String
        public let exitCode: Int
        public let duration: TimeInterval
        public let parsedOutput: HookOutput?
        public let errors: [String]
    }

    /// Test a command hook with sample input
    public func testCommandHook(
        command: String,
        input: HookInput,
        timeout: TimeInterval = 60
    ) async throws -> TestResult {
        let startTime = Date()

        // Create temp script if command is inline
        let scriptPath: String
        let cleanup: Bool

        if command.hasPrefix("/") || command.hasPrefix("$") {
            // External script path
            scriptPath = command
                .replacingOccurrences(of: "$CLAUDE_PROJECT_DIR", with: FileManager.default.currentDirectoryPath)
                .replacingOccurrences(of: "$CLAUDE_PLUGIN_ROOT", with: FileManager.default.currentDirectoryPath + "/.claude")
            cleanup = false
        } else {
            // Inline script - write to temp file
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent("hook-test-\(UUID().uuidString).sh")
            try command.write(to: tempFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempFile.path)
            scriptPath = tempFile.path
            cleanup = true
        }

        defer {
            if cleanup {
                try? FileManager.default.removeItem(atPath: scriptPath)
            }
        }

        // Encode input as JSON
        let encoder = JSONEncoder()
        let inputData = try encoder.encode(input)
        let inputJSON = String(data: inputData, encoding: .utf8) ?? "{}"

        // Run the hook
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "echo '\(inputJSON.replacingOccurrences(of: "'", with: "'\\''"))' | \(scriptPath)"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        // Wait with timeout
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            process.waitUntilExit()
            semaphore.signal()
        }

        let timeoutResult = semaphore.wait(timeout: .now() + timeout)
        if timeoutResult == .timedOut {
            process.terminate()
            return TestResult(
                success: false,
                output: "",
                exitCode: -1,
                duration: Date().timeIntervalSince(startTime),
                parsedOutput: nil,
                errors: ["Hook timed out after \(Int(timeout)) seconds"]
            )
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        let exitCode = Int(process.terminationStatus)
        let duration = Date().timeIntervalSince(startTime)

        // Try to parse output as HookOutput
        var parsedOutput: HookOutput?
        var errors: [String] = []

        if !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                let decoder = JSONDecoder()
                parsedOutput = try decoder.decode(HookOutput.self, from: Data(output.utf8))
            } catch {
                errors.append("Failed to parse output as JSON: \(error.localizedDescription)")
            }
        }

        if !errorOutput.isEmpty {
            errors.append("stderr: \(errorOutput)")
        }

        return TestResult(
            success: exitCode == 0 && errors.isEmpty,
            output: output,
            exitCode: exitCode,
            duration: duration,
            parsedOutput: parsedOutput,
            errors: errors
        )
    }

    /// Generate test command for CLI debugging
    public func generateTestCommand(
        scriptPath: String,
        input: HookInput
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let inputData = try encoder.encode(input)
        let inputJSON = String(data: inputData, encoding: .utf8) ?? "{}"

        return """
        echo '\(inputJSON.replacingOccurrences(of: "'", with: "'\\''"))' | \\
          bash \(scriptPath)
        """
    }
}
```

---

#### B007-ENV: Environment Variable Reference

**File**: `Blaze/Sources/Core/Hooks/HookEnvironment.swift`

```swift
import Foundation

// MARK: - Hook Environment Variables

/// Reference for all environment variables available to hooks
public enum HookEnvironment {

    public struct Variable: Identifiable, Sendable {
        public var id: String { name }
        public let name: String
        public let description: String
        public let example: String
        public let availability: [String]  // Events where this is available
        public let critical: Bool  // Whether this should always be used
    }

    public static let all: [Variable] = [
        Variable(
            name: "CLAUDE_PROJECT_DIR",
            description: "Absolute path to the project root directory",
            example: "/Users/developer/my-project",
            availability: ["All events"],
            critical: true
        ),
        Variable(
            name: "CLAUDE_PLUGIN_ROOT",
            description: "Path to plugin directory. Use for portable script paths.",
            example: "/Users/developer/my-project/.claude",
            availability: ["All events"],
            critical: true
        ),
        Variable(
            name: "CLAUDE_ENV_FILE",
            description: "Path to write persistent environment variables",
            example: "/tmp/claude-env-abc123",
            availability: ["SessionStart"],
            critical: false
        ),
        Variable(
            name: "CLAUDE_CODE_REMOTE",
            description: "Set to 'true' if running in remote/container environment",
            example: "true",
            availability: ["All events"],
            critical: false
        )
    ]

    /// Best practices for using environment variables
    public static let bestPractices: [String] = [
        "Always use ${CLAUDE_PLUGIN_ROOT} for script paths to ensure portability",
        "Check if CLAUDE_CODE_REMOTE is set before accessing local resources",
        "Use CLAUDE_ENV_FILE in SessionStart to persist variables across the session",
        "Never hardcode absolute paths - use environment variables instead",
        "Quote all variable references in bash: \"$CLAUDE_PROJECT_DIR\"",
        "Use set -euo pipefail at the start of bash scripts"
    ]
}
```

---

#### B008-UI-BUILDER: Visual Hook Builder View

**File**: `Blaze/Sources/Settings/Hooks/AdvancedHookBuilderView.swift`

**UI Wireframe**:
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Hooks Workflow Builder                                      [Test] [Export]│
├─────────────────────────────────────────────────────────────────────────────┤
│  Provider: [● Claude Code ○ Gemini ○ Codex (disabled)]                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐       │
│  │ SessionStart    │────▶│ PreToolUse      │────▶│ PostToolUse     │       │
│  │ ● startup       │     │ Write|Edit      │     │ *               │       │
│  │ ○ resume        │     │ [prompt]        │     │ [command]       │       │
│  │ ○ clear         │     │                 │     │                 │       │
│  └────────┬────────┘     └────────┬────────┘     └────────┬────────┘       │
│           │                       │                       │                 │
│           ▼                       ▼                       ▼                 │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐       │
│  │ Load Context    │     │ Security Check  │     │ Log to Trace    │       │
│  │ context-loader  │     │ file-protection │     │ tool-logger     │       │
│  │ ⚙️ Edit          │     │ ⚙️ Edit          │     │ ⚙️ Edit          │       │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘       │
│                                                                             │
│  [+ Add Hook Event]                                      Zoom: [−] 100% [+] │
├─────────────────────────────────────────────────────────────────────────────┤
│  Hook Inspector                                                      [×]    │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Name: Security Check                                                    ││
│  │ Event: PreToolUse                                                       ││
│  │ Matcher: Write|Edit                          [Suggestions ▾]            ││
│  │ Type: ● Prompt  ○ Command  ○ Agent                                      ││
│  │ Timeout: [30] seconds                                                   ││
│  │ ┌─────────────────────────────────────────────────────────────────────┐ ││
│  │ │ Verify this file operation is safe:                                 │ ││
│  │ │ - NOT in /etc or other system directories                           │ ││
│  │ │ - NOT a credentials file (.env, secrets.*, credentials.*)           │ ││
│  │ │ - NO path traversal (no '..' in path)                               │ ││
│  │ │                                                                     │ ││
│  │ │ If unsafe, deny with specific reason.                               │ ││
│  │ │ Tool input: $TOOL_INPUT                                             │ ││
│  │ └─────────────────────────────────────────────────────────────────────┘ ││
│  │                                                                         ││
│  │ Variables: [$TOOL_INPUT] [$TOOL_INPUT.file_path] [$TOOL_INPUT.content]  ││
│  │                                                                         ││
│  │ [Test with Sample Input]                         [Delete Hook]          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

---

#### B009-UI-TEMPLATES: Template Gallery View

**File**: `Blaze/Sources/Settings/Hooks/HookTemplateGalleryView.swift`

**UI Wireframe**:
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Hook Templates                                             [Search: ____] │
├─────────────────────────────────────────────────────────────────────────────┤
│  Categories: [All] [Security] [Testing] [Logging] [Context] [Workflow]     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────┐  ┌──────────────────────────────┐        │
│  │ 🔒 File Path Protection      │  │ 🔒 Dangerous Command Blocker │        │
│  │ Block writes to /etc, creds, │  │ Block rm -rf /, chmod 777,   │        │
│  │ and path traversal attempts  │  │ curl | bash patterns         │        │
│  │                              │  │                              │        │
│  │ Event: PreToolUse            │  │ Event: PreToolUse            │        │
│  │ Type: prompt                 │  │ Type: command                │        │
│  │ [Preview] [Use Template]     │  │ [Preview] [Use Template]     │        │
│  └──────────────────────────────┘  └──────────────────────────────┘        │
│                                                                             │
│  ┌──────────────────────────────┐  ┌──────────────────────────────┐        │
│  │ 🧪 Test Before Stop          │  │ 📝 Tool Execution Logger     │        │
│  │ Ensure tests pass before     │  │ Log all tool executions to   │        │
│  │ allowing agent to stop       │  │ .claude/tool-trace.jsonl     │        │
│  │                              │  │                              │        │
│  │ Event: Stop                  │  │ Event: PostToolUse           │        │
│  │ Type: prompt                 │  │ Type: command                │        │
│  │ [Preview] [Use Template]     │  │ [Preview] [Use Template]     │        │
│  └──────────────────────────────┘  └──────────────────────────────┘        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

#### B010-UI-TESTER: Hook Test Panel

**File**: `Blaze/Sources/Settings/Hooks/HookTestPanelView.swift`

**UI Wireframe**:
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Test Hook: Security Check                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  Sample Input                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ {                                                                       ││
│  │   "session_id": "test-abc123",                                          ││
│  │   "hook_event_name": "PreToolUse",                                      ││
│  │   "tool_name": "Write",                                                 ││
│  │   "tool_input": {                                                       ││
│  │     "file_path": "/etc/passwd",                    ← [Edit]             ││
│  │     "content": "malicious content"                                      ││
│  │   }                                                                     ││
│  │ }                                                                       ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│  [Load Example: Safe File] [Load Example: Dangerous Path] [Custom]          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                          [▶ Run Test]                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  Output                                                    Duration: 142ms  │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ {                                                                       ││
│  │   "continue": false,                                                    ││
│  │   "hookSpecificOutput": {                                               ││
│  │     "permissionDecision": "deny",                                       ││
│  │     "reason": "Blocked: write to /etc is forbidden"                     ││
│  │   }                                                                     ││
│  │ }                                                                       ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│  Exit Code: 0 ✓                              [Copy Output] [Copy CLI Test]  │
├─────────────────────────────────────────────────────────────────────────────┤
│  CLI Test Command:                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ echo '{"session_id":"test-abc123",...}' | \                             ││
│  │   bash .claude/hooks/security-check.sh                                  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                    [Copy]   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

#### B011-UI-ENVREF: Environment Reference Panel

**File**: `Blaze/Sources/Settings/Hooks/HookEnvReferenceView.swift`

Collapsible panel showing all environment variables with copy buttons.

---

#### B012-VALIDATION: Hook Configuration Validator

**File**: `Blaze/Sources/Core/Hooks/HookValidator.swift`

```swift
import Foundation

public actor HookValidator {

    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let errors: [ValidationError]
        public let warnings: [ValidationWarning]
    }

    public struct ValidationError: Sendable, Identifiable {
        public var id: String { "\(path):\(message)" }
        public let path: String
        public let message: String
    }

    public struct ValidationWarning: Sendable, Identifiable {
        public var id: String { "\(path):\(message)" }
        public let path: String
        public let message: String
    }

    /// Validate a complete hook configuration
    public func validate(_ config: HookConfiguration) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Validate each event
        for (event, entries) in config.hooks {
            for (index, entry) in entries.enumerated() {
                let path = "hooks.\(event)[\(index)]"

                // Validate matcher
                if entry.matcher.isEmpty {
                    warnings.append(ValidationWarning(
                        path: path,
                        message: "No matcher specified, will match all"
                    ))
                }

                // Validate hooks array
                if entry.hooks.isEmpty {
                    errors.append(ValidationError(
                        path: path,
                        message: "No hooks defined in entry"
                    ))
                }

                // Validate each hook definition
                for (hookIndex, hook) in entry.hooks.enumerated() {
                    let hookPath = "\(path).hooks[\(hookIndex)]"
                    let hookErrors = hook.validate()

                    for error in hookErrors {
                        if error.isWarning {
                            warnings.append(ValidationWarning(
                                path: hookPath,
                                message: error.localizedDescription ?? ""
                            ))
                        } else {
                            errors.append(ValidationError(
                                path: hookPath,
                                message: error.localizedDescription ?? ""
                            ))
                        }
                    }
                }
            }
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    /// Validate JSON syntax
    public func validateJSON(_ json: String) -> Result<Void, Error> {
        do {
            _ = try JSONSerialization.jsonObject(with: Data(json.utf8))
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
```

---

#### B013-DEBUG: Debug Mode Integration

**File**: `Blaze/Sources/Settings/Hooks/HookDebugService.swift`

Service for enabling Claude Code debug mode and capturing hook execution logs.

```swift
public actor HookDebugService {
    /// Enable debug mode in Claude Code
    public func enableDebugMode() async throws {
        // Sets CLAUDE_DEBUG=1 for next session
    }

    /// Parse debug output for hook execution traces
    public func parseDebugOutput(_ output: String) -> [HookExecutionTrace] {
        // Extract hook execution details from debug logs
    }

    /// Real-time hook execution monitoring
    public func startMonitoring(projectPath: String) -> AsyncStream<HookExecutionTrace> {
        // Watch for hook executions and stream events
    }
}
```

---

#### B014-EXPORT: Advanced Export Options

**File**: `Blaze/Sources/Settings/Hooks/HookExportService.swift`

Export hooks to correct format per provider with validation.

```swift
public actor HookExportService {

    public enum ExportFormat {
        case claudeSettings      // .claude/settings.json
        case geminiSettings      // .gemini/settings.json
        case pluginHooks         // Plugin hooks.json with wrapper
        case frontmatter         // YAML frontmatter for agents/skills
    }

    /// Export configuration to file
    public func export(
        _ config: HookConfiguration,
        format: ExportFormat,
        to path: URL
    ) async throws {
        // Validate before export
        let validator = HookValidator()
        let result = await validator.validate(config)

        guard result.isValid else {
            throw HookExportError.validationFailed(result.errors)
        }

        // Export based on format
        switch format {
        case .claudeSettings:
            try await exportClaudeSettings(config, to: path)
        case .geminiSettings:
            try await exportGeminiSettings(config, to: path)
        case .pluginHooks:
            try await exportPluginHooks(config, to: path)
        case .frontmatter:
            try await exportFrontmatter(config, to: path)
        }
    }

    private func exportClaudeSettings(_ config: HookConfiguration, to path: URL) async throws {
        // Merge with existing settings.json if present
        var settings: [String: Any] = [:]

        if FileManager.default.fileExists(atPath: path.path) {
            let data = try Data(contentsOf: path)
            if let existing = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                settings = existing
            }
        }

        // Update hooks section only
        settings["hooks"] = config.toJSON()

        let output = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try output.write(to: path)
    }
}
```

---

### Test Suite for F009

```swift
// Blaze/Tests/Hooks/HookBuilderTests.swift

import XCTest
@testable import Blaze

final class HookBuilderTests: XCTestCase {

    // MARK: - Matcher Tests

    func testExactMatcher() {
        let matcher = HookMatcher(pattern: "Write")
        XCTAssertEqual(matcher.type, .exact)
        XCTAssertTrue(matcher.matches("Write"))
        XCTAssertFalse(matcher.matches("Edit"))
    }

    func testMultipleMatcher() {
        let matcher = HookMatcher(pattern: "Write|Edit|Read")
        XCTAssertEqual(matcher.type, .multiple)
        XCTAssertTrue(matcher.matches("Write"))
        XCTAssertTrue(matcher.matches("Edit"))
        XCTAssertTrue(matcher.matches("Read"))
        XCTAssertFalse(matcher.matches("Bash"))
    }

    func testWildcardMatcher() {
        let matcher = HookMatcher(pattern: "*")
        XCTAssertEqual(matcher.type, .wildcard)
        XCTAssertTrue(matcher.matches("Write"))
        XCTAssertTrue(matcher.matches("Bash"))
        XCTAssertTrue(matcher.matches("AnyTool"))
    }

    func testRegexMatcher() {
        let matcher = HookMatcher(pattern: "mcp__.*__delete.*")
        XCTAssertEqual(matcher.type, .regex)
        XCTAssertTrue(matcher.matches("mcp__fs__delete_file"))
        XCTAssertTrue(matcher.matches("mcp__db__delete_row"))
        XCTAssertFalse(matcher.matches("mcp__fs__read_file"))
    }

    // MARK: - Hook Validation Tests

    func testPromptHookValidation() {
        var hook = HookDefinition(type: .prompt)
        XCTAssertFalse(hook.validate().isEmpty)  // Missing prompt

        hook.prompt = "Validate this action"
        XCTAssertTrue(hook.validate().isEmpty)
    }

    func testCommandHookValidation() {
        var hook = HookDefinition(type: .command)
        XCTAssertFalse(hook.validate().isEmpty)  // Missing command

        hook.command = "validate.sh"
        let errors = hook.validate()
        XCTAssertTrue(errors.contains { $0 == .relativePathWarning })

        hook.command = "${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh"
        XCTAssertTrue(hook.validate().filter { !$0.isWarning }.isEmpty)
    }

    func testTimeoutValidation() {
        var hook = HookDefinition(type: .prompt)
        hook.prompt = "Test"
        hook.timeout = 0
        XCTAssertTrue(hook.validate().contains {
            if case .invalidTimeout = $0 { return true }
            return false
        })

        hook.timeout = 700
        XCTAssertTrue(hook.validate().contains {
            if case .invalidTimeout = $0 { return true }
            return false
        })

        hook.timeout = 30
        XCTAssertFalse(hook.validate().contains {
            if case .invalidTimeout = $0 { return true }
            return false
        })
    }

    // MARK: - Output Builder Tests

    func testOutputBuilderAllow() throws {
        let output = HookOutputBuilder()
            .allow()
            .systemMessage("Approved automatically")
            .build()

        XCTAssertTrue(output.continue)
        XCTAssertEqual(output.hookSpecificOutput?.permissionDecision, .allow)
        XCTAssertEqual(output.systemMessage, "Approved automatically")
    }

    func testOutputBuilderDeny() throws {
        let output = HookOutputBuilder()
            .deny(reason: "Path traversal detected")
            .continue_(false)
            .build()

        XCTAssertFalse(output.continue)
        XCTAssertEqual(output.hookSpecificOutput?.permissionDecision, .deny)
        XCTAssertEqual(output.hookSpecificOutput?.reason, "Path traversal detected")
    }

    // MARK: - Template Tests

    func testTemplatesExist() {
        XCTAssertFalse(HookTemplates.all.isEmpty)
        XCTAssertTrue(HookTemplates.all.count >= 5)
    }

    func testSecurityTemplates() {
        let security = HookTemplates.templates(for: .security)
        XCTAssertFalse(security.isEmpty)
        XCTAssertTrue(security.allSatisfy { $0.event == "PreToolUse" })
    }

    // MARK: - Test Runner Tests

    func testCommandHookExecution() async throws {
        let runner = HookTestRunner()
        let input = HookInputExamples.example(for: "PreToolUse", toolName: "Write")

        let result = try await runner.testCommandHook(
            command: """
            #!/bin/bash
            echo '{"continue": true}'
            """,
            input: input,
            timeout: 5
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNotNil(result.parsedOutput)
        XCTAssertTrue(result.parsedOutput?.continue ?? false)
    }
}
```

---

## Implementation Order

```
Week 1: Foundation
  F005-C001 → F005-C002 → F001-A001 → F001-A002 → F001-A003

Week 2: Session Creation
  F001-A004 → F001-A005 → F001-A006 → F002-S001 → F002-S002 → F002-S003

Week 3: Onboarding Core
  F003-O001 → F003-O002 → F003-O003 → F003-O004 → F005-C003 → F005-C004

Week 4: Registries
  F006-R001 → F006-R002 → F006-R003 → F006-R004 → F006-R005

Week 5: Onboarding Recommendations
  F003-O005 → F003-O006 → F003-O007 → F003-O008 → F006-R006 → F006-R007

Week 6: Hooks Infrastructure
  F004-H001 → F004-H002 → F004-H003 → F004-H004 → F004-H005

Week 7: Hooks Visualization
  F007-G001 → F007-G002 → F007-G003 → F007-G004 → F007-G005

Week 8: Tutorial & Polish
  F003-O009 → F003-O010-O016 → F003-O017 → F003-O018

Week 9: Advanced Hooks Builder
  F009-B001 → F009-B002 → F009-B003 → F009-B004 → F009-B005
  F009-B006 → F009-B007 → F009-B008 → F009-B009 → F009-B010

Week 10: Hooks Builder UI + Codex (Optional)
  F009-B011 → F009-B012 → F009-B013 → F009-B014
  F008-X001 → F008-X002 → F008-X003 → F008-X004 → F008-X005
```

---

## Verification Plan

### E2E Test Scenarios

1. **Multi-Provider Session**: Create sessions with Claude/Codex/Gemini, verify correct CLI spawned
2. **One-Click Install**: Uninstall CLI, run onboarding, verify installation succeeds
3. **Registry Fetch**: Clear cache, verify registry loads from remote
4. **Plugin Install**: Select plugin in onboarding, verify installed
5. **Hook Segregation**: Create hooks for different providers, verify isolation
6. **Gantt Visualization**: Execute hooks, verify timeline renders correctly
7. **Tutorial Flow**: Complete all 7 tutorial steps, verify completion state

### Manual QA Checklist

- [ ] Provider/model selector matches mockup
- [ ] Clone from GitHub works with public repo
- [ ] Vendor logos visible at 16px in both themes
- [ ] Onboarding animation is tasteful, not overwhelming
- [ ] Tutorial callouts don't overlap highlighted areas
- [ ] Hooks builder shows correct events per provider
- [ ] Hooks builder shows "not supported" for Codex
- [ ] Hook export writes to correct config path
- [ ] Gantt chart fits within 300px sidebar
- [ ] Welcome back toast appears on subsequent launch

---

## Risk Register (Epic Level)

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| CLI installation fails on some machines | Medium | High | Comprehensive error handling, manual install fallback |
| Registry API unavailable | Low | Medium | Bundled fallback list, 24h cache |
| Hook schema changes upstream | Medium | Medium | Version detection, graceful degradation |
| Codex adds hooks later | High | Low | Feature flag to enable when ready |
| Performance with many hooks | Medium | Medium | LazyVStack, pagination, virtualization |
| Onboarding drop-off | Medium | Medium | Skip buttons, progress persistence |

---

## Design Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Model scope | Per-worktree | Enables concurrent multi-model workflows |
| Vendor logos | Brand assets, template rendering | Theme adaptation |
| Hook descriptions | settings.json extension | Backward compatible |
| Registry source | Remote with cache | Always fresh data |
| Tutorial positioning | PreferenceKey anchors | Dynamic, works with resize |
| Codex hooks | Show disabled state | Honest about current limitations |
| App-server support | Phase 2 | MVP uses headless, matches existing pattern |

---

## Open Questions

1. Should Fish shell be supported for PATH configuration?
2. Should we offer to install Homebrew automatically?
3. Do any CLIs require admin privileges?
4. Should registry support user-contributed items?
5. Maximum nesting depth for Gantt chart?
6. Should hooks persist after worktree deletion?

---

## Appendix: Source References

### CLI Documentation
- Claude Code: https://docs.anthropic.com/claude-code
- Codex CLI: https://platform.openai.com/docs/codex
- Gemini CLI: https://ai.google.dev/gemini-api
- Aider: https://aider.chat/docs
- Codex App-Server: https://github.com/openai/codex/tree/main/codex-rs/app-server

### Hook References
- Claude Code Hooks: https://gist.github.com/alexfazio/653c5164d726987569ee8229a19f451f
- Gemini CLI Hooks: https://geminicli.com/docs/hooks/
- Codex Lifecycle: https://openai.github.io/openai-agents-python/ref/lifecycle/

### Plugin Ecosystems
- claude-plugins.dev: https://claude-plugins.dev/
- Gemini Extensions: https://geminicli.com/extensions/
