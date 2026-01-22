import SwiftUI

/// Settings view for subagent concurrency control
struct SubagentSettingsView: View {
    @AppStorage("maxConcurrentSubagents") private var maxConcurrent: Int = 10
    @AppStorage("autoThrottleSubagents") private var autoThrottle: Bool = true
    @AppStorage("throttleMemoryGB") private var throttleThreshold: Int = 4

    var body: some View {
        Form {
            Section("Subagent Concurrency") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Max Concurrent Agents")
                        Spacer()
                        Text("\(maxConcurrent)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: Binding(
                            get: { Double(maxConcurrent) },
                            set: { maxConcurrent = Int($0) }
                        ),
                        in: 1...100,
                        step: 1
                    )

                    // Quick presets
                    HStack(spacing: 8) {
                        PresetButton(label: "10", value: 10, current: $maxConcurrent)
                        PresetButton(label: "25", value: 25, current: $maxConcurrent)
                        PresetButton(label: "50", value: 50, current: $maxConcurrent)
                        PresetButton(label: "100", value: 100, current: $maxConcurrent)
                    }

                    Text("Default: 10 • Power users: 50-100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Resource Limits") {
                Toggle("Auto-throttle on low memory", isOn: $autoThrottle)

                if autoThrottle {
                    Picker("Throttle threshold", selection: $throttleThreshold) {
                        Text("2 GB free").tag(2)
                        Text("4 GB free").tag(4)
                        Text("8 GB free").tag(8)
                    }

                    Text("When available memory drops below threshold, max concurrent is halved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct PresetButton: View {
    let label: String
    let value: Int
    @Binding var current: Int

    var body: some View {
        Button(label) {
            current = value
        }
        .buttonStyle(.bordered)
        .tint(current == value ? .accentColor : .secondary)
    }
}

#Preview {
    SubagentSettingsView()
        .frame(width: 400, height: 300)
}
