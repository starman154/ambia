import Foundation
import ActivityKit
import WidgetKit

@available(iOS 16.1, *)
class AmbiaLiveActivityManager {
    static let shared = AmbiaLiveActivityManager()

    private var currentActivity: Activity<AmbiaActivityAttributes>?

    // Start a new Live Activity
    func startActivity(eventData: [String: Any]) -> String? {
        // End any existing activity first
        endActivity()

        guard let eventId = eventData["id"] as? String,
              let title = eventData["title"] as? String,
              let eventType = eventData["event_type"] as? String else {
            print("[LiveActivity] Missing required fields in event data")
            return nil
        }

        let subtitle = eventData["subtitle"] as? String
        let body = eventData["body"] as? String
        let priority = eventData["priority"] as? String ?? "medium"
        let icon = eventData["icon"] as? String ?? "circle.fill"
        let color = eventData["color"] as? String ?? "#2196F3"

        // Parse the flexible data field
        let flexibleData = eventData["data"] as? [String: Any] ?? [:]

        // Convert chart data and custom fields to JSON strings
        var chartDataJson: String? = nil
        if let chartData = flexibleData["chartData"] as? [[String: Any]] {
            if let jsonData = try? JSONSerialization.data(withJSONObject: chartData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                chartDataJson = jsonString
            }
        }

        var customFieldsJson: String? = nil
        if !flexibleData.isEmpty {
            if let jsonData = try? JSONSerialization.data(withJSONObject: flexibleData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                customFieldsJson = jsonString
            }
        }

        // Create the activity attributes
        let attributes = AmbiaActivityAttributes(
            eventId: eventId,
            eventType: eventType,
            priority: priority
        )

        // Create the initial content state
        let initialState = AmbiaActivityAttributes.ContentState(
            title: title,
            subtitle: subtitle,
            body: body,
            icon: icon,
            color: color,
            progress: flexibleData["progress"] as? Double,
            imageUrl: flexibleData["imageUrl"] as? String,
            chartDataJson: chartDataJson,
            customFieldsJson: customFieldsJson,
            timestamp: Date()
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )

            currentActivity = activity
            print("[LiveActivity] ✅ Started activity: \(activity.id)")
            return activity.id

        } catch {
            print("[LiveActivity] ❌ Error starting activity: \(error)")
            return nil
        }
    }

    // Update an existing Live Activity
    func updateActivity(eventData: [String: Any]) {
        guard let activity = currentActivity else {
            print("[LiveActivity] No active activity to update")
            return
        }

        guard let title = eventData["title"] as? String else {
            print("[LiveActivity] Missing title in update data")
            return
        }

        let subtitle = eventData["subtitle"] as? String
        let body = eventData["body"] as? String
        let icon = eventData["icon"] as? String ?? "circle.fill"
        let color = eventData["color"] as? String ?? "#2196F3"

        // Parse the flexible data field
        let flexibleData = eventData["data"] as? [String: Any] ?? [:]

        // Convert chart data and custom fields to JSON strings
        var chartDataJson: String? = nil
        if let chartData = flexibleData["chartData"] as? [[String: Any]] {
            if let jsonData = try? JSONSerialization.data(withJSONObject: chartData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                chartDataJson = jsonString
            }
        }

        var customFieldsJson: String? = nil
        if !flexibleData.isEmpty {
            if let jsonData = try? JSONSerialization.data(withJSONObject: flexibleData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                customFieldsJson = jsonString
            }
        }

        let updatedState = AmbiaActivityAttributes.ContentState(
            title: title,
            subtitle: subtitle,
            body: body,
            icon: icon,
            color: color,
            progress: flexibleData["progress"] as? Double,
            imageUrl: flexibleData["imageUrl"] as? String,
            chartDataJson: chartDataJson,
            customFieldsJson: customFieldsJson,
            timestamp: Date()
        )

        Task {
            await activity.update(using: updatedState)
            print("[LiveActivity] ✅ Updated activity")
        }
    }

    // End the current Live Activity
    func endActivity() {
        guard let activity = currentActivity else {
            print("[LiveActivity] No active activity to end")
            return
        }

        Task {
            await activity.end(dismissalPolicy: .default)
            print("[LiveActivity] ✅ Ended activity")
            currentActivity = nil
        }
    }

    // Get all active activities
    func getActiveActivities() -> [[String: Any]] {
        var result: [[String: Any]] = []

        for activity in Activity<AmbiaActivityAttributes>.activities {
            result.append([
                "id": activity.id,
                "eventId": activity.attributes.eventId,
                "eventType": activity.attributes.eventType,
                "title": activity.content.state.title
            ])
        }

        return result
    }
}

// MARK: - Activity Attributes

@available(iOS 16.1, *)
struct AmbiaActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Core fields
        var title: String
        var subtitle: String?
        var body: String?
        var icon: String
        var color: String

        // Flexible UI elements
        var progress: Double?           // For progress bars (0.0-1.0)
        var imageUrl: String?           // For images
        var chartDataJson: String?      // JSON string for chart data
        var customFieldsJson: String?   // JSON string for custom fields
        var timestamp: Date
    }

    // Static attributes (don't change during activity lifetime)
    var eventId: String
    var eventType: String  // "flight", "meeting", "appointment", "deadline"
    var priority: String   // "low", "medium", "high"
}
