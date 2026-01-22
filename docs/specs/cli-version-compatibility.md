# CLI Version Compatibility Matrix

> Cogit0 Blaze - Supported CLI Versions & Feature Availability

## Overview

This document defines the minimum supported versions, feature availability by version, and upgrade/deprecation policies for each agentic CLI that Blaze supports.

**Golden Rule:** We support the last 6 months of CLI releases, with a 3-month deprecation notice period.

---

## 1. Claude Code CLI

### 1.1 Version Requirements

| Version Range | Support Status | Notes |
|---------------|----------------|-------|
| **≥ 2.0.62** | ✅ Fully Supported | Minimum supported version |
| 2.0.50 - 2.0.61 | ⚠️ Deprecated | Missing `--output-format stream-json` stability |
| < 2.0.50 | ❌ Unsupported | No structured output support |

### 1.2 Feature Availability by Version

| Feature | Min Version | Notes |
|---------|-------------|-------|
| `--output-format stream-json` | 2.0.50 | Basic streaming support |
| Stable stream-json events | 2.0.62 | Required for reliable parsing |
| `--allowedTools` flag | 2.0.55 | Tool filtering |
| `--permission-mode` | 2.0.60 | Permission presets |
| MCP server integration | 2.0.65 | External tool servers |
| `--continue` session resume | 2.0.70 | Native session continuity |
| Multi-model routing | 2.1.0 | Opus/Sonnet/Haiku selection |
| Parallel tool execution | 2.1.5 | Concurrent tool calls |
| Extended thinking | 2.2.0 | Deep reasoning mode |

### 1.3 Event Schema Changes

| Version | Schema Change | Migration |
|---------|---------------|-----------|
| 2.0.62 | Initial stable schema | N/A |
| 2.0.70 | Added `session_id` to init event | Optional field, backward compatible |
| 2.1.0 | Added `model` field to assistant events | Optional field |
| 2.1.5 | Changed tool_use.status enum values | Map old → new values |
| 2.2.0 | Added `thinking` event type | New event, ignore if unknown |

### 1.4 Detection & Validation

```swift
// ClaudeCodeVersionDetector.swift

struct ClaudeCodeVersion: Comparable, Codable {
    let major: Int
    let minor: Int
    let patch: Int

    static let minimumSupported = ClaudeCodeVersion(major: 2, minor: 0, patch: 62)
    static let recommended = ClaudeCodeVersion(major: 2, minor: 1, patch: 0)

    var isSupported: Bool {
        self >= Self.minimumSupported
    }

    var supportStatus: SupportStatus {
        if self >= Self.recommended {
            return .fullySupported
        } else if self >= Self.minimumSupported {
            return .supported
        } else if self >= ClaudeCodeVersion(major: 2, minor: 0, patch: 50) {
            return .deprecated
        } else {
            return .unsupported
        }
    }

    enum SupportStatus {
        case fullySupported
        case supported
        case deprecated
        case unsupported

        var message: String {
            switch self {
            case .fullySupported:
                return "Your Claude Code version is up to date"
            case .supported:
                return "Update available for best experience"
            case .deprecated:
                return "This version will lose support soon. Please update."
            case .unsupported:
                return "This version is not supported. Please update to continue."
            }
        }
    }
}
```

---

## 2. Gemini CLI

### 2.1 Version Requirements

| Version Range | Support Status | Notes |
|---------------|----------------|-------|
| **≥ 1.5.0** | ✅ Fully Supported | Minimum supported version |
| 1.3.0 - 1.4.x | ⚠️ Deprecated | Limited streaming support |
| < 1.3.0 | ❌ Unsupported | No JSON output mode |

### 2.2 Feature Availability by Version

| Feature | Min Version | Notes |
|---------|-------------|-------|
| `--output-format stream-json` | 1.3.0 | Basic JSON streaming |
| `--resume` session flag | 1.4.0 | Native session resume |
| Stable event schema | 1.5.0 | Required for Blaze |
| Code execution sandbox | 1.5.5 | Sandboxed code runner |
| Multi-model selection | 1.6.0 | Flash/Pro/Ultra |
| File upload support | 1.6.5 | Multimodal input |
| Long context (1M tokens) | 1.7.0 | Extended context window |

---

## 3. OpenAI Codex CLI

### 3.1 Version Requirements

| Version Range | Support Status | Notes |
|---------------|----------------|-------|
| **≥ 0.8.0** | ✅ Fully Supported | Minimum supported version |
| 0.6.0 - 0.7.x | ⚠️ Deprecated | Unstable JSON output |
| < 0.6.0 | ❌ Unsupported | No structured output |

### 3.2 Feature Availability by Version

| Feature | Min Version | Notes |
|---------|-------------|-------|
| `--json` output mode | 0.6.0 | Basic JSON |
| `exec resume` multi-turn | 0.7.0 | Session continuity |
| Stable JSON schema | 0.8.0 | Required for Blaze |
| `--full-auto` mode | 0.8.5 | Autonomous operation |
| Sandbox policies | 0.9.0 | Security controls |
| Model selection (o1/o3) | 1.0.0 | Multi-model |

---

## 4. Unified Version Management

### 4.1 Version Registry

```swift
// CLIVersionRegistry.swift

@Observable
final class CLIVersionRegistry {
    private(set) var claudeCode: ClaudeCodeVersion?
    private(set) var gemini: GeminiVersion?
    private(set) var codex: CodexVersion?
    private(set) var lastChecked: Date?

    struct VersionStatus {
        let engine: EngineType
        let installed: Bool
        let version: String?
        let status: SupportStatus
        let capabilities: Set<CLICapability>
        let updateAvailable: Bool
        let updateURL: URL?
    }

    func checkAllVersions() async {
        async let claude = ClaudeCodeDetector().detectVersion()
        async let gem = GeminiDetector().detectVersion()
        async let cdx = CodexDetector().detectVersion()

        claudeCode = try? await claude
        gemini = try? await gem
        codex = try? await cdx
        lastChecked = Date()
    }
}
```

---

## 5. Deprecation Policy

### 5.1 Timeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CLI Version Lifecycle                             │
├─────────────────────────────────────────────────────────────────────────┤
│  Release ───────────────► 6 months ───────────────► End of Support      │
│     │                         │                           │             │
│     ▼                         ▼                           ▼             │
│  ┌──────────┐           ┌──────────────┐           ┌────────────┐      │
│  │  Active  │──3 mo────▶│  Deprecated  │──3 mo────▶│ Unsupported│      │
│  │  Support │           │  (warnings)  │           │  (blocked) │      │
│  └──────────┘           └──────────────┘           └────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 User Communication

| Phase | User Experience |
|-------|-----------------|
| **Active** | No messages |
| **Deprecated** | Banner: "A newer CLI version is available." |
| **Deprecated (30 days remaining)** | Modal: "Your CLI version will lose support in 30 days." |
| **Unsupported** | Blocking modal: "Please update to continue using Blaze." |

---

## 6. Feature Flags & Graceful Degradation

### 6.1 Capability-Based UI

```swift
struct CapabilityGatedView<Content: View, Fallback: View>: View {
    let capability: CLICapability
    @ViewBuilder let content: () -> Content
    @ViewBuilder let fallback: () -> Fallback

    @Environment(CLIVersionRegistry.self) var registry

    var body: some View {
        if registry.hasCapability(capability) {
            content()
        } else {
            fallback()
        }
    }
}
```

### 6.2 Graceful Feature Degradation

| Feature | Full Experience | Degraded Experience |
|---------|-----------------|---------------------|
| Extended Thinking | Toggle available | Hidden |
| Model Selection | Full picker | Default model only |
| Parallel Tools | Concurrent execution | Sequential fallback |
| MCP Servers | Full integration | Disabled, message shown |
| Session Resume | Native `--continue` | Blaze-managed context injection |

---

## 7. Testing Strategy

### 7.1 Version Matrix Testing

| Test Suite | Versions Tested | Frequency |
|------------|-----------------|-----------|
| Unit Tests | Latest only | Every PR |
| Integration Tests | Min supported + Latest | Daily |
| Full Compatibility | All supported versions | Weekly |
| Deprecation Tests | Deprecated versions | Pre-release |

---

## 8. Appendix: Version History

### 8.1 Claude Code Release History

| Version | Release Date | Key Features |
|---------|--------------|--------------|
| 2.2.0 | 2025-02-01 | Extended thinking mode |
| 2.1.5 | 2025-01-15 | Parallel tool execution |
| 2.1.0 | 2025-01-01 | Multi-model routing |
| 2.0.70 | 2024-12-15 | Session resume with `--continue` |
| 2.0.65 | 2024-12-01 | MCP server integration |
| 2.0.62 | 2024-11-15 | Stable stream-json (Blaze minimum) |
