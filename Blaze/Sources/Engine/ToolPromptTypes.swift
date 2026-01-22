import Foundation

// MARK: - Tool Prompt Types

/// Option in a tool prompt (e.g., for AskUserQuestion)
public struct ToolPromptOption: Codable, Sendable, Identifiable {
    public let id: String           // Preferred for tool_result response
    public let label: String        // Display text
    public let description: String? // Optional explanation

    public init(id: String, label: String, description: String?) {
        self.id = id
        self.label = label
        self.description = description
    }
}

/// Response type for tool prompts
public enum ToolPromptResponseType: String, Codable, Sendable {
    case singleSelect   // Radio buttons, one choice
    case multiSelect    // Checkboxes, multiple choices
    case freeText       // Text input (fallback for unknown tools)
}

/// Generic tool prompt event (works for any interactive tool)
public struct ToolPromptEvent: Codable, Sendable, Identifiable {
    public var id: String { promptId }

    public let promptId: String
    public let toolUseId: String
    public let promptIndex: Int?
    public let promptCount: Int?
    public let toolName: String
    public let title: String?
    public let body: String?
    public let options: [ToolPromptOption]
    public let responseType: ToolPromptResponseType
    public let rawInput: String      // Original JSON for debugging
    public let timestamp: Date

    /// Whether this prompt has no options and needs free-text input
    public var requiresFreeText: Bool {
        options.isEmpty || responseType == .freeText
    }

    public init(
        toolUseId: String,
        toolName: String,
        title: String?,
        body: String?,
        options: [ToolPromptOption],
        responseType: ToolPromptResponseType,
        rawInput: String,
        timestamp: Date,
        promptId: String? = nil,
        promptIndex: Int? = nil,
        promptCount: Int? = nil
    ) {
        self.promptId = promptId ?? toolUseId
        self.toolUseId = toolUseId
        self.promptIndex = promptIndex
        self.promptCount = promptCount
        self.toolName = toolName
        self.title = title
        self.body = body
        self.options = options
        self.responseType = responseType
        self.rawInput = rawInput
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case promptId
        case toolUseId
        case promptIndex
        case promptCount
        case toolName
        case title
        case body
        case options
        case responseType
        case rawInput
        case timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let toolUseId = try container.decode(String.self, forKey: .toolUseId)
        self.promptId = try container.decodeIfPresent(String.self, forKey: .promptId) ?? toolUseId
        self.toolUseId = toolUseId
        self.promptIndex = try container.decodeIfPresent(Int.self, forKey: .promptIndex)
        self.promptCount = try container.decodeIfPresent(Int.self, forKey: .promptCount)
        self.toolName = try container.decode(String.self, forKey: .toolName)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.body = try container.decodeIfPresent(String.self, forKey: .body)
        self.options = try container.decode([ToolPromptOption].self, forKey: .options)
        self.responseType = try container.decode(ToolPromptResponseType.self, forKey: .responseType)
        self.rawInput = try container.decode(String.self, forKey: .rawInput)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(promptId, forKey: .promptId)
        try container.encode(toolUseId, forKey: .toolUseId)
        try container.encodeIfPresent(promptIndex, forKey: .promptIndex)
        try container.encodeIfPresent(promptCount, forKey: .promptCount)
        try container.encode(toolName, forKey: .toolName)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encode(options, forKey: .options)
        try container.encode(responseType, forKey: .responseType)
        try container.encode(rawInput, forKey: .rawInput)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

/// User's selection (for option-based prompts)
public struct ToolPromptSelection: Codable, Sendable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

/// User's response (covers both selections and free-text)
public enum ToolPromptResponse: Codable, Sendable {
    case selections([ToolPromptSelection])
    case freeText(String)
}

// MARK: - Submission State

/// State machine for prompt submission
public enum SubmissionState: Equatable, Sendable {
    case idle           // Not yet submitted
    case submitting     // In progress
    case submitted      // Successfully sent
    case failed(String) // Failed with error message
}
