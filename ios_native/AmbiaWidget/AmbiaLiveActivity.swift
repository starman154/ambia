//
//  AmbiaLiveActivity.swift
//  AmbiaWidget
//
//  Live Activity with Dynamic Island support
//  NO HARDCODING - Renders ANY data structure from Claude
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct AmbiaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AmbiaActivityAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.25))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // EXPANDED view (when user long-presses)
                DynamicIslandExpandedRegion(.leading) {
                    // Icon or leading content
                    if let icon = context.state.icon {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(parseColor(context.state.color))
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    // Priority indicator or trailing content
                    PriorityBadge(priority: context.state.priority)
                }

                DynamicIslandExpandedRegion(.center) {
                    // Main title
                    Text(context.attributes.title)
                        .font(.headline)
                        .lineLimit(2)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    // Dynamic data rendering - NO HARDCODING
                    DynamicDataGrid(data: context.state.data)
                        .padding(.top, 8)
                }
            } compactLeading: {
                // COMPACT view - Left side (e.g., icon)
                if let icon = context.state.icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(parseColor(context.state.color))
                }
            } compactTrailing: {
                // COMPACT view - Right side (e.g., time or value)
                if let firstValue = context.state.data.values.first {
                    Text(valueToString(firstValue.value))
                        .font(.caption2)
                        .lineLimit(1)
                }
            } minimal: {
                // MINIMAL view (when multiple activities are active)
                if let icon = context.state.icon {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundColor(parseColor(context.state.color))
                } else {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                }
            }
            .keylineTint(parseColor(context.state.color))
        }
    }
}

// MARK: - Lock Screen View
@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<AmbiaActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                if let icon = context.state.icon {
                    Image(systemName: icon)
                        .foregroundColor(parseColor(context.state.color))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.headline)

                    if let subtitle = context.state.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                PriorityBadge(priority: context.state.priority)
            }

            // Dynamic data display - NO HARDCODING
            if !context.state.data.isEmpty {
                Divider()
                DynamicDataGrid(data: context.state.data)
            }

            // Time info
            if let endTime = context.state.endTime {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(endTime, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

// MARK: - Dynamic Data Grid (NO HARDCODING!)
struct DynamicDataGrid: View {
    let data: [String: AnyCodable]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Render each key-value pair dynamically
            ForEach(Array(data.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(formatKey(key))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let value = data[key] {
                        Text(valueToString(value.value))
                            .font(.caption)
                            .bold()
                    }
                }
            }
        }
    }

    /// Format key from snake_case to Title Case
    private func formatKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Priority Badge
struct PriorityBadge: View {
    let priority: String

    var body: some View {
        Text(priority.uppercased())
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor.opacity(0.2))
            .foregroundColor(priorityColor)
            .cornerRadius(4)
    }

    var priorityColor: Color {
        switch priority.lowercased() {
        case "critical":
            return .red
        case "high":
            return .orange
        case "medium":
            return .blue
        case "low":
            return .gray
        default:
            return .blue
        }
    }
}

// MARK: - Helper Functions

/// Parse hex color string to SwiftUI Color
func parseColor(_ colorString: String?) -> Color {
    guard let colorString = colorString else {
        return .blue
    }

    // Handle hex colors like "#FF5733"
    if colorString.hasPrefix("#") {
        let hex = String(colorString.dropFirst())

        guard hex.count == 6,
              let r = Int(hex.prefix(2), radix: 16),
              let g = Int(hex.dropFirst(2).prefix(2), radix: 16),
              let b = Int(hex.dropFirst(4).prefix(2), radix: 16) else {
            return .blue
        }

        return Color(red: Double(r) / 255.0,
                    green: Double(g) / 255.0,
                    blue: Double(b) / 255.0)
    }

    // Handle system color names
    switch colorString.lowercased() {
    case "red":
        return .red
    case "blue":
        return .blue
    case "green":
        return .green
    case "orange":
        return .orange
    case "yellow":
        return .yellow
    case "purple":
        return .purple
    case "pink":
        return .pink
    default:
        return .blue
    }
}

/// Convert any value to display string
func valueToString(_ value: Any) -> String {
    switch value {
    case let string as String:
        return string
    case let int as Int:
        return "\(int)"
    case let double as Double:
        return String(format: "%.1f", double)
    case let bool as Bool:
        return bool ? "Yes" : "No"
    case let array as [Any]:
        return array.map { valueToString($0) }.joined(separator: ", ")
    default:
        return "\(value)"
    }
}

// MARK: - Preview
@available(iOS 16.1, *)
struct AmbiaLiveActivity_Previews: PreviewProvider {
    static let attributes = AmbiaActivityAttributes(
        eventId: "preview-123",
        eventType: "live_activity",
        title: "Amtrak to NYC"
    )

    static let contentState = AmbiaActivityAttributes.ContentState(
        subtitle: "Northeast Regional 190",
        body: "Your train is departing soon",
        data: [
            "departure_time": AnyCodable("3:45 PM"),
            "platform": AnyCodable("Track 7"),
            "travel_time_mins": AnyCodable(18),
            "status": AnyCodable("On Time")
        ],
        icon: "train.side.front.car",
        color: "#4A90E2",
        priority: "high",
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600)
    )

    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Island Compact")

        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Island Expanded")

        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Island Minimal")

        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Lock Screen")
    }
}
