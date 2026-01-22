import Foundation

// MARK: - Hook Timeline Builder

/// Transforms flat hook executions into hierarchical timeline trees for Gantt-style visualization.
///
/// **Architecture:**
/// - Processes `HookExecution` arrays from HookStore
/// - Groups executions by turn/parent relationship
/// - Calculates nesting depths
/// - Maps event types to timeline categories
///
/// **Usage:**
/// ```swift
/// let builder = HookTimelineBuilder()
/// let timeline = builder.buildTurnTimeline(
///     executions: executions,
///     hooks: hooks,
///     turnStart: turnStartDate,
///     turnEnd: turnEndDate
/// )
/// ```
public struct HookTimelineBuilder {

    // MARK: - Initialization

    public init() {}

    // MARK: - Single Turn Timeline

    /// Build a timeline for a single turn's hook executions.
    ///
    /// Groups executions hierarchically:
    /// - Turn container (depth 0) wraps all executions
    /// - Tool/file/git hooks at depth 1
    /// - Concurrent executions share the same depth level
    ///
    /// - Parameters:
    ///   - executions: Raw hook executions from the store
    ///   - hooks: Hook definitions (for names/metadata)
    ///   - turnStart: When the turn began
    ///   - turnEnd: When the turn ended (nil if still active)
    ///   - turnId: UUID for the turn container event
    ///   - turnName: Display name for the turn
    /// - Returns: Hierarchical timeline events
    public func buildTurnTimeline(
        executions: [HookExecution],
        hooks: [Hook],
        turnStart: Date,
        turnEnd: Date?,
        turnId: UUID = UUID(),
        turnName: String = "Turn"
    ) -> [HookTimelineEvent] {
        // Build lookup for hooks
        let hookLookup = Dictionary(uniqueKeysWithValues: hooks.map { ($0.id, $0) })

        // Convert executions to timeline events
        var childEvents = executions.compactMap { execution -> HookTimelineEvent? in
            guard let hook = hookLookup[execution.hookId] else { return nil }

            let event = HookTimelineEvent.from(execution: execution, hook: hook)
            // Set depth 1 (under turn container)
            return HookTimelineEvent(
                id: event.id,
                name: event.name,
                category: event.category,
                startTime: event.startTime,
                endTime: event.endTime,
                depth: 1,
                children: event.children,
                status: event.status
            )
        }

        // Sort by start time for consistent ordering
        childEvents.sort { $0.startTime < $1.startTime }

        // Determine turn status from children
        let turnStatus: HookTimelineStatus
        if childEvents.isEmpty {
            turnStatus = turnEnd == nil ? .running : .completed
        } else if childEvents.contains(where: { $0.status == .running }) {
            turnStatus = .running
        } else if childEvents.contains(where: { $0.status == .failed }) {
            turnStatus = .completed // Turn completed even if a hook failed
        } else {
            turnStatus = turnEnd == nil ? .running : .completed
        }

        // Create turn container
        let turnEvent = HookTimelineEvent(
            id: turnId,
            name: turnName,
            category: .turn,
            startTime: turnStart,
            endTime: turnEnd,
            depth: 0,
            children: childEvents,
            status: turnStatus
        )

        return [turnEvent]
    }

    // MARK: - Session Timeline

    /// Build a session-level timeline with turns as parent containers.
    ///
    /// Structure:
    /// - Session (depth 0) - optional
    /// - Turns (depth 1 or 0 if no session container)
    /// - Hooks (depth 2 or 1)
    ///
    /// - Parameters:
    ///   - turns: Array of turn data with executions
    ///   - sessionId: Session UUID for the container
    ///   - sessionStart: When the session began
    ///   - sessionEnd: When the session ended (nil if still active)
    ///   - includeSessionContainer: Whether to wrap in a session-level event
    /// - Returns: Hierarchical timeline events
    public func buildSessionTimeline(
        turns: [TurnData],
        sessionId: UUID = UUID(),
        sessionStart: Date,
        sessionEnd: Date?,
        includeSessionContainer: Bool = false
    ) -> [HookTimelineEvent] {
        // Build each turn's timeline
        var turnEvents = turns.enumerated().map { (index, turn) -> HookTimelineEvent in
            let turnTimeline = buildTurnTimeline(
                executions: turn.executions,
                hooks: turn.hooks,
                turnStart: turn.startTime,
                turnEnd: turn.endTime,
                turnId: turn.turnId,
                turnName: turn.name ?? "Turn \(index + 1)"
            )

            // Return the turn container (first element)
            var turnEvent = turnTimeline.first!

            // Adjust depth if including session container
            if includeSessionContainer {
                turnEvent = adjustDepth(event: turnEvent, by: 1)
            }

            return turnEvent
        }

        // Sort turns by start time
        turnEvents.sort { $0.startTime < $1.startTime }

        if includeSessionContainer {
            // Determine session status
            let sessionStatus: HookTimelineStatus
            if turnEvents.isEmpty {
                sessionStatus = sessionEnd == nil ? .running : .completed
            } else if turnEvents.contains(where: { $0.status == .running }) {
                sessionStatus = .running
            } else {
                sessionStatus = sessionEnd == nil ? .running : .completed
            }

            let sessionEvent = HookTimelineEvent(
                id: sessionId,
                name: "Session",
                category: .session,
                startTime: sessionStart,
                endTime: sessionEnd,
                depth: 0,
                children: turnEvents,
                status: sessionStatus
            )

            return [sessionEvent]
        }

        return turnEvents
    }

    // MARK: - Flat Timeline (No Hierarchy)

    /// Build a flat timeline without nesting (all events at depth 0).
    ///
    /// Useful for simple visualizations or when hierarchy isn't needed.
    ///
    /// - Parameters:
    ///   - executions: Raw hook executions
    ///   - hooks: Hook definitions
    /// - Returns: Flat array of timeline events
    public func buildFlatTimeline(
        executions: [HookExecution],
        hooks: [Hook]
    ) -> [HookTimelineEvent] {
        let hookLookup = Dictionary(uniqueKeysWithValues: hooks.map { ($0.id, $0) })

        var events = executions.compactMap { execution -> HookTimelineEvent? in
            guard let hook = hookLookup[execution.hookId] else { return nil }
            return HookTimelineEvent.from(execution: execution, hook: hook)
        }

        // Sort by start time
        events.sort { $0.startTime < $1.startTime }

        return events
    }

    // MARK: - Group by Category

    /// Build a timeline grouped by category (tool, file, git, etc.).
    ///
    /// Structure:
    /// - Category container (depth 0)
    /// - Individual hooks (depth 1)
    ///
    /// - Parameters:
    ///   - executions: Raw hook executions
    ///   - hooks: Hook definitions
    /// - Returns: Timeline events grouped by category
    public func buildCategoryGroupedTimeline(
        executions: [HookExecution],
        hooks: [Hook]
    ) -> [HookTimelineEvent] {
        let hookLookup = Dictionary(uniqueKeysWithValues: hooks.map { ($0.id, $0) })

        // Build events and group by category
        var eventsByCategory: [HookTimelineCategory: [HookTimelineEvent]] = [:]

        for execution in executions {
            guard let hook = hookLookup[execution.hookId] else { continue }
            let event = HookTimelineEvent.from(execution: execution, hook: hook)
            let category = HookTimelineCategory.from(eventType: hook.eventType)
            eventsByCategory[category, default: []].append(event)
        }

        // Build category containers
        var categoryEvents: [HookTimelineEvent] = []

        for (category, events) in eventsByCategory {
            guard !events.isEmpty else { continue }

            // Sort events by start time
            let sortedEvents = events.sorted { $0.startTime < $1.startTime }

            // Adjust depth for children
            let childEvents = sortedEvents.map { event in
                HookTimelineEvent(
                    id: event.id,
                    name: event.name,
                    category: event.category,
                    startTime: event.startTime,
                    endTime: event.endTime,
                    depth: 1,
                    children: event.children,
                    status: event.status
                )
            }

            // Calculate category time span
            let startTime = sortedEvents.map(\.startTime).min()!
            let endTime = sortedEvents.compactMap(\.endTime).max()

            // Determine category status
            let status: HookTimelineStatus
            if childEvents.contains(where: { $0.status == .running }) {
                status = .running
            } else if childEvents.contains(where: { $0.status == .failed }) {
                status = .completed
            } else {
                status = .completed
            }

            let categoryEvent = HookTimelineEvent(
                id: UUID(),
                name: category.displayName,
                category: category,
                startTime: startTime,
                endTime: endTime,
                depth: 0,
                children: childEvents,
                status: status
            )

            categoryEvents.append(categoryEvent)
        }

        // Sort categories by their first event's start time
        categoryEvents.sort { $0.startTime < $1.startTime }

        return categoryEvents
    }

    // MARK: - Concurrent Execution Detection

    /// Identify concurrent executions (overlapping time spans).
    ///
    /// Useful for visualizing parallel hook execution in the timeline.
    ///
    /// - Parameter events: Timeline events to analyze
    /// - Returns: Groups of concurrent events (each group ran at the same time)
    public func findConcurrentExecutions(in events: [HookTimelineEvent]) -> [[HookTimelineEvent]] {
        guard events.count > 1 else { return events.isEmpty ? [] : [events] }

        // Sort by start time
        let sorted = events.sorted { $0.startTime < $1.startTime }

        var groups: [[HookTimelineEvent]] = []
        var currentGroup: [HookTimelineEvent] = []
        var currentGroupEnd: Date?

        for event in sorted {
            if let groupEnd = currentGroupEnd, event.startTime < groupEnd {
                // Overlaps with current group
                currentGroup.append(event)
                // Extend group end time if this event ends later
                if let eventEnd = event.endTime, eventEnd > groupEnd {
                    currentGroupEnd = eventEnd
                }
            } else {
                // Start new group
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [event]
                currentGroupEnd = event.endTime ?? Date.distantFuture
            }
        }

        // Don't forget the last group
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups
    }

    // MARK: - Private Helpers

    /// Recursively adjust depth of an event and its children.
    private func adjustDepth(event: HookTimelineEvent, by delta: Int) -> HookTimelineEvent {
        let adjustedChildren = event.children.map { adjustDepth(event: $0, by: delta) }
        return HookTimelineEvent(
            id: event.id,
            name: event.name,
            category: event.category,
            startTime: event.startTime,
            endTime: event.endTime,
            depth: event.depth + delta,
            children: adjustedChildren,
            status: event.status
        )
    }
}

// MARK: - Turn Data

/// Data for a single turn within a session.
public struct TurnData: Sendable {
    public let turnId: UUID
    public let name: String?
    public let startTime: Date
    public let endTime: Date?
    public let executions: [HookExecution]
    public let hooks: [Hook]

    public init(
        turnId: UUID = UUID(),
        name: String? = nil,
        startTime: Date,
        endTime: Date? = nil,
        executions: [HookExecution],
        hooks: [Hook]
    ) {
        self.turnId = turnId
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.executions = executions
        self.hooks = hooks
    }
}

// MARK: - HookExecutionInfo Extension

extension HookTimelineBuilder {

    /// Build timeline from HookExecutionInfo (from HookExecutionStore).
    ///
    /// Converts HookExecutionInfo to the simpler model used by timeline building.
    ///
    /// - Parameters:
    ///   - infos: Hook execution info records
    ///   - hooks: Hook definitions
    /// - Returns: Flat timeline events
    func buildTimelineFromExecutionInfo(
        infos: [HookExecutionInfo],
        hooks: [Hook]
    ) -> [HookTimelineEvent] {
        let hookLookup = Dictionary(uniqueKeysWithValues: hooks.map { ($0.id.uuidString, $0) })

        var events = infos.compactMap { info -> HookTimelineEvent? in
            guard let hook = hookLookup[info.hookId] else { return nil }

            let status: HookTimelineStatus
            switch info.status {
            case .running:
                status = .running
            case .success:
                status = .completed
            case .failed:
                status = .failed
            case .timeout:
                status = .failed
            }

            return HookTimelineEvent(
                id: info.id,
                name: hook.name,
                category: HookTimelineCategory.from(eventType: hook.eventType),
                startTime: info.startedAt,
                endTime: info.endedAt,
                depth: 0,
                children: [],
                status: status
            )
        }

        events.sort { $0.startTime < $1.startTime }
        return events
    }
}
