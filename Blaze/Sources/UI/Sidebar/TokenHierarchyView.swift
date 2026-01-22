import SwiftUI
import Charts

/// Hierarchical token breakdown (parent + subagents)
struct TokenHierarchyView: View {
    let rows: [TokenHierarchyRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                TokenRow(row: row)
            }

            Divider()

            // Total row
            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text("\(totalTokens)")
                    .font(.headline.monospacedDigit())
            }
        }
        .padding()
    }

    var totalTokens: Int {
        rows.reduce(0) { $0 + $1.tokens }
    }
}

struct TokenRow: View {
    let row: TokenHierarchyRow

    var body: some View {
        HStack {
            if !row.isParent {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 16)
            }

            Text(row.label)
                .font(row.isParent ? .subheadline.bold() : .caption)

            Spacer()

            Text("\(row.tokens)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)

            // Percentage bar
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: geo.size.width * row.percentage)
            }
            .frame(width: 60, height: 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
        }
    }
}

/// Timeline chart showing cumulative token usage over time
struct TokenTimelineChart: View {
    let dataPoints: [TokenDataPoint]

    var body: some View {
        if dataPoints.isEmpty {
            Text("No token data yet")
                .foregroundColor(.secondary)
                .font(.caption)
        } else {
            Chart(dataPoints) { point in
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Tokens", point.cumulativeTokens)
                )
                .foregroundStyle(by: .value("Agent", point.agentLabel))
            }
            .chartXAxis {
                AxisMarks(values: .automatic)
            }
            .chartYAxis {
                AxisMarks(values: .automatic)
            }
            .frame(height: 200)
        }
    }
}

#Preview {
    VStack {
        TokenHierarchyView(rows: [
            TokenHierarchyRow(label: "Parent", tokens: 5000, isParent: true, totalTokens: 15000),
            TokenHierarchyRow(label: "Explore-1", tokens: 3000, isParent: false, totalTokens: 15000),
            TokenHierarchyRow(label: "Plan-2", tokens: 7000, isParent: false, totalTokens: 15000)
        ])

        TokenTimelineChart(dataPoints: [
            TokenDataPoint(timestamp: Date().addingTimeInterval(-60), cumulativeTokens: 1000, agentLabel: "Parent"),
            TokenDataPoint(timestamp: Date().addingTimeInterval(-30), cumulativeTokens: 5000, agentLabel: "Explore"),
            TokenDataPoint(timestamp: Date(), cumulativeTokens: 10000, agentLabel: "Plan")
        ])
    }
    .frame(width: 400, height: 500)
}
