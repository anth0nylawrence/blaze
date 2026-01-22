# MCP Integration Architecture Specification

> **Status:** `Draft` | **Last Updated:** 2025-12-30 | **Version:** 1.0

---

## Executive Summary

Blaze acts as an **MCP Host** that manages MCP (Model Context Protocol) servers, exposing tools to the underlying CLIs while providing governance, approval workflows, and audit logging. This architecture enables consistent tool management across all engines (Claude, Gemini, Codex) while maintaining full control over what tools are available and when they can be invoked.

**Why This Matters:** MCP is the emerging standard for AI tool integration. By being an MCP host, Blaze becomes the single control plane for all tool access, enabling security policies, usage tracking, and consistent UX regardless of which CLI is running underneath.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [MCP Protocol Primer](#2-mcp-protocol-primer)
3. [Server Management](#3-server-management)
4. [Tool Registry](#4-tool-registry)
5. [Request Interception](#5-request-interception)
6. [Governance Layer](#6-governance-layer)
7. [UI Components](#7-ui-components)
8. [Implementation](#8-implementation)

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BLAZE (MCP HOST)                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐       │
│  │  MCP Server   │    │  MCP Server   │    │  MCP Server   │       │
│  │  (Filesystem) │    │   (GitHub)    │    │    (Slack)    │       │
│  └───────┬───────┘    └───────┬───────┘    └───────┬───────┘       │
│          │                    │                    │                │
│          └────────────────────┼────────────────────┘                │
│                               │                                      │
│                               ▼                                      │
│                    ┌─────────────────────┐                          │
│                    │   Tool Registry     │                          │
│                    │  (unified view)     │                          │
│                    └──────────┬──────────┘                          │
│                               │                                      │
│                               ▼                                      │
│                    ┌─────────────────────┐                          │
│                    │  Governance Layer   │                          │
│                    │  (policies, audit)  │                          │
│                    └──────────┬──────────┘                          │
│                               │                                      │
│                               ▼                                      │
│           ┌───────────────────┼───────────────────┐                 │
│           │                   │                   │                  │
│           ▼                   ▼                   ▼                  │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐       │
│  │  Claude Code    │ │   Gemini CLI    │ │   Codex CLI     │       │
│  │  (subprocess)   │ │  (subprocess)   │ │  (subprocess)   │       │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Design Principles

1. **Single Control Plane**: All MCP servers managed by Blaze, not individual CLIs
2. **Engine Agnostic**: Same tools available regardless of which CLI is active
3. **Governance First**: Every tool call goes through policy evaluation
4. **Transparent Proxy**: CLIs don't know they're not talking to MCP directly
5. **Audit Everything**: Complete log of all tool invocations for compliance

### 1.3 Component Responsibilities

| Component | Responsibility |
|-----------|----------------|
| **MCPServerManager** | Spawn, monitor, restart MCP servers |
| **ToolRegistry** | Aggregate tools from all servers, handle naming conflicts |
| **RequestInterceptor** | Proxy requests, inject governance |
| **GovernanceLayer** | Policy evaluation, approval workflows |
| **MCPBridge** | Translate between CLI expectations and MCP protocol |

---

## 2. MCP Protocol Primer

### 2.1 What is MCP?

**Model Context Protocol (MCP)** is a standard for connecting AI models to external tools and data sources. Key concepts:

- **Host**: Application that manages MCP servers (Blaze)
- **Server**: Process that provides tools/resources (e.g., filesystem, GitHub)
- **Client**: Consumer of tools (Claude, Gemini, Codex via CLI)
- **Tool**: Function the AI can invoke (e.g., `read_file`, `create_issue`)
- **Resource**: Data the AI can access (e.g., `file://`, `github://`)

### 2.2 Protocol Messages

```typescript
// Tool discovery
interface ListToolsRequest {
  method: "tools/list"
}

interface ListToolsResponse {
  tools: Tool[]
}

interface Tool {
  name: string
  description: string
  inputSchema: JSONSchema
}

// Tool invocation
interface CallToolRequest {
  method: "tools/call"
  params: {
    name: string
    arguments: Record<string, unknown>
  }
}

interface CallToolResponse {
  content: Content[]
  isError?: boolean
}

// Resource access
interface ReadResourceRequest {
  method: "resources/read"
  params: {
    uri: string
  }
}
```

### 2.3 Transport Layer

MCP uses stdio (stdin/stdout JSON-RPC) or SSE:

```
┌─────────────────┐           ┌─────────────────┐
│      Blaze      │ ◄──────── │   MCP Server    │
│     (Host)      │  stdin    │  (subprocess)   │
│                 │ ────────► │                 │
│                 │  stdout   │                 │
└─────────────────┘           └─────────────────┘
```

---

## 3. Server Management

### 3.1 Server Configuration

Servers are configured in `~/.blaze/mcp-servers.json`:

```json
{
  "version": "1.0",
  "servers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-filesystem", "/Users/me/projects"],
      "env": {},
      "enabled": true,
      "autoStart": true,
      "restartPolicy": "on-failure",
      "maxRestarts": 3
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-github"],
      "env": {
        "GITHUB_TOKEN": "${secrets.GITHUB_TOKEN}"
      },
      "enabled": true,
      "autoStart": false,
      "permissions": {
        "repos": ["owner/repo1", "owner/repo2"]
      }
    },
    "slack": {
      "command": "uvx",
      "args": ["mcp-server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "${secrets.SLACK_BOT_TOKEN}"
      },
      "enabled": false
    }
  }
}
```

### 3.2 Server Lifecycle

```swift
enum MCPServerState: String, Codable {
    case stopped        // Not running
    case starting       // Process spawning
    case initializing   // Handshake in progress
    case ready          // Tools available
    case error          // Failed, may retry
    case stopping       // Graceful shutdown
}
```

State machine:

```
         ┌─────────────────────────────────────┐
         │                                     │
         ▼                                     │
     ┌───────┐     start()     ┌──────────┐   │
     │stopped│ ──────────────► │ starting │   │
     └───────┘                 └────┬─────┘   │
         ▲                          │         │
         │                          ▼         │
         │                   ┌─────────────┐  │
         │                   │initializing │  │
         │                   └──────┬──────┘  │
         │                          │         │
         │     stop()               ▼         │
         │ ◄────────────────┬───────────┐     │
    ┌────┴────┐             │   ready   │─────┘
    │stopping │             └─────┬─────┘  error
    └─────────┘                   │
                                  │ error
                                  ▼
                             ┌─────────┐
                             │  error  │────► restart (if policy allows)
                             └─────────┘
```

### 3.3 Server Manager

```swift
@MainActor
final class MCPServerManager: ObservableObject {
    @Published private(set) var servers: [String: MCPServer] = [:]
    @Published private(set) var serverStates: [String: MCPServerState] = [:]

    // Lifecycle
    func startServer(_ name: String) async throws
    func stopServer(_ name: String) async
    func restartServer(_ name: String) async throws
    func startAllEnabled() async

    // Health
    func healthCheck(_ name: String) async -> HealthStatus
    func watchHealth() -> AsyncStream<(String, HealthStatus)>

    // Configuration
    func loadConfig() throws
    func updateServerConfig(_ name: String, _ config: MCPServerConfig) throws
    func enableServer(_ name: String, enabled: Bool)
}

struct MCPServer: Identifiable {
    let id: String                    // Server name
    let config: MCPServerConfig
    var process: Process?
    var state: MCPServerState
    var tools: [MCPTool]
    var resources: [MCPResource]
    var lastError: Error?
    var restartCount: Int
}
```

### 3.4 Restart Policies

| Policy | Behavior |
|--------|----------|
| `never` | Don't restart on failure |
| `on-failure` | Restart on non-zero exit (default) |
| `always` | Restart on any exit |
| `on-success` | Restart only on zero exit (daemon mode) |

```swift
struct RestartPolicy: Codable {
    let type: RestartType
    let maxRestarts: Int           // 0 = unlimited
    let backoffMs: [Int]           // [1000, 2000, 4000, 8000, ...]
    let resetAfterMs: Int          // Reset restart count after stable period
}
```

---

## 4. Tool Registry

### 4.1 Unified Tool View

The Tool Registry aggregates tools from all active MCP servers:

```swift
@MainActor
final class ToolRegistry: ObservableObject {
    @Published private(set) var tools: [RegisteredTool] = []
    @Published private(set) var conflictingTools: [String: [RegisteredTool]] = [:]

    // Registration
    func registerTools(from server: String, tools: [MCPTool])
    func unregisterTools(from server: String)

    // Lookup
    func findTool(_ name: String) -> RegisteredTool?
    func findTools(matching pattern: String) -> [RegisteredTool]

    // Conflict resolution
    func setPreferredServer(for tool: String, server: String)
    func resolveConflict(_ tool: String, resolution: ConflictResolution)
}

struct RegisteredTool: Identifiable {
    let id: String                    // Unique: "server/toolName" or "toolName"
    let name: String                  // Original tool name
    let server: String                // Source server
    let description: String
    let inputSchema: JSONSchema
    var enabled: Bool
    var policy: ToolPolicy?           // Optional override policy
}
```

### 4.2 Naming Conflicts

When multiple servers provide the same tool name:

```
┌─────────────────────────────────────────────────────────────────────┐
│                      CONFLICT RESOLUTION                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Tool: "read_file"                                                  │
│                                                                      │
│  ┌─────────────────┐       ┌─────────────────┐                      │
│  │   filesystem    │       │    github       │                      │
│  │   read_file     │       │   read_file     │                      │
│  └────────┬────────┘       └────────┬────────┘                      │
│           │                         │                                │
│           └───────────┬─────────────┘                                │
│                       │                                              │
│                       ▼                                              │
│              ┌─────────────────┐                                     │
│              │ Conflict Detected│                                    │
│              └────────┬────────┘                                     │
│                       │                                              │
│           ┌───────────┼───────────┐                                  │
│           ▼           ▼           ▼                                  │
│     ┌──────────┐ ┌──────────┐ ┌──────────┐                          │
│     │ Prefer   │ │  Rename  │ │  Scope   │                          │
│     │ Server   │ │  Tools   │ │  to CLI  │                          │
│     └──────────┘ └──────────┘ └──────────┘                          │
│                                                                      │
│  Result:                                                             │
│  • filesystem/read_file (preferred)                                  │
│  • github/read_file (qualified name)                                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

Resolution strategies:

```swift
enum ConflictResolution {
    case preferServer(String)        // Use this server's version
    case qualifyAll                  // Always use "server/tool" format
    case scopeByProject              // Different projects use different servers
    case disable(except: String)     // Disable all but one
}
```

### 4.3 Tool Discovery for CLIs

When a CLI requests tool list:

```swift
func getToolsForEngine(_ engine: EngineType) -> [ExportedTool] {
    let enabledTools = tools.filter { $0.enabled }
    let policyFiltered = enabledTools.filter { tool in
        PolicyEngine.shared.canExposeToolTo(tool, engine: engine)
    }

    return policyFiltered.map { tool in
        ExportedTool(
            name: tool.resolvedName,
            description: tool.description,
            inputSchema: tool.inputSchema
        )
    }
}
```

---

## 5. Request Interception

### 5.1 Proxy Architecture

Blaze intercepts all tool calls between CLI and MCP servers:

```
┌───────────────────────────────────────────────────────────────────────┐
│                        REQUEST FLOW                                   │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   CLI Process                                                          │
│       │                                                                │
│       │ 1. tools/call { name: "read_file", args: {...} }              │
│       ▼                                                                │
│   ┌─────────────────────┐                                             │
│   │  Request Interceptor │                                            │
│   └──────────┬──────────┘                                             │
│              │                                                         │
│              ▼                                                         │
│   ┌─────────────────────┐                                             │
│   │  2. Policy Check    │ ────► Allow / Deny / RequireConfirm        │
│   └──────────┬──────────┘                                             │
│              │                                                         │
│         ┌────┴────┐                                                   │
│         │ Allowed?│                                                   │
│         └────┬────┘                                                   │
│          Yes │ No ────► Return error to CLI                          │
│              │                                                         │
│              ▼                                                         │
│   ┌─────────────────────┐                                             │
│   │  3. Route to Server │ ────► Resolve which MCP server handles     │
│   └──────────┬──────────┘                                             │
│              │                                                         │
│              ▼                                                         │
│   ┌─────────────────────┐                                             │
│   │  4. Execute Tool    │ ────► Forward to MCP server                │
│   └──────────┬──────────┘                                             │
│              │                                                         │
│              ▼                                                         │
│   ┌─────────────────────┐                                             │
│   │  5. Audit Log       │ ────► Record invocation                    │
│   └──────────┬──────────┘                                             │
│              │                                                         │
│              ▼                                                         │
│   ┌─────────────────────┐                                             │
│   │  6. Return Result   │ ────► Back to CLI                          │
│   └─────────────────────┘                                             │
│                                                                        │
└───────────────────────────────────────────────────────────────────────┘
```

### 5.2 Interceptor Implementation

```swift
actor RequestInterceptor {
    private let registry: ToolRegistry
    private let governance: GovernanceLayer
    private let serverManager: MCPServerManager
    private let auditLog: AuditLog

    func intercept(_ request: ToolCallRequest, from engine: EngineType) async throws -> ToolCallResponse {
        let startTime = Date()

        // 1. Find tool
        guard let tool = registry.findTool(request.name) else {
            throw MCPError.toolNotFound(request.name)
        }

        // 2. Policy check
        let decision = await governance.evaluate(
            tool: tool,
            arguments: request.arguments,
            engine: engine
        )

        switch decision {
        case .deny(let reason):
            await auditLog.record(.denied(tool: tool.name, reason: reason))
            throw MCPError.policyDenied(reason)

        case .requireConfirm:
            let approved = await governance.requestApproval(tool: tool, arguments: request.arguments)
            if !approved {
                await auditLog.record(.userDeclined(tool: tool.name))
                throw MCPError.userDeclined
            }

        case .allow:
            break
        }

        // 3. Route to server
        guard let server = serverManager.servers[tool.server],
              server.state == .ready else {
            throw MCPError.serverUnavailable(tool.server)
        }

        // 4. Execute
        let response = try await server.callTool(name: tool.name, arguments: request.arguments)

        // 5. Audit
        await auditLog.record(.executed(
            tool: tool.name,
            server: tool.server,
            duration: Date().timeIntervalSince(startTime),
            success: !response.isError
        ))

        // 6. Return
        return response
    }
}
```

### 5.3 MCP Bridge

Translates between CLI tool format and MCP:

```swift
struct MCPBridge {
    // Convert CLI tool call to MCP format
    func toMCPRequest(_ cliRequest: CLIToolCall) -> ToolCallRequest {
        ToolCallRequest(
            method: "tools/call",
            params: .init(
                name: cliRequest.toolName,
                arguments: cliRequest.arguments
            )
        )
    }

    // Convert MCP response to CLI format
    func toCLIResponse(_ mcpResponse: ToolCallResponse, engine: EngineType) -> CLIToolResult {
        switch engine {
        case .claude:
            return ClaudeToolResult(
                content: mcpResponse.content,
                isError: mcpResponse.isError ?? false
            )
        case .gemini:
            return GeminiToolResult(
                output: mcpResponse.content.first?.text ?? "",
                error: mcpResponse.isError == true ? mcpResponse.content.first?.text : nil
            )
        case .codex:
            return CodexToolResult(
                result: mcpResponse.content,
                status: mcpResponse.isError == true ? "error" : "success"
            )
        }
    }
}
```

---

## 6. Governance Layer

### 6.1 Policy Integration

MCP tools integrate with the Policy Engine:

```swift
extension PolicyEngine {
    func evaluateMCPTool(
        _ tool: RegisteredTool,
        arguments: [String: Any],
        context: EvaluationContext
    ) async -> PolicyDecision {
        // Check tool-specific policies
        if let toolPolicy = tool.policy {
            let decision = evaluate(toolPolicy, arguments: arguments)
            if decision != .allow { return decision }
        }

        // Check server-level policies
        if let serverPolicy = serverPolicies[tool.server] {
            let decision = evaluate(serverPolicy, arguments: arguments)
            if decision != .allow { return decision }
        }

        // Check global MCP policies
        return evaluate(globalMCPPolicy, tool: tool.name, arguments: arguments)
    }
}
```

### 6.2 Approval Workflows

```swift
struct MCPApprovalRequest: Identifiable {
    let id: UUID
    let tool: RegisteredTool
    let arguments: [String: Any]
    let engine: EngineType
    let sessionId: UUID
    let timestamp: Date

    var displayTitle: String {
        "Allow \(tool.name)?"
    }

    var displayDetails: String {
        "Server: \(tool.server)\nArguments: \(formattedArguments)"
    }
}

enum ApprovalScope {
    case once                // This invocation only
    case session             // All invocations this session
    case project             // All invocations in this project
    case always              // Remember forever
    case alwaysForPattern    // Remember for this tool + argument pattern
}
```

### 6.3 Audit Logging

```swift
struct MCPAuditEntry: Codable {
    let id: UUID
    let timestamp: Date
    let sessionId: UUID
    let engine: EngineType
    let toolName: String
    let serverName: String
    let arguments: [String: Any]
    let decision: PolicyDecision
    let approvalScope: ApprovalScope?
    let duration: TimeInterval?
    let success: Bool?
    let errorMessage: String?
}

actor MCPAuditLog {
    private let store: LanceDBStore

    func record(_ entry: MCPAuditEntry) async {
        try? await store.insert(entry)
    }

    func query(
        tool: String? = nil,
        server: String? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) async -> [MCPAuditEntry] {
        // Vector search + filters
    }
}
```

---

## 7. UI Components

### 7.1 Server Management Panel

```
┌─────────────────────────────────────────────────────────────────────┐
│  MCP Servers                                           [+ Add Server]│
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ● filesystem          Ready    12 tools    [Configure] [Stop]      │
│    /Users/me/projects                                                │
│                                                                      │
│  ● github              Ready     8 tools    [Configure] [Stop]      │
│    owner/repo1, owner/repo2                                          │
│                                                                      │
│  ○ slack               Stopped   0 tools    [Configure] [Start]     │
│    Not authenticated                                                 │
│                                                                      │
│  ◐ database            Starting  - tools    [Configure] [Cancel]    │
│    Connecting to localhost:5432...                                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.2 Tool Browser

```
┌─────────────────────────────────────────────────────────────────────┐
│  Available Tools                        [Search tools...]           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  filesystem (12 tools)                                    [▼]       │
│  ├── read_file          Read contents of a file          [✓]       │
│  ├── write_file         Write contents to a file         [✓]       │
│  ├── list_directory     List directory contents          [✓]       │
│  └── ...                                                             │
│                                                                      │
│  github (8 tools)                                         [▼]       │
│  ├── create_issue       Create a new GitHub issue        [✓]       │
│  ├── list_prs           List pull requests               [✓]       │
│  ├── read_file ⚠️       Read file from repo (conflict)   [○]       │
│  └── ...                                                             │
│                                                                      │
│  ─────────────────────────────────────────────────────────────────  │
│  Tool Details: read_file (filesystem)                                │
│                                                                      │
│  Description: Read the contents of a file at the specified path     │
│                                                                      │
│  Input Schema:                                                       │
│    path (string, required): Absolute path to the file               │
│                                                                      │
│  Policy: require_confirm for paths outside project                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.3 Tool Approval Dialog

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Tool Approval Request                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Claude wants to use: create_issue                                   │
│  Server: github                                                      │
│                                                                      │
│  Arguments:                                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ repo: "owner/my-repo"                                        │   │
│  │ title: "Fix bug in authentication"                           │   │
│  │ body: "The login flow fails when..."                         │   │
│  │ labels: ["bug", "auth"]                                      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  Remember this decision:                                             │
│  ○ Just this once                                                    │
│  ○ For this session                                                  │
│  ● For this project                                                  │
│  ○ Always allow create_issue                                         │
│                                                                      │
│                          [Deny]    [Allow]                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Implementation

### 8.1 File Structure

```
Sources/
  MCP/
    Protocol/
      MCPTypes.swift              # Protocol types
      MCPTransport.swift          # stdio/SSE transport
      MCPCodec.swift              # JSON-RPC encoding
    Server/
      MCPServer.swift             # Single server wrapper
      MCPServerManager.swift      # Multi-server management
      MCPServerConfig.swift       # Configuration types
      MCPHealthMonitor.swift      # Health checking
    Registry/
      ToolRegistry.swift          # Unified tool registry
      ConflictResolver.swift      # Naming conflicts
      ResourceRegistry.swift      # Resource management
    Interception/
      RequestInterceptor.swift    # Tool call interception
      MCPBridge.swift             # CLI <-> MCP translation
      ResponseTransformer.swift   # Response formatting
    Governance/
      MCPPolicyIntegration.swift  # Policy engine hooks
      MCPApprovalFlow.swift       # Approval UI flows
      MCPAuditLog.swift           # Audit logging
    UI/
      ServerManagementView.swift  # Server panel
      ToolBrowserView.swift       # Tool explorer
      ApprovalDialogView.swift    # Approval requests
```

### 8.2 Phase Implementation

| Phase | Deliverable |
|-------|-------------|
| **Phase 1** | Server spawning, tool discovery, basic passthrough |
| **Phase 2** | Request interception, policy integration |
| **Phase 3** | Approval workflows, audit logging, UI panels |
| **Phase 4** | Conflict resolution UI, server marketplace |

### 8.3 Testing Strategy

```swift
// Mock MCP server for testing
class MockMCPServer: MCPServerProtocol {
    var tools: [MCPTool]
    var callHandler: ((String, [String: Any]) -> ToolCallResponse)?

    func listTools() async -> [MCPTool] { tools }
    func callTool(name: String, arguments: [String: Any]) async throws -> ToolCallResponse {
        callHandler?(name, arguments) ?? .init(content: [])
    }
}

// Integration tests
func testToolCallInterception() async {
    let mockServer = MockMCPServer(tools: [readFileTool])
    mockServer.callHandler = { name, args in
        ToolCallResponse(content: [.text("file contents")])
    }

    let interceptor = RequestInterceptor(
        registry: registry,
        governance: MockGovernance(decision: .allow),
        serverManager: MockServerManager(servers: ["test": mockServer])
    )

    let response = try await interceptor.intercept(
        ToolCallRequest(name: "read_file", arguments: ["path": "/test"]),
        from: .claude
    )

    XCTAssertEqual(response.content.first?.text, "file contents")
}

func testPolicyDenial() async {
    let interceptor = RequestInterceptor(
        governance: MockGovernance(decision: .deny("Not allowed"))
    )

    do {
        try await interceptor.intercept(dangerousRequest, from: .claude)
        XCTFail("Should have thrown")
    } catch MCPError.policyDenied(let reason) {
        XCTAssertEqual(reason, "Not allowed")
    }
}
```

### 8.4 Dependencies

| Component | Dependency | Purpose |
|-----------|------------|---------|
| Transport | Foundation.Process, Pipe | stdio communication |
| Protocol | JSONDecoder/Encoder | JSON-RPC messages |
| Async | Swift Concurrency | Actor-based isolation |
| UI | SwiftUI | Server management views |

---

## Appendix A: MCP Server Examples

### A.1 Adding a Custom MCP Server

```json
{
  "servers": {
    "my-custom-server": {
      "command": "/path/to/my-server",
      "args": ["--config", "~/.myserver/config.json"],
      "env": {
        "API_KEY": "${secrets.MY_API_KEY}"
      },
      "enabled": true,
      "permissions": {
        "network": ["api.example.com"],
        "fileRead": ["~/.myserver/*"]
      }
    }
  }
}
```

### A.2 Tool Policy Override

```json
{
  "toolPolicies": {
    "github/create_issue": {
      "action": "require_confirm",
      "message": "Creating GitHub issues requires approval"
    },
    "filesystem/write_file": {
      "action": "allow",
      "conditions": {
        "path": { "startsWith": "${project.path}" }
      },
      "fallback": "require_confirm"
    }
  }
}
```

---

## Appendix B: Troubleshooting

### B.1 Server Won't Start

1. Check server command exists: `which npx`
2. Verify MCP server package: `npx -y @anthropic/mcp-server-filesystem --help`
3. Check logs: `~/.blaze/logs/mcp-servers.log`
4. Verify environment variables are set

### B.2 Tool Not Appearing

1. Ensure server is in `ready` state
2. Check tool is enabled in Tool Browser
3. Verify no naming conflict hiding it
4. Check policy isn't blocking exposure

### B.3 Approval Dialog Not Showing

1. Verify `require_confirm` policy is set
2. Check Blaze window is in foreground
3. Look for notification in system tray
4. Check audit log for automatic approvals
