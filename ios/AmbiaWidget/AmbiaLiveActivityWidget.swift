import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct AmbiaLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AmbiaActivityAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island UI
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.title)
                            .font(.caption)
                    } icon: {
                        Image(systemName: context.state.icon)
                            .foregroundColor(Color(hex: context.state.color))
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let progress = context.state.progress {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(.circular)
                            .frame(width: 40, height: 40)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let subtitle = context.state.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if let body = context.state.body {
                            Text(body)
                                .font(.caption)
                                .lineLimit(2)
                        }

                        // Show progress bar if available
                        if let progress = context.state.progress {
                            ProgressView(value: progress, total: 1.0)
                                .progressViewStyle(.linear)
                        }
                    }
                }
            } compactLeading: {
                // Compact leading (left side of Dynamic Island)
                Image(systemName: context.state.icon)
                    .foregroundColor(Color(hex: context.state.color))
            } compactTrailing: {
                // Compact trailing (right side of Dynamic Island)
                if let progress = context.state.progress {
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } minimal: {
                // Minimal view (when multiple activities are active)
                Image(systemName: context.state.icon)
                    .foregroundColor(Color(hex: context.state.color))
            }
        }
    }
}

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<AmbiaActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and title
            HStack {
                Image(systemName: context.state.icon)
                    .foregroundColor(Color(hex: context.state.color))
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title)
                        .font(.headline)

                    if let subtitle = context.state.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Priority badge
                PriorityBadge(priority: context.attributes.priority)
            }

            // Body text
            if let body = context.state.body {
                Text(body)
                    .font(.body)
                    .lineLimit(3)
            }

            // Flexible content based on data
            FlexibleContentView(state: context.state)

            // Timestamp
            HStack {
                Spacer()
                Text(context.state.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: context.state.color).opacity(0.1))
        )
        .widgetURL(URL(string: "ambia://ambient-info/\(context.attributes.eventId)"))
    }
}

@available(iOS 16.1, *)
struct FlexibleContentView: View {
    let state: AmbiaActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Progress bar
            if let progress = state.progress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .bold()
                    }
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(Color(hex: state.color))
                }
            }

            // Image (if available)
            if let imageUrl = state.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 120)
                }
            }

            // Chart data (simplified representation)
            if let chartDataJson = state.chartDataJson,
               let jsonData = chartDataJson.data(using: .utf8),
               let chartData = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]],
               !chartData.isEmpty {
                ChartView(data: chartData, color: Color(hex: state.color))
            }
        }
    }
}

@available(iOS 16.1, *)
struct ChartView: View {
    let data: [[String: Any]]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Chart")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<min(data.count, 7), id: \.self) { index in
                    if let value = data[index]["value"] as? Double {
                        VStack {
                            Rectangle()
                                .fill(color)
                                .frame(width: 30, height: CGFloat(value * 60))
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            if let label = data[index]["label"] as? String {
                                Text(label)
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(height: 80)
        }
    }
}

struct PriorityBadge: View {
    let priority: String

    var body: some View {
        Text(priority.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(priorityColor)
            )
    }

    private var priorityColor: Color {
        switch priority.lowercased() {
        case "high":
            return .red
        case "medium":
            return .orange
        case "low":
            return .green
        default:
            return .gray
        }
    }
}

// Helper extension to convert hex color strings to Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
