import Foundation
import SwiftUI

// MARK: - Gantt View Mode

/// Display mode for the hook timeline visualization
public enum GanttViewMode: String, CaseIterable, Sendable {
    case turn
    case session

    public var displayName: String {
        switch self {
        case .turn: return "Turn"
        case .session: return "Session"
        }
    }
}

// MARK: - Hook Gantt View Model

/// Reactive state management for the Gantt-style hook timeline visualization.
///
/// Bridges `HookTimelineEvent` model and `HookTimelineBuilder` to SwiftUI views.
///
/// **Responsibilities:**
/// - Manages expand/collapse state for hierarchical events
/// - Tracks selection and hover state for interaction
/// - Provides flattened event list respecting expand state
/// - Coordinates timeline building from raw execution data
@Observable
public final class HookGanttViewModel {

    // MARK: - State Properties

    /// Current timeline tree (hierarchical events)
    public private(set) var events: [HookTimelineEvent] = []

    /// Which events are expanded (show children)
    public var expandedEventIds: Set<UUID> = []

    /// Currently selected event ID
    public var selectedEventId: UUID?

    /// Event ID under hover (for tooltip display)
    public var hoveredEventId: UUID?

    /// Current view mode (turn vs session granularity)
    public var viewMode: GanttViewMode = .turn

    /// Timeline start boundary
    public private(set) var timelineStart: Date = Date()

    /// Timeline end boundary
    public private(set) var timelineEnd: Date = Date()

    // MARK: - Private State

    /// Cached source data for refresh
    private var cachedExecutions: [HookExecution] = []
    private var cachedHooks: [Hook] = []
    private var cachedTurnStart: Date?
    private var cachedTurnEnd: Date?
    private var cachedSessionStart: Date?
    private var cachedSessionEnd: Date?

    /// Builder instance
    private let builder = HookTimelineBuilder()

    // MARK: - Initialization

    public init() {}

    // MARK: - Computed Properties

    /// Flattened list of events respecting expand state.
    ///
    /// Children of collapsed events are hidden. Useful for rendering
    /// a flat list while maintaining tree semantics.
    public var flattenedEvents: [HookTimelineEvent] {
        flattenEvents(events, expandedIds: expandedEventIds)
    }

    /// Total duration of the visible timeline
    public var totalDuration: TimeInterval {
        timelineEnd.timeIntervalSince(timelineStart)
    }

    /// Visible time range as a closed range
    public var visibleTimeRange: ClosedRange<Date> {
        timelineStart...timelineEnd
    }

    /// Currently selected event (if any)
    public var selectedEvent: HookTimelineEvent? {
        guard let id = selectedEventId else { return nil }
        return findEvent(by: id, in: events)
    }

    /// Currently hovered event (if any)
    public var hoveredEvent: HookTimelineEvent? {
        guard let id = hoveredEventId else { return nil }
        return findEvent(by: id, in: events)
    }

    // MARK: - Public Methods

    /// Toggle expand/collapse state for an event
    public func toggleExpanded(_ id: UUID) {
        if expandedEventIds.contains(id) {
            expandedEventIds.remove(id)
        } else {
            expandedEventIds.insert(id)
        }
    }

    /// Set selection to a specific event (or clear with nil)
    public func selectEvent(_ id: UUID?) {
        selectedEventId = id
    }

    /// Change the view mode
    public func setViewMode(_ mode: GanttViewMode) {
        guard mode != viewMode else { return }
        viewMode = mode
        refresh()
    }

    /// Load timeline from execution data.
    ///
    /// - Parameters:
    ///   - executions: Raw hook executions from storage
    ///   - hooks: Hook definitions for metadata lookup
    ///   - turnStart: Start time for turn-level view
    ///   - turnEnd: End time for turn-level view
    ///   - sessionStart: Start time for session-level view
    ///   - sessionEnd: End time for session-level view
    public func loadTimeline(
        from executions: [HookExecution],
        hooks: [Hook],
        turnStart: Date? = nil,
        turnEnd: Date? = nil,
        sessionStart: Date? = nil,
        sessionEnd: Date? = nil
    ) {
        // Cache for refresh
        cachedExecutions = executions
        cachedHooks = hooks
        cachedTurnStart = turnStart
        cachedTurnEnd = turnEnd
        cachedSessionStart = sessionStart
        cachedSessionEnd = sessionEnd

        buildTimeline()
    }

    /// Rebuild timeline from cached data
    public func refresh() {
        buildTimeline()
    }

    /// Expand all events
    public func expandAll() {
        expandedEventIds = Set(collectAllIds(from: events))
    }

    /// Collapse all events
    public func collapseAll() {
        expandedEventIds.removeAll()
    }

    // MARK: - Private Methods

    private func buildTimeline() {
        switch viewMode {
        case .turn:
            let turnStart = cachedTurnStart ?? (cachedExecutions.map(\.startedAt).min() ?? Date())
            let turnEnd = cachedTurnEnd ?? cachedExecutions.compactMap(\.completedAt).max()

            events = builder.buildTurnTimeline(
                executions: cachedExecutions,
                hooks: cachedHooks,
                turnStart: turnStart,
                turnEnd: turnEnd
            )

            timelineStart = turnStart
            timelineEnd = turnEnd ?? Date()

        case .session:
            // For session mode, build a session timeline with the turn as a child
            let sessionStart = cachedSessionStart ?? (cachedExecutions.map(\.startedAt).min() ?? Date())
            let sessionEnd = cachedSessionEnd ?? cachedExecutions.compactMap(\.completedAt).max()
            let turnStart = cachedTurnStart ?? sessionStart
            let turnEnd = cachedTurnEnd ?? cachedExecutions.compactMap(\.completedAt).max()

            let turnData = TurnData(
                turnId: UUID(),
                name: "Current Turn",
                startTime: turnStart,
                endTime: turnEnd,
                executions: cachedExecutions,
                hooks: cachedHooks
            )

            events = builder.buildSessionTimeline(
                turns: [turnData],
                sessionStart: sessionStart,
                sessionEnd: sessionEnd,
                includeSessionContainer: true
            )

            timelineStart = sessionStart
            timelineEnd = sessionEnd ?? Date()
        }

        // Auto-expand top-level events
        for event in events {
            expandedEventIds.insert(event.id)
        }
    }

    /// Flatten events recursively, respecting expand state
    private func flattenEvents(
        _ events: [HookTimelineEvent],
        expandedIds: Set<UUID>
    ) -> [HookTimelineEvent] {
        var result: [HookTimelineEvent] = []

        for event in events {
            result.append(event)

            if expandedIds.contains(event.id) && !event.children.isEmpty {
                let childrenFlattened = flattenEvents(event.children, expandedIds: expandedIds)
                result.append(contentsOf: childrenFlattened)
            }
        }

        return result
    }

    /// Find an event by ID in the tree
    private func findEvent(by id: UUID, in events: [HookTimelineEvent]) -> HookTimelineEvent? {
        for event in events {
            if event.id == id {
                return event
            }
            if let found = findEvent(by: id, in: event.children) {
                return found
            }
        }
        return nil
    }

    /// Collect all event IDs from the tree
    private func collectAllIds(from events: [HookTimelineEvent]) -> [UUID] {
        var ids: [UUID] = []
        for event in events {
            ids.append(event.id)
            ids.append(contentsOf: collectAllIds(from: event.children))
        }
        return ids
    }
}
