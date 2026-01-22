import SwiftUI

// MARK: - Tasks Sidebar View

/// Sidebar view showing tasks/todos with checkbox interaction
struct TasksSidebarView: View {
    let sessionId: UUID?
    let events: [EventEnvelope]

    @State private var tasks: [TaskItem] = []
    @State private var showCompleted: Bool = true
    @State private var newTaskText: String = ""
    @State private var isAddingTask: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with filter
            taskHeader

            Divider()

            // Task list
            if filteredTasks.isEmpty {
                emptyState
            } else {
                taskList
            }

            Divider()

            // Add task bar
            addTaskBar
        }
        .onAppear {
            loadTasksFromEvents()
        }
        .onChange(of: events.count) { _, _ in
            loadTasksFromEvents()
        }
    }

    // MARK: - Header

    private var taskHeader: some View {
        HStack {
            // Task count
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "checklist")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ds.secondary)

                Text("\(completedCount)/\(tasks.count) completed")
                    .dsTextStyle(.caption, color: .ds.secondary)
            }

            Spacer()

            // Toggle completed visibility
            Button {
                withAnimation {
                    showCompleted.toggle()
                }
            } label: {
                HStack(spacing: DSSpacing.xxs) {
                    Image(systemName: showCompleted ? "eye" : "eye.slash")
                        .font(.system(size: 11))
                    Text(showCompleted ? "Hide Done" : "Show Done")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color.ds.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.xs) {
                ForEach($tasks) { $task in
                    if showCompleted || !task.isCompleted {
                        TaskRow(task: $task)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.9))
                            ))
                    }
                }
            }
            .padding(DSSpacing.sm)
            .animation(.easeInOut(duration: 0.2), value: tasks.map(\.isCompleted))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "checklist")
                .font(.system(size: 32))
                .foregroundStyle(Color.ds.tertiary)

            Text("No Tasks")
                .dsTextStyle(.subtitle)

            Text("Tasks will appear here as they are created during the session")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Add Task Bar

    private var addTaskBar: some View {
        HStack(spacing: DSSpacing.xs) {
            if isAddingTask {
                TextField("New task...", text: $newTaskText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        addTask()
                    }

                Button {
                    addTask()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(newTaskText.isEmpty ? Color.ds.tertiary : Color.ds.accent)
                }
                .buttonStyle(.plain)
                .disabled(newTaskText.isEmpty)

                Button {
                    isAddingTask = false
                    newTaskText = ""
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    isAddingTask = true
                } label: {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Add Task")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.ds.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.sm)
        .background(Color.ds.surface.opacity(0.3))
    }

    // MARK: - Computed Properties

    private var filteredTasks: [TaskItem] {
        if showCompleted {
            return tasks
        }
        return tasks.filter { !$0.isCompleted }
    }

    private var completedCount: Int {
        tasks.filter(\.isCompleted).count
    }

    // MARK: - Actions

    private func addTask() {
        guard !newTaskText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let task = TaskItem(
            content: newTaskText.trimmingCharacters(in: .whitespaces),
            isCompleted: false
        )

        withAnimation {
            tasks.append(task)
        }

        newTaskText = ""
        isAddingTask = false
    }

    private func loadTasksFromEvents() {
        // Extract tasks from events (if any todo-related events exist)
        // For now, this is a placeholder that could parse TodoWrite events
        // In the future, this would sync with the TodoWrite tool output

        // Sample tasks for development
        if tasks.isEmpty && sessionId != nil {
            tasks = [
                TaskItem(content: "Review generated code", isCompleted: false),
                TaskItem(content: "Run tests", isCompleted: false),
                TaskItem(content: "Update documentation", isCompleted: true),
            ]
        }
    }
}

// MARK: - Task Item Model

struct TaskItem: Identifiable {
    let id: UUID
    var content: String
    var isCompleted: Bool
    var priority: TaskPriority
    var createdAt: Date

    init(
        id: UUID = UUID(),
        content: String,
        isCompleted: Bool = false,
        priority: TaskPriority = .normal
    ) {
        self.id = id
        self.content = content
        self.isCompleted = isCompleted
        self.priority = priority
        self.createdAt = Date()
    }
}

enum TaskPriority: String, CaseIterable {
    case low
    case normal
    case high

    var color: Color {
        switch self {
        case .low: return Color.ds.tertiary
        case .normal: return Color.ds.secondary
        case .high: return Color.ds.warning
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    @Binding var task: TaskItem
    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var editText: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    task.isCompleted.toggle()
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        task.isCompleted
                            ? Color.ds.positive
                            : (isHovered ? Color.ds.secondary : Color.ds.tertiary)
                    )
            }
            .buttonStyle(.plain)

            // Task content
            if isEditing {
                TextField("Task", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        task.content = editText
                        isEditing = false
                    }
            } else {
                Text(task.content)
                    .dsTextStyle(.body, color: task.isCompleted ? .ds.tertiary : .ds.foreground)
                    .strikethrough(task.isCompleted, color: Color.ds.tertiary)
                    .onTapGesture(count: 2) {
                        editText = task.content
                        isEditing = true
                    }
            }

            Spacer()

            // Priority indicator (on hover)
            if isHovered && task.priority == .high {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.ds.warning)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(
            isHovered
                ? Color.ds.surface.opacity(0.3)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Progress Ring

/// Circular progress indicator for task completion
struct TaskProgressRing: View {
    let completed: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.ds.surface, lineWidth: 3)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.ds.positive,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Center text
            Text("\(Int(progress * 100))%")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.ds.secondary)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Previews

#Preview("Tasks Sidebar") {
    TasksSidebarView(sessionId: UUID(), events: [])
        .frame(width: 280, height: 400)
        .background(Color.ds.bg0)
}

#Preview("Task Row") {
    struct PreviewWrapper: View {
        @State private var task1 = TaskItem(content: "Review code changes", isCompleted: false)
        @State private var task2 = TaskItem(content: "Update documentation", isCompleted: true)
        @State private var task3 = TaskItem(content: "Urgent fix needed", isCompleted: false, priority: .high)

        var body: some View {
            VStack(spacing: 0) {
                TaskRow(task: $task1)
                TaskRow(task: $task2)
                TaskRow(task: $task3)
            }
            .frame(width: 280)
            .background(Color.ds.bg0)
        }
    }

    return PreviewWrapper()
}

#Preview("Progress Ring") {
    HStack(spacing: DSSpacing.lg) {
        TaskProgressRing(completed: 0, total: 10)
        TaskProgressRing(completed: 5, total: 10)
        TaskProgressRing(completed: 10, total: 10)
    }
    .padding()
    .background(Color.ds.bg0)
}
