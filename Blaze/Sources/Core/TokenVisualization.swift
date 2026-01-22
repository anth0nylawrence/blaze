import Foundation

/// Data point for token timeline chart (Swift Charts compatible)
public struct TokenDataPoint: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let cumulativeTokens: Int
    public let agentLabel: String  // "Parent", "Explore-1", "Plan-2", etc.

    public init(timestamp: Date, cumulativeTokens: Int, agentLabel: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.cumulativeTokens = cumulativeTokens
        self.agentLabel = agentLabel
    }
}

/// Hierarchy row for parent + subagent breakdown
public struct TokenHierarchyRow: Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let tokens: Int
    public let isParent: Bool
    public let percentage: Double  // 0.0-1.0

    public init(label: String, tokens: Int, isParent: Bool, totalTokens: Int) {
        self.id = UUID()
        self.label = label
        self.tokens = tokens
        self.isParent = isParent
        self.percentage = totalTokens > 0 ? Double(tokens) / Double(totalTokens) : 0
    }
}

/// Aggregator that builds visualization-ready data
public struct TokenAggregator {
    public static func buildHierarchy(
        parentTokens: Int,
        subagents: [(label: String, tokens: Int)]
    ) -> [TokenHierarchyRow] {
        let total = parentTokens + subagents.reduce(0) { $0 + $1.tokens }
        var rows = [TokenHierarchyRow(label: "Parent", tokens: parentTokens, isParent: true, totalTokens: total)]
        rows.append(contentsOf: subagents.map {
            TokenHierarchyRow(label: $0.label, tokens: $0.tokens, isParent: false, totalTokens: total)
        })
        return rows
    }

    public static func buildTimeline(
        events: [(timestamp: Date, tokens: Int, agentLabel: String)]
    ) -> [TokenDataPoint] {
        var cumulative = 0
        return events.sorted { $0.timestamp < $1.timestamp }.map { event in
            cumulative += event.tokens
            return TokenDataPoint(
                timestamp: event.timestamp,
                cumulativeTokens: cumulative,
                agentLabel: event.agentLabel
            )
        }
    }
}
