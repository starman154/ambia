//
//  LiveActivityManager.swift
//  Ambia
//
//  Manages Live Activities lifecycle using ActivityKit
//  Supports Dynamic Island on iPhone 14 Pro+
//

import Foundation
import ActivityKit

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activeActivities: [String: Activity<AmbiaActivityAttributes>] = [:]

    private init() {}

    // MARK: - Live Activity Management

    /// Start a new Live Activity from an ambient event
    func startActivity(for event: AmbientEvent) async throws {
        // Check if Live Activities are supported and enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }

        // Don't start if we already have an activity for this event
        if activeActivities[event.id] != nil {
            print("Activity already exists for event \(event.id)")
            return
        }

        // Build activity attributes and content state
        let attributes = AmbiaActivityAttributes(
            eventId: event.id,
            eventType: event.eventType.rawValue,
            title: event.title
        )

        let contentState = AmbiaActivityAttributes.ContentState(
            subtitle: event.subtitle,
            body: event.body,
            data: event.data,
            icon: event.icon,
            color: event.color,
            priority: event.priority.rawValue,
            startTime: event.startTime,
            endTime: event.endTime
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: event.endTime),
                pushType: nil
            )

            activeActivities[event.id] = activity
            print("Started Live Activity for event: \(event.title)")

            // Track the interaction
            try? await AmbiaAPIClient.shared.trackInteraction(
                eventId: event.id,
                userId: event.userId ?? "",
                interactionType: .shown
            )

        } catch {
            print("Failed to start Live Activity: \(error)")
            throw error
        }
    }

    /// Update an existing Live Activity
    func updateActivity(for event: AmbientEvent) async throws {
        guard let activity = activeActivities[event.id] else {
            print("No activity found for event \(event.id)")
            return
        }

        let contentState = AmbiaActivityAttributes.ContentState(
            subtitle: event.subtitle,
            body: event.body,
            data: event.data,
            icon: event.icon,
            color: event.color,
            priority: event.priority.rawValue,
            startTime: event.startTime,
            endTime: event.endTime
        )

        await activity.update(using: contentState)
        print("Updated Live Activity for event: \(event.title)")
    }

    /// End a Live Activity
    func endActivity(for eventId: String, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        guard let activity = activeActivities[eventId] else {
            print("No activity found for event \(eventId)")
            return
        }

        await activity.end(using: nil, dismissalPolicy: dismissalPolicy)
        activeActivities.removeValue(forKey: eventId)
        print("Ended Live Activity for event \(eventId)")
    }

    /// End all active Live Activities
    func endAllActivities() async {
        for (eventId, activity) in activeActivities {
            await activity.end(using: nil, dismissalPolicy: .immediate)
            print("Ended Live Activity for event \(eventId)")
        }
        activeActivities.removeAll()
    }

    /// Get all currently active activities
    func getActiveActivities() -> [Activity<AmbiaActivityAttributes>] {
        return Activity<AmbiaActivityAttributes>.activities
    }

    /// Sync active activities with backend events
    func syncActivities(with events: [AmbientEvent]) async {
        // Get current active activities
        let currentActivities = Activity<AmbiaActivityAttributes>.activities

        // Build a set of event IDs from backend
        let eventIds = Set(events.map { $0.id })

        // End activities that are no longer in the backend
        for activity in currentActivities {
            if !eventIds.contains(activity.attributes.eventId) {
                await endActivity(for: activity.attributes.eventId)
            }
        }

        // Start or update activities from backend
        for event in events {
            if event.eventType == .liveActivity {
                if activeActivities[event.id] != nil {
                    try? await updateActivity(for: event)
                } else {
                    try? await startActivity(for: event)
                }
            }
        }
    }
}

// MARK: - Activity Attributes
@available(iOS 16.1, *)
struct AmbiaActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var subtitle: String?
        var body: String?
        var data: [String: AnyCodable]
        var icon: String?
        var color: String?
        var priority: String
        var startTime: Date?
        var endTime: Date?
    }

    var eventId: String
    var eventType: String
    var title: String
}

// Make AnyCodable Hashable for ActivityKit
extension AnyCodable: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch value {
        case let bool as Bool:
            hasher.combine(bool)
        case let int as Int:
            hasher.combine(int)
        case let double as Double:
            hasher.combine(double)
        case let string as String:
            hasher.combine(string)
        default:
            hasher.combine(0)
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (let lhs as Bool, let rhs as Bool):
            return lhs == rhs
        case (let lhs as Int, let rhs as Int):
            return lhs == rhs
        case (let lhs as Double, let rhs as Double):
            return lhs == rhs
        case (let lhs as String, let rhs as String):
            return lhs == rhs
        default:
            return false
        }
    }
}
