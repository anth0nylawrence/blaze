# Recipe Execution Engine Specification

> **Status:** `Draft` | **Last Updated:** 2025-12-30 | **Version:** 1.0

---

## Executive Summary

The Recipe Execution Engine enables users to define and run reusable workflows ranging from simple prompt templates to complex multi-step automations. Using a **progressive unlock** model, recipes start as single-session workflows and evolve to support cross-session orchestration in later phases.

**Why This Matters:** Power users repeat the same workflows constantly (code review, test writing, refactoring). Without recipes, they manually re-type prompts. With recipes, they automate workflows, share patterns with teams, and build on community recipes.

---

## Table of Contents

1. [Recipe Tiers](#1-recipe-tiers)
2. [Recipe Format](#2-recipe-format)
3. [Execution Model](#3-execution-model)
4. [Variable System](#4-variable-system)
5. [Control Flow](#5-control-flow)
6. [Approval Gates](#6-approval-gates)
7. [Recipe Management](#7-recipe-management)
8. [UI Components](#8-ui-components)
9. [Implementation Phases](#9-implementation-phases)

---

## 1. Recipe Tiers

### 1.1 Progressive Unlock Model

Recipes are organized in tiers that unlock progressively:

| Tier | Name | Complexity | Phase |
|------|------|------------|-------|
| **T1** | Prompt Templates | Variables in prompts | Phase 1 |
| **T2** | Multi-Step Workflows | Sequential steps with state | Phase 2 |
| **T3** | Conditional Workflows | Branching and loops | Phase 3 |
| **T4** | Cross-Session Orchestration | Parallel sessions, aggregation | Phase 4 |

### 1.2 Tier Capabilities

```
┌─────────────────────────────────────────────────────────────────────┐
│                      RECIPE TIER CAPABILITIES                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  T1: Prompt Templates                                                │
│  ├── Variable substitution: {{filename}}, {{language}}              │
│  ├── Input prompts: Ask user for values                             │
│  └── Single turn execution                                           │
│                                                                      │
│  T2: Multi-Step Workflows                                            │
│  ├── All T1 features                                                 │
│  ├── Sequential steps with named outputs                             │
│  ├── Step dependencies: use output from previous step               │
│  └── State persistence across steps                                  │
│                                                                      │
│  T3: Conditional Workflows                                           │
│  ├── All T2 features                                                 │
│  ├── if/else branching on conditions                                │
│  ├── while/for loops with iteration limits                          │
│  ├── Error handling: try/catch/retry                                │
│  └── Sub-recipe calls                                                │
│                                                                      │
│  T4: Cross-Session Orchestration                                     │
│  ├── All T3 features                                                 │
│  ├── Spawn parallel sessions                                         │
│  ├── Fan-out/fan-in patterns                                        │
│  ├── Result aggregation                                              │
│  └── Coordinator session management                                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.3 Tier Selection

Blaze automatically determines recipe tier from its definition:

```swift
enum RecipeTier: Int, Comparable {
    case template = 1
    case multiStep = 2
    case conditional = 3
    case orchestration = 4

    static func detect(from recipe: Recipe) -> RecipeTier {
        if recipe.steps.count == 1 && !recipe.hasControlFlow {
            return .template
        }
        if recipe.spawnsSubSessions {
            return .orchestration
        }
        if recipe.hasControlFlow {
            return .conditional
        }
        return .multiStep
    }
}
```

---

## 2. Recipe Format

### 2.1 YAML Schema

Recipes are defined in YAML format:

```yaml
# ~/.blaze/recipes/code-review.yaml
name: code-review
version: "1.0"
description: Review code changes with structured feedback
tier: 2  # Auto-detected if omitted

# Input variables
inputs:
  - name: file_path
    type: string
    description: Path to file to review
    required: true
  - name: focus_areas
    type: array
    items: string
    default: ["bugs", "style", "performance"]
  - name: severity_threshold
    type: enum
    values: [low, medium, high]
    default: medium

# Recipe steps
steps:
  - id: read_file
    prompt: |
      Read the file at {{file_path}} and understand its structure.
    outputs:
      - name: file_content
        extract: "content"

  - id: analyze
    prompt: |
      Review this code for issues:

      ```
      {{steps.read_file.file_content}}
      ```

      Focus areas: {{focus_areas | join(", ")}}
      Report issues at {{severity_threshold}} severity or above.
    outputs:
      - name: issues
        extract: "json_array"

  - id: summarize
    prompt: |
      Summarize the {{issues | length}} issues found:
      {{issues | json}}

      Format as a markdown checklist.

# Metadata
metadata:
  author: "Blaze Team"
  tags: ["code-review", "quality"]
  category: "development"
```

### 2.2 Recipe Types

```swift
struct Recipe: Identifiable, Codable {
    let id: UUID
    let name: String
    let version: String
    let description: String
    let tier: RecipeTier?        // Auto-detect if nil
    let inputs: [RecipeInput]
    let steps: [RecipeStep]
    let metadata: RecipeMetadata

    var effectiveTier: RecipeTier {
        tier ?? RecipeTier.detect(from: self)
    }
}

struct RecipeInput: Codable {
    let name: String
    let type: InputType
    let description: String?
    let required: Bool
    let `default`: AnyCodable?
    let validation: InputValidation?
}

enum InputType: String, Codable {
    case string
    case number
    case boolean
    case array
    case `enum`
    case file        // File picker
    case directory   // Directory picker
    case code        // Code editor
}

struct RecipeStep: Identifiable, Codable {
    let id: String
    let prompt: String?
    let action: StepAction?
    let outputs: [StepOutput]?
    let condition: String?       // T3: conditional execution
    let loop: LoopConfig?        // T3: iteration
    let parallel: ParallelConfig? // T4: fan-out
}
```

### 2.3 Step Actions

Beyond prompts, steps can perform actions:

```swift
enum StepAction: Codable {
    case prompt(String)                    // Send to AI
    case tool(name: String, args: [String: Any])  // Direct tool call
    case script(command: String)           // Shell script
    case webhook(WebhookConfig)            // HTTP call
    case subRecipe(name: String, inputs: [String: Any]) // Call another recipe
    case userInput(UserInputConfig)        // Pause for user input
    case approval(ApprovalConfig)          // Approval gate
}
```

---

## 3. Execution Model

### 3.1 Execution Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     RECIPE EXECUTION FLOW                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   User triggers recipe                                               │
│        │                                                             │
│        ▼                                                             │
│   ┌─────────────────┐                                               │
│   │  Collect Inputs │  Show input form, validate                    │
│   └────────┬────────┘                                               │
│            │                                                         │
│            ▼                                                         │
│   ┌─────────────────┐                                               │
│   │  Create Context │  Initialize state, bind variables             │
│   └────────┬────────┘                                               │
│            │                                                         │
│            ▼                                                         │
│   ┌─────────────────┐                                               │
│   │  Execute Steps  │  Sequential (T1-T3) or parallel (T4)         │
│   └────────┬────────┘                                               │
│            │                                                         │
│       ┌────┴────────────┬─────────────────┐                         │
│       ▼                 ▼                 ▼                          │
│  ┌──────────┐     ┌──────────┐     ┌──────────┐                     │
│  │ Step 1   │────►│ Step 2   │────►│ Step N   │                     │
│  │ Execute  │     │ Execute  │     │ Execute  │                     │
│  │ Extract  │     │ Extract  │     │ Extract  │                     │
│  └──────────┘     └──────────┘     └──────────┘                     │
│                                           │                          │
│                                           ▼                          │
│                                   ┌─────────────────┐               │
│                                   │  Return Result  │               │
│                                   │  (final output) │               │
│                                   └─────────────────┘               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Execution Context

```swift
@MainActor
final class RecipeExecutionContext: ObservableObject {
    let recipe: Recipe
    let inputs: [String: Any]

    @Published var state: ExecutionState = .pending
    @Published var currentStepIndex: Int = 0
    @Published var stepResults: [String: StepResult] = [:]
    @Published var errors: [RecipeError] = []

    // Variable resolution
    func resolve(_ template: String) throws -> String
    func getValue(_ path: String) -> Any?
    func setValue(_ path: String, _ value: Any)

    // Step management
    func executeStep(_ step: RecipeStep) async throws -> StepResult
    func skipStep(_ stepId: String, reason: String)
    func retryStep(_ stepId: String) async throws
}

enum ExecutionState {
    case pending
    case collectingInputs
    case running(stepId: String)
    case paused(reason: PauseReason)
    case completed(result: RecipeResult)
    case failed(error: RecipeError)
    case cancelled
}

enum PauseReason {
    case awaitingApproval(ApprovalRequest)
    case awaitingUserInput(UserInputRequest)
    case rateLimit(retryAfter: TimeInterval)
    case userRequested
}
```

### 3.3 Step Execution

```swift
actor StepExecutor {
    func execute(
        step: RecipeStep,
        context: RecipeExecutionContext,
        session: Session
    ) async throws -> StepResult {
        // 1. Check condition
        if let condition = step.condition {
            let shouldRun = try context.evaluateCondition(condition)
            if !shouldRun {
                return .skipped(reason: "Condition not met: \(condition)")
            }
        }

        // 2. Resolve prompt template
        let resolvedPrompt = try context.resolve(step.prompt ?? "")

        // 3. Execute
        let response: String
        switch step.action {
        case .prompt(let template):
            let prompt = try context.resolve(template)
            response = try await session.send(prompt: prompt)

        case .tool(let name, let args):
            let resolvedArgs = try context.resolveDict(args)
            response = try await session.invokeTool(name: name, args: resolvedArgs)

        case .script(let command):
            let resolvedCmd = try context.resolve(command)
            response = try await runScript(resolvedCmd)

        case .subRecipe(let name, let inputs):
            let resolvedInputs = try context.resolveDict(inputs)
            response = try await executeSubRecipe(name, inputs: resolvedInputs)

        case .approval(let config):
            let approved = try await requestApproval(config, context: context)
            response = approved ? "approved" : "denied"

        default:
            response = ""
        }

        // 4. Extract outputs
        var outputs: [String: Any] = [:]
        for output in step.outputs ?? [] {
            outputs[output.name] = try extractOutput(response, spec: output)
        }

        // 5. Store in context
        context.stepResults[step.id] = StepResult(
            stepId: step.id,
            response: response,
            outputs: outputs,
            duration: executionTime
        )

        return .success(outputs: outputs)
    }
}
```

---

## 4. Variable System

### 4.1 Variable Scopes

Variables exist in hierarchical scopes:

| Scope | Syntax | Example |
|-------|--------|---------|
| **Input** | `{{name}}` | `{{file_path}}` |
| **Step Output** | `{{steps.stepId.output}}` | `{{steps.read_file.content}}` |
| **Environment** | `{{env.NAME}}` | `{{env.HOME}}` |
| **Built-in** | `{{blaze.xxx}}` | `{{blaze.project_path}}` |
| **Secrets** | `{{secrets.NAME}}` | `{{secrets.API_KEY}}` |

### 4.2 Template Engine

```swift
struct TemplateEngine {
    func render(_ template: String, context: RecipeExecutionContext) throws -> String {
        var result = template

        // 1. Replace simple variables: {{name}}
        result = replaceSimpleVariables(result, context: context)

        // 2. Replace step outputs: {{steps.id.output}}
        result = replaceStepOutputs(result, context: context)

        // 3. Apply filters: {{value | filter}}
        result = applyFilters(result, context: context)

        // 4. Evaluate expressions: {{value > 5}}
        result = evaluateExpressions(result, context: context)

        return result
    }
}
```

### 4.3 Filters

Jinja-style filters for transforming values:

| Filter | Example | Description |
|--------|---------|-------------|
| `upper` | `{{name \| upper}}` | Uppercase |
| `lower` | `{{name \| lower}}` | Lowercase |
| `trim` | `{{text \| trim}}` | Remove whitespace |
| `json` | `{{data \| json}}` | JSON serialize |
| `length` | `{{items \| length}}` | Array/string length |
| `join` | `{{items \| join(", ")}}` | Join array |
| `first` | `{{items \| first}}` | First element |
| `last` | `{{items \| last}}` | Last element |
| `default` | `{{value \| default("N/A")}}` | Default if nil |
| `truncate` | `{{text \| truncate(100)}}` | Truncate string |

### 4.4 Output Extraction

Steps can extract structured data from AI responses:

```swift
struct StepOutput: Codable {
    let name: String
    let extract: ExtractionMethod

    enum ExtractionMethod: String, Codable {
        case full           // Entire response
        case content        // Text content only
        case json           // Parse as JSON object
        case jsonArray      // Parse as JSON array
        case regex          // Regex capture groups
        case xpath          // XML/HTML xpath
        case jsonPath       // JSONPath query
        case codeBlock      // Extract code blocks
    }
}

// Example extractions
let outputs: [StepOutput] = [
    StepOutput(name: "summary", extract: .content),
    StepOutput(name: "issues", extract: .jsonArray),
    StepOutput(name: "code", extract: .codeBlock),
    StepOutput(name: "count", extract: .regex(pattern: "(\\d+) issues found"))
]
```

---

## 5. Control Flow

### 5.1 Conditional Execution (T3)

```yaml
steps:
  - id: check_tests
    prompt: "Are there tests for {{file_path}}?"
    outputs:
      - name: has_tests
        extract: "boolean"

  - id: write_tests
    condition: "not steps.check_tests.has_tests"
    prompt: "Write tests for {{file_path}}"

  - id: run_tests
    condition: "steps.check_tests.has_tests or steps.write_tests"
    action:
      type: tool
      name: Bash
      args:
        command: "npm test"
```

### 5.2 Loops (T3)

```yaml
steps:
  - id: get_files
    prompt: "List all TypeScript files needing review"
    outputs:
      - name: files
        extract: "json_array"

  - id: review_each
    loop:
      over: "steps.get_files.files"
      as: "current_file"
      maxIterations: 10
    prompt: |
      Review {{current_file}}:
      - Check for type safety
      - Look for potential bugs
```

### 5.3 Error Handling (T3)

```yaml
steps:
  - id: risky_operation
    prompt: "Perform complex refactoring"
    onError:
      retry:
        maxAttempts: 3
        backoffMs: [1000, 2000, 4000]
      fallback:
        stepId: manual_fallback

  - id: manual_fallback
    action:
      type: userInput
      config:
        message: "Automatic refactoring failed. Please provide manual guidance."
```

### 5.4 Control Flow Types

```swift
struct LoopConfig: Codable {
    let over: String           // Expression returning array
    let `as`: String           // Variable name for current item
    let index: String?         // Variable name for index
    let maxIterations: Int     // Safety limit
    let continueOnError: Bool  // Skip failed iterations
}

struct ConditionalConfig: Codable {
    let `if`: String           // Condition expression
    let then: [RecipeStep]     // Steps if true
    let `else`: [RecipeStep]?  // Steps if false
}

struct ErrorHandler: Codable {
    let retry: RetryConfig?
    let fallback: FallbackConfig?
    let onError: String?       // Step ID to jump to
}
```

---

## 6. Approval Gates

### 6.1 Gate Types

Recipes can pause for user approval:

```yaml
steps:
  - id: plan_changes
    prompt: "Create a plan for refactoring {{module}}"
    outputs:
      - name: plan
        extract: "content"

  - id: approve_plan
    action:
      type: approval
      config:
        title: "Approve Refactoring Plan"
        message: "Review the proposed changes before proceeding"
        showContext:
          - "steps.plan_changes.plan"
        timeout: 3600  # 1 hour
        defaultAction: deny

  - id: execute_plan
    condition: "steps.approve_plan.approved"
    prompt: "Execute the approved refactoring plan"
```

### 6.2 Approval Configuration

```swift
struct ApprovalConfig: Codable {
    let title: String
    let message: String?
    let showContext: [String]?      // Variables to display
    let timeout: TimeInterval?       // Auto-deny after timeout
    let defaultAction: ApprovalDefault
    let notifyChannels: [String]?   // Slack, email, etc.
}

enum ApprovalDefault: String, Codable {
    case allow      // Auto-approve after timeout
    case deny       // Auto-deny after timeout
    case block      // Never auto-decide
}
```

### 6.3 Batch Approvals

For recipes that generate multiple changes:

```yaml
steps:
  - id: generate_changes
    prompt: "Generate changes for all files"
    outputs:
      - name: changes
        extract: "json_array"

  - id: batch_approve
    action:
      type: approval
      config:
        mode: batch
        items: "steps.generate_changes.changes"
        allowPartial: true  # User can approve subset
        groupBy: "severity"
```

---

## 7. Recipe Management

### 7.1 Recipe Sources

```swift
enum RecipeSource {
    case builtin           // Shipped with Blaze
    case user              // ~/.blaze/recipes/
    case project           // <project>/.blaze/recipes/
    case marketplace       // Downloaded from community
    case team              // Shared via team sync
}
```

### 7.2 Recipe Registry

```swift
@MainActor
final class RecipeRegistry: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var categories: [String: [Recipe]] = [:]

    // Loading
    func loadBuiltinRecipes()
    func loadUserRecipes() throws
    func loadProjectRecipes(_ project: Project) throws

    // CRUD
    func addRecipe(_ recipe: Recipe, source: RecipeSource) throws
    func updateRecipe(_ recipe: Recipe) throws
    func deleteRecipe(_ id: UUID) throws

    // Search
    func findRecipe(name: String) -> Recipe?
    func searchRecipes(query: String) -> [Recipe]
    func filterByCategory(_ category: String) -> [Recipe]
    func filterByTier(_ tier: RecipeTier) -> [Recipe]
}
```

### 7.3 Recipe Validation

```swift
struct RecipeValidator {
    func validate(_ recipe: Recipe) throws -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Check required fields
        if recipe.name.isEmpty {
            errors.append(.missingName)
        }

        // Validate inputs
        for input in recipe.inputs {
            if input.required && input.default != nil {
                warnings.append(.requiredWithDefault(input.name))
            }
        }

        // Validate step references
        for step in recipe.steps {
            if let condition = step.condition {
                try validateExpression(condition, availableSteps: stepsBefore(step))
            }
        }

        // Check for cycles in dependencies
        try detectCycles(recipe.steps)

        // Validate tier compatibility
        let detectedTier = RecipeTier.detect(from: recipe)
        if let declaredTier = recipe.tier, declaredTier < detectedTier {
            errors.append(.tierMismatch(declared: declaredTier, detected: detectedTier))
        }

        return ValidationResult(errors: errors, warnings: warnings)
    }
}
```

### 7.4 Recipe Versioning

```swift
struct RecipeVersion: Codable, Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    var string: String { "\(major).\(minor).\(patch)" }

    static func < (lhs: RecipeVersion, rhs: RecipeVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

// Migration support
struct RecipeMigration {
    let fromVersion: RecipeVersion
    let toVersion: RecipeVersion
    let migrate: (Recipe) throws -> Recipe
}
```

---

## 8. UI Components

### 8.1 Recipe Browser

```
┌─────────────────────────────────────────────────────────────────────┐
│  Recipes                                    [Search...]   [+ New]   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Categories:  [All] [Development] [Review] [Testing] [Custom]       │
│                                                                      │
│  ─────────────────────────────────────────────────────────────────  │
│                                                                      │
│  📝 Code Review                                              T2     │
│     Review code changes with structured feedback                     │
│     [Run]  [Edit]  [Duplicate]                                      │
│                                                                      │
│  🧪 Write Tests                                              T2     │
│     Generate unit tests for a file or function                       │
│     [Run]  [Edit]  [Duplicate]                                      │
│                                                                      │
│  🔄 Refactor Component                                       T3     │
│     Safely refactor a React component                                │
│     [Run]  [Edit]  [Duplicate]                                      │
│                                                                      │
│  📦 Multi-File Migration                                     T4     │
│     Migrate multiple files to new API                                │
│     ⚠️ Requires orchestration tier (upgrade to unlock)              │
│     [View]  [Upgrade]                                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.2 Recipe Input Form

```
┌─────────────────────────────────────────────────────────────────────┐
│  Run Recipe: Code Review                                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  File Path *                                                         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ src/components/Button.tsx                           [Browse] │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  Focus Areas                                                         │
│  ☑ Bugs      ☑ Style      ☐ Performance      ☑ Security            │
│                                                                      │
│  Severity Threshold                                                  │
│  ○ Low   ● Medium   ○ High                                          │
│                                                                      │
│  ─────────────────────────────────────────────────────────────────  │
│                                                                      │
│  Steps Preview:                                                      │
│  1. read_file → Read and analyze file structure                     │
│  2. analyze → Review for issues based on focus areas                │
│  3. summarize → Generate markdown checklist                         │
│                                                                      │
│                               [Cancel]    [Run Recipe]              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.3 Execution Progress

```
┌─────────────────────────────────────────────────────────────────────┐
│  Running: Code Review                                    [Cancel]   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ✓ read_file                                           2.3s        │
│    Read src/components/Button.tsx (124 lines)                       │
│                                                                      │
│  ● analyze                                             Running...   │
│    ████████████░░░░░░░░                                45%          │
│    Reviewing for: bugs, style, security                             │
│                                                                      │
│  ○ summarize                                           Pending      │
│                                                                      │
│  ─────────────────────────────────────────────────────────────────  │
│                                                                      │
│  Live Output:                                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Found 3 issues so far:                                       │   │
│  │ - Missing prop validation on line 45                         │   │
│  │ - Unused import 'useState' on line 2                         │   │
│  │ - ...                                                        │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.4 Recipe Editor

```
┌─────────────────────────────────────────────────────────────────────┐
│  Edit Recipe: Code Review                      [Validate] [Save]    │
├──────────────────────────┬──────────────────────────────────────────┤
│  YAML Editor             │  Preview                                 │
│  ─────────────────────── │  ──────────────────────────────────────  │
│  name: code-review       │                                          │
│  version: "1.0"          │  Inputs:                                 │
│  description: Review...  │  • file_path (string, required)         │
│                          │  • focus_areas (array, optional)        │
│  inputs:                 │  • severity_threshold (enum)            │
│    - name: file_path     │                                          │
│      type: string        │  Steps:                                  │
│      required: true      │  1. read_file (prompt)                  │
│                          │  2. analyze (prompt)                     │
│  steps:                  │  3. summarize (prompt)                  │
│    - id: read_file       │                                          │
│      prompt: |           │  Detected Tier: T2 (Multi-Step)         │
│        Read the file...  │                                          │
│                          │  Validation: ✓ No errors                │
│                          │                                          │
└──────────────────────────┴──────────────────────────────────────────┘
```

---

## 9. Implementation Phases

### 9.1 Phase 1: Prompt Templates (T1)

**Timeline:** Days 46-60

| Component | Description |
|-----------|-------------|
| Recipe YAML parser | Parse T1 recipe format |
| Variable substitution | Simple `{{var}}` replacement |
| Input form generator | Auto-generate forms from schema |
| Execution engine (single step) | Execute one prompt |
| Recipe browser UI | List and run recipes |
| 5 built-in recipes | Common templates |

### 9.2 Phase 2: Multi-Step Workflows (T2)

**Timeline:** Days 61-90

| Component | Description |
|-----------|-------------|
| Step sequencing | Execute steps in order |
| Output extraction | Parse AI responses |
| Step references | `{{steps.id.output}}` syntax |
| Execution state | Track progress, allow resume |
| Progress UI | Show step-by-step progress |
| Recipe editor | Visual YAML editor |

### 9.3 Phase 3: Conditional Workflows (T3)

**Timeline:** Days 91-120

| Component | Description |
|-----------|-------------|
| Condition parser | Evaluate expressions |
| Loop execution | `for`, `while` with limits |
| Error handlers | Try/catch/retry |
| Sub-recipes | Call recipes from recipes |
| Approval gates | Pause for user approval |
| Advanced filters | Full Jinja-style filters |

### 9.4 Phase 4: Orchestration (T4)

**Timeline:** Days 121-180

| Component | Description |
|-----------|-------------|
| Session spawning | Create parallel sessions |
| Fan-out/fan-in | Distribute and collect |
| Result aggregation | Combine outputs |
| Coordinator view | Monitor parallel work |
| Cross-session state | Share data between sessions |
| Orchestration templates | Common patterns |

### 9.5 File Structure

```
Sources/
  Recipes/
    Core/
      Recipe.swift              # Recipe types
      RecipeInput.swift         # Input definitions
      RecipeStep.swift          # Step definitions
      RecipeVersion.swift       # Versioning
    Parser/
      RecipeParser.swift        # YAML parsing
      RecipeValidator.swift     # Validation
      RecipeMigrator.swift      # Version migration
    Execution/
      RecipeExecutor.swift      # Main executor
      StepExecutor.swift        # Step runner
      TemplateEngine.swift      # Variable substitution
      OutputExtractor.swift     # Response parsing
    ControlFlow/
      ConditionEvaluator.swift  # T3 conditions
      LoopExecutor.swift        # T3 loops
      ErrorHandler.swift        # T3 error handling
    Orchestration/
      SessionSpawner.swift      # T4 parallel sessions
      ResultAggregator.swift    # T4 collection
      Coordinator.swift         # T4 management
    Registry/
      RecipeRegistry.swift      # Recipe management
      RecipeSource.swift        # Source types
    UI/
      RecipeBrowserView.swift
      RecipeInputFormView.swift
      RecipeProgressView.swift
      RecipeEditorView.swift
    Builtin/
      CodeReviewRecipe.yaml
      WriteTestsRecipe.yaml
      RefactorRecipe.yaml
```

---

## Appendix A: Built-in Recipes

### A.1 Code Review

```yaml
name: code-review
description: Review code for bugs, style, and best practices
inputs:
  - name: target
    type: file
    required: true
steps:
  - id: review
    prompt: |
      Review {{target}} for:
      1. Potential bugs
      2. Style issues
      3. Performance concerns
      4. Security vulnerabilities

      Format as a checklist with severity levels.
```

### A.2 Write Tests

```yaml
name: write-tests
description: Generate unit tests for a function or file
inputs:
  - name: target
    type: file
  - name: framework
    type: enum
    values: [jest, vitest, pytest, swift-testing]
steps:
  - id: analyze
    prompt: "Analyze {{target}} and identify testable functions"
  - id: generate
    prompt: |
      Generate {{framework}} tests for:
      {{steps.analyze.functions}}

      Include edge cases and error conditions.
```

### A.3 Explain Code

```yaml
name: explain-code
description: Get a detailed explanation of code
inputs:
  - name: target
    type: file
  - name: depth
    type: enum
    values: [overview, detailed, line-by-line]
    default: detailed
steps:
  - id: explain
    prompt: |
      Explain {{target}} at {{depth}} level:
      - What it does
      - How it works
      - Key patterns used
      - Potential improvements
```

---

## Appendix B: Expression Language

### B.1 Operators

| Operator | Example | Description |
|----------|---------|-------------|
| `==` | `x == 5` | Equality |
| `!=` | `x != 5` | Inequality |
| `>`, `<` | `x > 5` | Comparison |
| `>=`, `<=` | `x >= 5` | Comparison |
| `and` | `a and b` | Logical AND |
| `or` | `a or b` | Logical OR |
| `not` | `not x` | Logical NOT |
| `in` | `x in list` | Membership |
| `+`, `-`, `*`, `/` | `a + b` | Arithmetic |

### B.2 Functions

| Function | Example | Description |
|----------|---------|-------------|
| `length(x)` | `length(items)` | Array/string length |
| `empty(x)` | `empty(list)` | Check if empty |
| `contains(a, b)` | `contains(text, "error")` | Substring check |
| `startsWith(a, b)` | `startsWith(path, "/")` | Prefix check |
| `endsWith(a, b)` | `endsWith(file, ".ts")` | Suffix check |
| `matches(a, b)` | `matches(text, "\\d+")` | Regex match |

### B.3 Examples

```yaml
# Only run if file is TypeScript
condition: "endsWith(file_path, '.ts') or endsWith(file_path, '.tsx')"

# Run while there are unprocessed items
loop:
  while: "length(remaining_items) > 0 and iteration < 10"

# Skip if already has tests
condition: "not contains(steps.check.output, 'test file exists')"
```
