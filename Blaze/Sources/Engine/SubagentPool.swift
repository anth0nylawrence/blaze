import Foundation

// MARK: - Queue Result

/// Result of enqueueing a subagent
public enum QueueResult: Sendable {
    /// Subagent started immediately (slot available)
    case started
    /// Subagent queued (1-indexed position)
    case queued(position: Int)
}

// MARK: - Subagent Pool

/// Thread-safe pool managing running and queued subagents with concurrency control.
///
/// **Concurrency Model:**
/// - `maxConcurrent`: Configurable limit (default 10, hard cap 500)
/// - `running`: Set of currently executing subagent UUIDs
/// - `queue`: Priority-ordered queue of pending subagents
///
/// **Queue Ordering:**
/// - Sorted by priority (higher = runs sooner)
/// - Stable sort preserves insertion order for equal priorities
/// - Reordering via drag-drop updates priority and re-sorts
///
/// **Auto-Draining:**
/// - When `onComplete()` is called, next queued item auto-starts
/// - When `setMaxConcurrent()` increases limit, queue drains immediately
/// - No manual queue processing needed
///
/// **Thread Safety:**
/// - All methods are async and isolated to the actor
/// - Safe to call from multiple tasks concurrently
public actor SubagentPool {
    /// Default max concurrent subagents
    public static let defaultMaxConcurrent = 10

    /// Absolute maximum concurrent subagents (hard cap)
    public static let absoluteMaxConcurrent = 500

    // MARK: - Private State

    private var maxConcurrent: Int
    private var running: Set<UUID> = []
    private var queue: [(internalId: UUID, priority: Int)] = []
    private let registry: SubagentRegistry

    // MARK: - Initialization

    /// Create a new pool with configurable concurrency
    ///
    /// - Parameters:
    ///   - maxConcurrent: Maximum concurrent subagents (clamped to 1...500)
    ///   - registry: Registry for correlation lookups
    public init(
        maxConcurrent: Int = defaultMaxConcurrent,
        registry: SubagentRegistry
    ) {
        self.maxConcurrent = min(max(maxConcurrent, 1), Self.absoluteMaxConcurrent)
        self.registry = registry
    }

    // MARK: - Public API

    /// Set max concurrent subagents and immediately drain queue if increased
    ///
    /// - Parameter value: New max concurrent (clamped to 1...500)
    public func setMaxConcurrent(_ value: Int) async {
        let clamped = min(max(value, 1), Self.absoluteMaxConcurrent)
        maxConcurrent = clamped

        // Drain queue if we have more slots now
        await processQueue()
    }

    /// Enqueue a subagent with optional priority
    ///
    /// - Parameters:
    ///   - internalId: Blaze internal UUID
    ///   - priority: Queue priority (higher = runs sooner, default 0)
    /// - Returns: `.started` if executed immediately, `.queued(position)` otherwise
    public func enqueue(_ internalId: UUID, priority: Int = 0) async -> QueueResult {
        // Start immediately if slot available
        let effective = effectiveMaxConcurrent()
        if running.count < effective {
            running.insert(internalId)

            // Update status in registry
            if let correlation = await registry.lookup(internalId: internalId) {
                await registry.updateStatus(correlation.toolUseId, status: .running)
            }

            return .started
        }

        // Queue with priority
        queue.append((internalId: internalId, priority: priority))

        // Sort by priority descending (higher = sooner)
        queue.sort { $0.priority > $1.priority }

        // Find position (1-indexed)
        guard let index = queue.firstIndex(where: { $0.internalId == internalId }) else {
            return .queued(position: queue.count) // Fallback
        }

        let position = index + 1 // 1-indexed

        // Update queue position in registry
        if let correlation = await registry.lookup(internalId: internalId) {
            await registry.updateQueuePosition(correlation.toolUseId, position: position)
        }

        return .queued(position: position)
    }

    /// Reorder queue by moving an item to a new position
    ///
    /// - Parameters:
    ///   - internalId: UUID of item to move
    ///   - toPosition: Target position (0-indexed)
    public func reorderQueue(moving internalId: UUID, toPosition: Int) async {
        // Find current index
        guard let currentIndex = queue.firstIndex(where: { $0.internalId == internalId }) else {
            return // Item not in queue
        }

        // Validate bounds
        let targetIndex = min(max(toPosition, 0), queue.count - 1)

        // Remove item
        let item = queue.remove(at: currentIndex)

        // Calculate new priority based on position
        // Position 0 = highest priority, position n = lowest
        // Use descending priority: higher position = lower priority
        let newPriority = queue.count - targetIndex

        // Insert at new position with updated priority
        let updatedItem = (internalId: item.internalId, priority: newPriority)
        queue.insert(updatedItem, at: targetIndex)

        // Re-sort by priority (stable sort for equal priorities)
        queue.sort { $0.priority > $1.priority }

        // Update all queue positions in registry
        for (index, queuedItem) in queue.enumerated() {
            if let correlation = await registry.lookup(internalId: queuedItem.internalId) {
                await registry.updateQueuePosition(correlation.toolUseId, position: index + 1)
            }
        }
    }

    /// Mark a subagent as complete and auto-start next queued item
    ///
    /// - Parameter internalId: UUID of completed subagent
    /// - Returns: UUID of next started subagent, or nil if queue empty
    public func onComplete(_ internalId: UUID) async -> UUID? {
        // Remove from running
        running.remove(internalId)

        // Update status in registry
        if let correlation = await registry.lookup(internalId: internalId) {
            await registry.updateStatus(correlation.toolUseId, status: .completed)
        }

        // Drain queue
        await processQueue()

        // Return next started item (if any)
        return queue.isEmpty ? nil : queue.first?.internalId
    }

    /// Cancel all queued subagents for a parent session
    ///
    /// - Parameter parentSessionId: Parent session UUID
    /// - Returns: Array of cancelled subagent UUIDs
    public func cancelQueued(for parentSessionId: UUID) async -> [UUID] {
        var cancelled: [UUID] = []

        // Get all correlations for this session
        let correlations = await registry.getAll(for: parentSessionId)

        // Filter to queued items
        let queuedInternalIds = Set(correlations.filter { $0.status == .queued }.map { $0.internalId })

        // Remove from queue and collect UUIDs
        queue.removeAll { queuedItem in
            if queuedInternalIds.contains(queuedItem.internalId) {
                cancelled.append(queuedItem.internalId)
                return true
            }
            return false
        }

        // Update status to cancelled in registry
        for internalId in cancelled {
            if let correlation = await registry.lookup(internalId: internalId) {
                await registry.updateStatus(correlation.toolUseId, status: .cancelled)
            }
        }

        return cancelled
    }

    // MARK: - Private Helpers

    /// Get available system memory in bytes
    private func getAvailableMemory() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let freePages = UInt64(stats.free_count)
        let inactivePages = UInt64(stats.inactive_count)

        return (freePages + inactivePages) * pageSize
    }

    /// Check system memory and auto-reduce concurrency if needed
    private func effectiveMaxConcurrent() -> Int {
        guard UserDefaults.standard.bool(forKey: "autoThrottleSubagents") else {
            return maxConcurrent
        }

        let threshold = UserDefaults.standard.integer(forKey: "throttleMemoryGB")
        let availableMemory = getAvailableMemory()
        let freeMemoryGB = availableMemory / 1_073_741_824

        // If below threshold, halve max concurrent
        if freeMemoryGB < UInt64(threshold == 0 ? 4 : threshold) {
            return max(maxConcurrent / 2, 1)
        }
        return maxConcurrent
    }

    /// Process queue and start items if slots available
    private func processQueue() async {
        let effective = effectiveMaxConcurrent()
        while running.count < effective && !queue.isEmpty {
            // Take first item (highest priority)
            let item = queue.removeFirst()

            // Start running
            running.insert(item.internalId)

            // Update status in registry
            if let correlation = await registry.lookup(internalId: item.internalId) {
                await registry.updateStatus(correlation.toolUseId, status: .running)
                await registry.updateQueuePosition(correlation.toolUseId, position: 0) // Clear position
            }
        }

        // Update queue positions for remaining items
        for (index, queuedItem) in queue.enumerated() {
            if let correlation = await registry.lookup(internalId: queuedItem.internalId) {
                await registry.updateQueuePosition(correlation.toolUseId, position: index + 1)
            }
        }
    }
}
