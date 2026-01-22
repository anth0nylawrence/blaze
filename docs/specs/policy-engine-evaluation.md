# Policy Engine Evaluation Specification

> **Status:** `Draft` | **Last Updated:** 2025-12-30 | **Version:** 1.0

---

## Executive Summary

The Policy Engine is the safety layer that evaluates rules to decide if AI actions should be allowed, denied, or require user approval. This specification defines the rule matching algorithm, scope resolution, approval workflows, and audit logging.

**Why This Matters:** Users must trust that Blaze won't let AI do dangerous things. Without clear evaluation logic, the policy system will be inconsistent and unsafe.

---

## Table of Contents

1. [Core Concepts](#1-core-concepts)
2. [Rule Types & Matching](#2-rule-types--matching)
3. [Evaluation Algorithm](#3-evaluation-algorithm)
4. [Scope Resolution](#4-scope-resolution)
5. [Approval Workflows](#5-approval-workflows)
6. [Audit Logging](#6-audit-logging)
7. [Policy Pack Format](#7-policy-pack-format)
8. [Implementation](#8-implementation)

---

## 1. Core Concepts

### 1.1 What is a Policy?

A **Policy** is a named collection of rules that govern AI behavior. Policies can be:

- **Global**: Apply to all projects
- **Project-scoped**: Apply to a specific project
- **Session-scoped**: Apply to the current session only

### 1.2 What is a Rule?

A **Rule** is a single condition-action pair:

```
IF [condition matches] THEN [take action]
```

Actions:
- `allow` - Permit the action silently
- `deny` - Block the action with explanation
- `require_confirm` - Show approval dialog before proceeding

### 1.3 Evaluation Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     POLICY EVALUATION FLOW                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   AI Action (e.g., bash command, file write)                        │
│        │                                                             │
│        ▼                                                             │
│   ┌─────────────────┐                                               │
│   │ Extract Context │  tool name, arguments, file path, etc.       │
│   └────────┬────────┘                                               │
│            │                                                         │
│            ▼                                                         │
│   ┌─────────────────┐                                               │
│   │ Load Policies   │  global → project → session (priority order) │
│   └────────┬────────┘                                               │
│            │                                                         │
│            ▼                                                         │
│   ┌─────────────────┐                                               │
│   │ Check Approvals │  cached decisions from previous approvals    │
│   └────────┬────────┘                                               │
│            │                                                         │
│       ┌────┴────┐                                                   │
│       │ Cached? │                                                   │
│       └────┬────┘                                                   │
│       Yes  │  No                                                    │
│        │   │                                                         │
│        │   ▼                                                         │
│        │  ┌─────────────────┐                                       │
│        │  │ Evaluate Rules  │  first match wins                     │
│        │  └────────┬────────┘                                       │
│        │           │                                                 │
│        │           ▼                                                 │
│        │  ┌─────────────────┐                                       │
│        │  │ Apply Decision  │  allow / deny / require_confirm       │
│        │  └────────┬────────┘                                       │
│        │           │                                                 │
│        └───────────┤                                                 │
│                    ▼                                                 │
│           ┌─────────────────┐                                       │
│           │  Log Decision   │  audit trail                          │
│           └─────────────────┘                                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Rule Types & Matching

### 2.1 Rule Type Taxonomy

| Rule Type | Applies To | Match Field | Example |
|-----------|------------|-------------|---------|
| `deny_file_write` | File write operations | File path glob | `**/.env*` |
| `deny_file_read` | File read operations | File path glob | `**/secrets/**` |
| `deny_bash` | Bash commands | Command pattern | `rm -rf` |
| `require_confirm_bash` | Bash commands | Command pattern | `git push` |
| `allow_bash` | Bash commands | Command pattern | `git status` |
| `deny_tool` | Any tool call | Tool name | `WebFetch` |
| `require_confirm_tool` | Any tool call | Tool name | `Write` |
| `deny_mcp` | MCP tool calls | MCP server/tool | `database/*` |

### 2.2 Glob Pattern Matching

For file paths, we use **Unix glob patterns** (not regex):

| Pattern | Matches | Does Not Match |
|---------|---------|----------------|
| `*.env` | `.env`, `local.env` | `.env.example` (different extension) |
| `**/.env*` | `.env`, `dir/.env`, `.env.local` | `env.txt` |
| `src/**/*.ts` | `src/a.ts`, `src/deep/b.ts` | `test/a.ts` |
| `**/node_modules/**` | Any path containing `node_modules` | - |

**Implementation:** Use Swift's `fnmatch()` or equivalent with `FNM_PATHNAME` flag.

### 2.3 Command Pattern Matching

For bash commands, we use **substring matching with word boundaries**:

| Pattern | Matches | Does Not Match |
|---------|---------|----------------|
| `rm -rf` | `rm -rf .`, `rm -rf /tmp` | `rm file.txt` |
| `git push` | `git push origin`, `git push --force` | `git status` |
| `npm publish` | `npm publish`, `npm publish --tag` | `npm install` |
| `sudo` | `sudo rm`, `sudo apt` | `sudoku` (different word) |

**Implementation:** Split command into tokens, check if pattern tokens appear in sequence.

```swift
func matchesCommandPattern(_ command: String, pattern: String) -> Bool {
    let commandTokens = command.split(separator: " ").map(String.init)
    let patternTokens = pattern.split(separator: " ").map(String.init)

    guard let firstIndex = commandTokens.firstIndex(of: patternTokens[0]) else {
        return false
    }

    // Check if all pattern tokens appear in sequence
    for (offset, token) in patternTokens.enumerated() {
        let idx = firstIndex + offset
        guard idx < commandTokens.count, commandTokens[idx] == token else {
            return false
        }
    }
    return true
}
```

### 2.4 Rule Priority Order

When multiple rules could match, the **first matching rule wins** (top-to-bottom evaluation):

```json
{
  "rules": [
    { "type": "allow_bash", "pattern": "git status" },     // Rule 1
    { "type": "deny_bash", "pattern": "git" },             // Rule 2
    { "type": "require_confirm_bash", "pattern": "git push" } // Rule 3 (never reached)
  ]
}
```

For `git status`: Rule 1 matches → **allow**
For `git push`: Rule 2 matches → **deny** (Rule 3 never evaluated)

**Best Practice:** Order rules from most specific to least specific.

---

## 3. Evaluation Algorithm

### 3.1 Pseudocode

```swift
func evaluate(action: AIAction, context: EvaluationContext) -> PolicyDecision {
    // Step 1: Check cached approvals
    if let cached = approvalCache.get(action, context) {
        if cached.isValid {
            logDecision(action, .cached(cached.decision))
            return cached.decision
        }
    }

    // Step 2: Load policies in priority order
    let policies = loadPolicies(context)
    // Order: session-scoped → project-scoped → global

    // Step 3: Flatten all rules with policy context
    let allRules = policies.flatMap { policy in
        policy.rules.map { rule in
            EvaluatableRule(rule: rule, policy: policy)
        }
    }

    // Step 4: Evaluate rules in order (first match wins)
    for evaluatableRule in allRules {
        if evaluatableRule.matches(action) {
            let decision = evaluatableRule.action
            logDecision(action, .matched(evaluatableRule))
            return decision
        }
    }

    // Step 5: No rule matched → apply mode default
    let defaultDecision = context.trustMode.defaultDecision(for: action)
    logDecision(action, .default(defaultDecision))
    return defaultDecision
}
```

### 3.2 Mode Defaults

When no rule matches, the trust mode determines the default:

| Trust Mode | File Write | File Read | Bash | Tool Call |
|------------|------------|-----------|------|-----------|
| **Review** (default) | `require_confirm` | `allow` | `require_confirm` | `allow` |
| **Trusted** | `allow` | `allow` | `allow` | `allow` |
| **Sandbox** | `deny` | `allow` | `deny` | `deny` (except safe tools) |

**Safe Tools in Sandbox Mode:**
- `Read` (file reading)
- `Glob` (file pattern matching)
- `Grep` (content search)
- `WebSearch` (read-only)

### 3.3 Action Extraction

Before evaluation, extract structured data from the action:

```swift
struct AIAction {
    let toolName: String        // "bash", "Write", "Edit", etc.
    let arguments: [String: Any] // Tool-specific arguments
    let timestamp: Date
    let sessionId: Session.ID

    // Derived properties for matching
    var filePath: String? { arguments["file_path"] as? String }
    var command: String? { arguments["command"] as? String }
    var mcpServer: String? { /* extract from MCP tool name */ }
}
```

---

## 4. Scope Resolution

### 4.1 Policy Scope Hierarchy

Policies are evaluated in order of specificity:

```
Session Policies  (most specific - current session overrides)
       ↓
Project Policies  (project-level rules)
       ↓
Global Policies   (user defaults)
       ↓
Built-in Policies (system defaults, lowest priority)
```

### 4.2 Merging Rules

All rules from all applicable policies are **concatenated** (not merged):

```swift
func loadPolicies(_ context: EvaluationContext) -> [Policy] {
    var policies: [Policy] = []

    // 1. Session policies (highest priority)
    if let sessionPolicies = context.session.policies {
        policies.append(contentsOf: sessionPolicies)
    }

    // 2. Project policies
    if let projectPolicies = context.project.policies {
        policies.append(contentsOf: projectPolicies)
    }

    // 3. Global policies
    policies.append(contentsOf: globalPolicyStore.enabledPolicies)

    // 4. Built-in policies (always last)
    policies.append(builtInSafetyPolicy)

    return policies
}
```

### 4.3 Rule Overrides

A higher-priority policy can override a lower-priority rule:

**Global Policy:**
```json
{ "type": "deny_bash", "pattern": "rm -rf", "reason": "Destructive command" }
```

**Project Policy (higher priority):**
```json
{ "type": "allow_bash", "pattern": "rm -rf ./build", "reason": "Build cleanup allowed" }
```

Result: `rm -rf ./build` is allowed (project rule matches first)

---

## 5. Approval Workflows

### 5.1 Approval Scopes

When `require_confirm` action fires, user chooses a scope:

| Scope | Duration | Storage |
|-------|----------|---------|
| `once` | This specific action only | In-memory (session) |
| `session` | All matching actions this session | In-memory (session) |
| `project` | All matching actions in this project | LanceDB (persistent) |
| `always` | Add to permanent allowlist | LanceDB (persistent) |

### 5.2 Approval Cache Structure

```swift
struct ApprovalDecision {
    let id: UUID
    let actionHash: String        // Hash of action for matching
    let scope: ApprovalScope
    let decision: Decision        // allow or deny
    let reason: String?
    let createdAt: Date
    let expiresAt: Date?
    let sessionId: Session.ID?
    let projectId: Project.ID?
}

enum ApprovalScope: String, Codable {
    case once
    case session
    case project
    case always
}
```

### 5.3 Cache Lookup

```swift
func getCachedApproval(for action: AIAction, context: EvaluationContext) -> ApprovalDecision? {
    let hash = action.computeHash()

    // Check in order: session → project → global

    // Session-scoped approvals (in-memory)
    if let sessionApproval = sessionApprovalCache[hash] {
        if sessionApproval.sessionId == context.session.id {
            return sessionApproval
        }
    }

    // Project-scoped approvals (persistent)
    if let projectApproval = approvalStore.find(hash: hash, projectId: context.project.id) {
        if !projectApproval.isExpired {
            return projectApproval
        }
    }

    // Global approvals (persistent)
    if let globalApproval = approvalStore.find(hash: hash, scope: .always) {
        if !globalApproval.isExpired {
            return globalApproval
        }
    }

    return nil
}
```

### 5.4 Approval Expiration

| Scope | Expires |
|-------|---------|
| `once` | Immediately after use |
| `session` | When session ends |
| `project` | Never (until manually revoked) |
| `always` | Never (until manually revoked) |

### 5.5 Timeout Handling

If user doesn't respond to approval prompt:

- **Default timeout:** 60 seconds
- **Timeout action:** `deny` (safe default)
- **UI feedback:** Show countdown timer
- **Retry:** User can re-trigger the action

```swift
func showApprovalDialog(for action: AIAction, timeout: TimeInterval = 60) async -> ApprovalResult {
    return await withTimeout(timeout) {
        await approvalUI.present(action)
    } onTimeout: {
        logDecision(action, .timeout)
        return .deny(reason: "Approval timed out")
    }
}
```

---

## 6. Audit Logging

### 6.1 What Gets Logged

Every policy evaluation is logged:

```swift
struct PolicyAuditEntry {
    let id: UUID
    let timestamp: Date
    let sessionId: Session.ID
    let actionType: String        // "bash", "file_write", etc.
    let actionSummary: String     // Sanitized summary (no secrets)
    let decision: Decision
    let decisionSource: DecisionSource
    let matchedRuleId: String?
    let matchedPolicyId: String?
    let approvalScope: ApprovalScope?
}

enum DecisionSource: String, Codable {
    case rule         // Matched a specific rule
    case cached       // Used cached approval
    case modeDefault  // No rule matched, used mode default
    case timeout      // Approval timed out
}
```

### 6.2 Sanitization

**Never log:**
- Full file contents
- API keys, tokens, passwords
- Full command output

**Always log:**
- Tool name
- File path (but not contents)
- Command (first 200 chars, secrets redacted)
- Decision and reason

```swift
func sanitize(_ command: String) -> String {
    var sanitized = command.prefix(200)

    // Redact patterns
    let secretPatterns = [
        #"(api[_-]?key|apikey)\s*[:=]\s*['\"][^'\"]+['\"]"#,
        #"(password|passwd|pwd)\s*[:=]\s*['\"][^'\"]+['\"]"#,
        #"sk-[a-zA-Z0-9]{32,}"#,
        #"ghp_[a-zA-Z0-9]{36}"#
    ]

    for pattern in secretPatterns {
        sanitized = sanitized.replacingOccurrences(
            of: pattern,
            with: "[REDACTED]",
            options: .regularExpression
        )
    }

    return String(sanitized)
}
```

### 6.3 Audit Query API

```swift
protocol AuditStore {
    func query(
        sessionId: Session.ID?,
        projectId: Project.ID?,
        decision: Decision?,
        dateRange: ClosedRange<Date>?
    ) async -> [PolicyAuditEntry]

    func export(format: ExportFormat) async -> Data
}

enum ExportFormat {
    case json
    case csv
}
```

---

## 7. Policy Pack Format

### 7.1 Policy JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["name", "version", "rules"],
  "properties": {
    "name": {
      "type": "string",
      "description": "Human-readable policy name"
    },
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$",
      "description": "Semantic version"
    },
    "description": {
      "type": "string"
    },
    "author": {
      "type": "string"
    },
    "rules": {
      "type": "array",
      "items": {
        "$ref": "#/definitions/Rule"
      }
    }
  },
  "definitions": {
    "Rule": {
      "type": "object",
      "required": ["type", "reason"],
      "properties": {
        "type": {
          "enum": [
            "deny_file_write",
            "deny_file_read",
            "deny_bash",
            "require_confirm_bash",
            "allow_bash",
            "deny_tool",
            "require_confirm_tool",
            "deny_mcp"
          ]
        },
        "glob": {
          "type": "string",
          "description": "File path glob pattern"
        },
        "pattern": {
          "type": "string",
          "description": "Command or tool pattern"
        },
        "tool": {
          "type": "string",
          "description": "Tool name for tool rules"
        },
        "reason": {
          "type": "string",
          "description": "Human-readable explanation"
        },
        "overridable": {
          "type": "boolean",
          "default": true,
          "description": "Can user approve this action?"
        }
      }
    }
  }
}
```

### 7.2 Built-in Policy Presets

**Paranoid Mode:**
```json
{
  "name": "Paranoid",
  "version": "1.0.0",
  "description": "Maximum safety - confirm everything",
  "rules": [
    { "type": "require_confirm_bash", "pattern": "", "reason": "All bash commands require approval" },
    { "type": "require_confirm_tool", "tool": "Write", "reason": "All file writes require approval" },
    { "type": "require_confirm_tool", "tool": "Edit", "reason": "All file edits require approval" },
    { "type": "deny_bash", "pattern": "rm -rf", "reason": "Recursive delete blocked", "overridable": false }
  ]
}
```

**Safe Default:**
```json
{
  "name": "Safe Default",
  "version": "1.0.0",
  "description": "Balanced safety for everyday use",
  "rules": [
    { "type": "deny_file_write", "glob": "**/.env*", "reason": "Secrets file" },
    { "type": "deny_file_write", "glob": "**/credentials*", "reason": "Credentials file" },
    { "type": "deny_bash", "pattern": "rm -rf /", "reason": "System destruction", "overridable": false },
    { "type": "require_confirm_bash", "pattern": "git push", "reason": "Network side effect" },
    { "type": "require_confirm_bash", "pattern": "npm publish", "reason": "Public package release" },
    { "type": "require_confirm_bash", "pattern": "docker push", "reason": "Image publish" }
  ]
}
```

**Fast/Trusted:**
```json
{
  "name": "Fast/Trusted",
  "version": "1.0.0",
  "description": "Minimal interruptions for experienced users",
  "rules": [
    { "type": "deny_bash", "pattern": "rm -rf /", "reason": "System destruction", "overridable": false },
    { "type": "deny_file_write", "glob": "**/.env*", "reason": "Secrets file" }
  ]
}
```

### 7.3 Policy Pack Signature (Future)

For policy marketplace distribution, packs should be signed:

```json
{
  "policy": { /* policy content */ },
  "signature": {
    "algorithm": "ed25519",
    "publicKey": "...",
    "value": "..."
  }
}
```

---

## 8. Implementation

### 8.1 Swift Types

```swift
// Core types
struct Policy: Identifiable, Codable {
    let id: UUID
    var name: String
    var version: String
    var description: String?
    var rules: [Rule]
    var enabled: Bool
    var scope: PolicyScope
    let createdAt: Date
    var updatedAt: Date
}

enum PolicyScope: String, Codable {
    case global
    case project
    case session
}

struct Rule: Identifiable, Codable {
    let id: UUID
    let type: RuleType
    let pattern: String?
    let glob: String?
    let tool: String?
    let reason: String
    let overridable: Bool
}

enum RuleType: String, Codable {
    case denyFileWrite = "deny_file_write"
    case denyFileRead = "deny_file_read"
    case denyBash = "deny_bash"
    case requireConfirmBash = "require_confirm_bash"
    case allowBash = "allow_bash"
    case denyTool = "deny_tool"
    case requireConfirmTool = "require_confirm_tool"
    case denyMcp = "deny_mcp"
}

enum Decision {
    case allow
    case deny(reason: String)
    case requireConfirm(reason: String)
}
```

### 8.2 PolicyEngine Actor

```swift
@MainActor
final class PolicyEngine: ObservableObject {
    @Published private(set) var globalPolicies: [Policy] = []
    @Published private(set) var evaluationStats: EvaluationStats = .empty

    private let store: PolicyStore
    private let approvalCache: ApprovalCache
    private let auditLog: AuditLog

    init(store: PolicyStore, auditLog: AuditLog) {
        self.store = store
        self.approvalCache = ApprovalCache()
        self.auditLog = auditLog
    }

    func evaluate(
        action: AIAction,
        session: Session,
        project: Project
    ) async -> PolicyDecision {
        let context = EvaluationContext(
            session: session,
            project: project,
            trustMode: project.trustMode
        )

        // Check cache first
        if let cached = approvalCache.get(action: action, context: context) {
            await auditLog.record(action: action, decision: cached.decision, source: .cached)
            return cached.decision
        }

        // Load and evaluate policies
        let policies = await loadPolicies(context: context)
        let decision = evaluateRules(action: action, policies: policies, context: context)

        // Log decision
        await auditLog.record(action: action, decision: decision, source: .rule)

        return decision
    }

    func recordApproval(
        action: AIAction,
        decision: Decision,
        scope: ApprovalScope,
        context: EvaluationContext
    ) async {
        let approval = ApprovalDecision(
            id: UUID(),
            actionHash: action.computeHash(),
            scope: scope,
            decision: decision,
            createdAt: Date(),
            sessionId: scope == .session ? context.session.id : nil,
            projectId: scope == .project ? context.project.id : nil
        )

        switch scope {
        case .once:
            // Don't cache
            break
        case .session:
            approvalCache.set(approval)
        case .project, .always:
            await store.saveApproval(approval)
        }

        await auditLog.record(action: action, decision: decision, source: .approval(scope))
    }
}
```

### 8.3 Integration Points

**With EngineAdapter:**
```swift
// In ClaudeCodeAdapter
func handlePreToolUse(_ event: PreToolUseEvent) async -> ToolUseDecision {
    let action = AIAction(from: event)
    let decision = await policyEngine.evaluate(
        action: action,
        session: currentSession,
        project: currentProject
    )

    switch decision {
    case .allow:
        return .proceed
    case .deny(let reason):
        return .block(reason: reason)
    case .requireConfirm(let reason):
        return await showApprovalUI(action: action, reason: reason)
    }
}
```

**With SessionStore:**
```swift
// Load session-scoped policies
let sessionPolicies = await sessionStore.getPolicies(for: session.id)
```

---

## Acceptance Criteria

- [ ] All rule types implemented with correct matching
- [ ] Scope resolution works correctly (session > project > global)
- [ ] Approval cache persists across app restarts (for project/always scopes)
- [ ] Audit log captures all decisions
- [ ] Built-in presets available (Paranoid, Safe Default, Fast/Trusted)
- [ ] Policy import/export works
- [ ] Timeout handling works correctly
- [ ] No secrets logged in audit trail

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-30 | Initial specification |
