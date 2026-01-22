import Foundation
import CoreGraphics

// MARK: - Hooks Pipeline

/// Visual pipeline representation for the Hooks Builder.
/// Represents a graph of event sources, filters, transforms, and actions.
public struct HooksPipeline: Codable, Sendable {
    public var nodes: [HookNode]
    public var connections: [HookConnection]

    public init(nodes: [HookNode] = [], connections: [HookConnection] = []) {
        self.nodes = nodes
        self.connections = connections
    }

    /// Export the pipeline to Claude Code settings.json format.
    /// Returns a dictionary representation compatible with .claude/settings.json hooks schema.
    public func exportToSettings() -> [String: Any] {
        var hooksDict: [String: [[String: Any]]] = [:]

        // Group nodes by event type
        let eventNodes = nodes.filter { $0.type.category == .event }

        for eventNode in eventNodes {
            guard let eventType = eventNode.eventType else { continue }

            // Find the action chain connected to this event
            let actionChain = buildActionChain(from: eventNode.id)

            if !actionChain.isEmpty {
                let hookEntry: [String: Any] = [
                    "matcher": eventNode.config["matcher"]?.value as? [String] ?? [],
                    "hooks": actionChain
                ]

                if hooksDict[eventType] == nil {
                    hooksDict[eventType] = []
                }
                hooksDict[eventType]?.append(hookEntry)
            }
        }

        return hooksDict
    }

    /// Validate the pipeline and return any errors found.
    /// Returns empty array if pipeline is valid.
    public func validate() -> [PipelineValidationError] {
        var errors: [PipelineValidationError] = []

        // Validate event nodes have event types
        for node in nodes where node.type.category == .event {
            if node.eventType == nil || node.eventType?.isEmpty == true {
                errors.append(PipelineValidationError(
                    id: UUID(),
                    message: "Event node '\(node.type.displayName)' must have an eventType specified",
                    nodeId: node.id
                ))
            }
        }

        // Validate connections reference existing nodes
        for connection in connections {
            let sourceExists = nodes.contains { $0.id == connection.sourceNodeId }
            let targetExists = nodes.contains { $0.id == connection.targetNodeId }

            if !sourceExists {
                errors.append(PipelineValidationError(
                    id: UUID(),
                    message: "Connection references non-existent source node",
                    nodeId: connection.sourceNodeId
                ))
            }

            if !targetExists {
                errors.append(PipelineValidationError(
                    id: UUID(),
                    message: "Connection references non-existent target node",
                    nodeId: connection.targetNodeId
                ))
            }
        }

        // Validate no cycles (basic check - BFS)
        for eventNode in nodes where eventNode.type.category == .event {
            if hasCycle(from: eventNode.id) {
                errors.append(PipelineValidationError(
                    id: UUID(),
                    message: "Pipeline contains a cycle starting from '\(eventNode.type.displayName)'",
                    nodeId: eventNode.id
                ))
            }
        }

        // Validate action nodes have required config
        for node in nodes where node.type.category == .action {
            switch node.type {
            case .command:
                if node.config["command"] == nil {
                    errors.append(PipelineValidationError(
                        id: UUID(),
                        message: "Command action must have 'command' field configured",
                        nodeId: node.id
                    ))
                }
            case .prompt:
                if node.config["message"] == nil && node.config["prompt"] == nil {
                    errors.append(PipelineValidationError(
                        id: UUID(),
                        message: "Prompt action must have 'message' or 'prompt' field configured",
                        nodeId: node.id
                    ))
                }
            case .agent:
                if node.config["skill"] == nil && node.config["agent"] == nil {
                    errors.append(PipelineValidationError(
                        id: UUID(),
                        message: "Agent action must have 'skill' or 'agent' field configured",
                        nodeId: node.id
                    ))
                }
            default:
                break
            }
        }

        return errors
    }

    // MARK: - Private Helpers

    private func buildActionChain(from nodeId: UUID) -> [[String: Any]] {
        var chain: [[String: Any]] = []
        var visited = Set<UUID>()
        var queue = [nodeId]

        while !queue.isEmpty {
            let currentId = queue.removeFirst()
            guard !visited.contains(currentId) else { continue }
            visited.insert(currentId)

            guard let node = nodes.first(where: { $0.id == currentId }) else { continue }

            // If this is an action node, add to chain
            if node.type.category == .action {
                var actionDict: [String: Any] = ["type": node.type.rawValue]

                // Merge config into action dict
                for (key, value) in node.config {
                    actionDict[key] = value.value
                }

                chain.append(actionDict)
            }

            // Find outgoing connections
            let outgoing = connections.filter { $0.sourceNodeId == currentId }
            for connection in outgoing {
                queue.append(connection.targetNodeId)
            }
        }

        return chain
    }

    private func hasCycle(from startId: UUID, visited: Set<UUID> = [], recursionStack: Set<UUID> = []) -> Bool {
        var visited = visited
        var recursionStack = recursionStack

        visited.insert(startId)
        recursionStack.insert(startId)

        let outgoing = connections.filter { $0.sourceNodeId == startId }
        for connection in outgoing {
            let targetId = connection.targetNodeId

            if !visited.contains(targetId) {
                if hasCycle(from: targetId, visited: visited, recursionStack: recursionStack) {
                    return true
                }
            } else if recursionStack.contains(targetId) {
                return true
            }
        }

        recursionStack.remove(startId)
        return false
    }
}

// MARK: - Hook Node

/// A single node in the hooks pipeline graph.
public struct HookNode: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var type: HookNodeType
    public var eventType: String?
    public var config: [String: AnyCodable]
    public var position: CGPoint

    public init(
        id: UUID = UUID(),
        type: HookNodeType,
        eventType: String? = nil,
        config: [String: AnyCodable] = [:],
        position: CGPoint = .zero
    ) {
        self.id = id
        self.type = type
        self.eventType = eventType
        self.config = config
        self.position = position
    }

    // Custom coding for CGPoint
    private enum CodingKeys: String, CodingKey {
        case id, type, eventType, config, positionX, positionY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(HookNodeType.self, forKey: .type)
        eventType = try container.decodeIfPresent(String.self, forKey: .eventType)
        config = try container.decode([String: AnyCodable].self, forKey: .config)

        let x = try container.decode(Double.self, forKey: .positionX)
        let y = try container.decode(Double.self, forKey: .positionY)
        position = CGPoint(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(eventType, forKey: .eventType)
        try container.encode(config, forKey: .config)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
    }

    // MARK: - Equatable

    public static func == (lhs: HookNode, rhs: HookNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.eventType == rhs.eventType &&
        lhs.position == rhs.position
        // Note: config comparison intentionally omitted for simplicity
    }
}

// MARK: - Hook Connection

/// A connection between two nodes in the pipeline.
public struct HookConnection: Codable, Sendable, Identifiable {
    public let id: UUID
    public var sourceNodeId: UUID
    public var targetNodeId: UUID

    public init(id: UUID = UUID(), sourceNodeId: UUID, targetNodeId: UUID) {
        self.id = id
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
    }
}

// MARK: - Hook Validation Error

/// Validation error for a pipeline node or connection.
/// Note: Named PipelineValidationError to avoid conflict with HookValidationError enum in HookTypes.swift
public struct PipelineValidationError: Codable, Sendable, Identifiable {
    public let id: UUID
    public var message: String
    public var nodeId: UUID?

    public init(id: UUID = UUID(), message: String, nodeId: UUID? = nil) {
        self.id = id
        self.message = message
        self.nodeId = nodeId
    }
}

// MARK: - Hook Node Category

/// High-level category for hook node types.
public enum HookNodeCategory: String, Codable, Sendable, CaseIterable {
    case event      // Event sources (triggers)
    case filter     // Conditional filtering
    case action     // Actions to execute
    case control    // Control flow (decisions, gates)
    case transform  // Data transformation
    case utility    // Utility nodes (logging, etc.)
}

// MARK: - Hook Node Type

/// All supported hook node types in the visual builder.
public enum HookNodeType: String, Codable, Sendable, CaseIterable {
    // Event nodes (12)
    case preToolUse
    case postToolUse
    case postToolUseFailure
    case permissionRequest
    case userPromptSubmit
    case stop
    case subagentStart
    case subagentStop
    case sessionStart
    case sessionEnd
    case preCompact
    case notification

    // Filter nodes (2)
    case matcher
    case predicate

    // Action nodes (3)
    case command
    case prompt
    case agent

    // Control nodes (4)
    case decisionAllowDenyAsk
    case permissionDecision
    case blockWithReason
    case continueStop

    // Transform nodes (3)
    case updatedInput
    case additionalContext
    case systemMessage

    // Utility nodes (3)
    case logger
    case exportTrace
    case rateLimitDebounce

    /// The category this node type belongs to.
    public var category: HookNodeCategory {
        switch self {
        // Events
        case .preToolUse, .postToolUse, .postToolUseFailure, .permissionRequest,
             .userPromptSubmit, .stop, .subagentStart, .subagentStop,
             .sessionStart, .sessionEnd, .preCompact, .notification:
            return .event

        // Filters
        case .matcher, .predicate:
            return .filter

        // Actions
        case .command, .prompt, .agent:
            return .action

        // Control
        case .decisionAllowDenyAsk, .permissionDecision, .blockWithReason, .continueStop:
            return .control

        // Transform
        case .updatedInput, .additionalContext, .systemMessage:
            return .transform

        // Utility
        case .logger, .exportTrace, .rateLimitDebounce:
            return .utility
        }
    }

    /// Human-readable display name for the node type.
    public var displayName: String {
        switch self {
        // Events
        case .preToolUse: return "Pre Tool Use"
        case .postToolUse: return "Post Tool Use"
        case .postToolUseFailure: return "Post Tool Use Failure"
        case .permissionRequest: return "Permission Request"
        case .userPromptSubmit: return "User Prompt Submit"
        case .stop: return "Stop"
        case .subagentStart: return "Subagent Start"
        case .subagentStop: return "Subagent Stop"
        case .sessionStart: return "Session Start"
        case .sessionEnd: return "Session End"
        case .preCompact: return "Pre Compact"
        case .notification: return "Notification"

        // Filters
        case .matcher: return "Matcher"
        case .predicate: return "Predicate"

        // Actions
        case .command: return "Command"
        case .prompt: return "Prompt"
        case .agent: return "Agent"

        // Control
        case .decisionAllowDenyAsk: return "Decision: Allow/Deny/Ask"
        case .permissionDecision: return "Permission Decision"
        case .blockWithReason: return "Block With Reason"
        case .continueStop: return "Continue/Stop"

        // Transform
        case .updatedInput: return "Updated Input"
        case .additionalContext: return "Additional Context"
        case .systemMessage: return "System Message"

        // Utility
        case .logger: return "Logger"
        case .exportTrace: return "Export Trace"
        case .rateLimitDebounce: return "Rate Limit/Debounce"
        }
    }

    /// SF Symbol icon for the node type based on category.
    public var icon: String {
        switch category {
        case .event:
            return "bolt.circle.fill"
        case .filter:
            return "line.3.horizontal.decrease.circle"
        case .action:
            return "play.circle.fill"
        case .control:
            return "arrow.triangle.branch"
        case .transform:
            return "arrow.triangle.2.circlepath"
        case .utility:
            return "wrench.and.screwdriver.fill"
        }
    }
}
