//
//  AmbientEvent.swift
//  Ambia
//
//  Data models for ambient events from Claude
//  NO HARDCODING - Supports ANY event structure dynamically
//

import Foundation

// MARK: - Ambient Event Model
struct AmbientEvent: Codable, Identifiable {
    let id: String
    let userId: String?
    let eventType: EventType
    let priority: Priority
    let title: String
    let subtitle: String?
    let body: String?

    // Dynamic data structure - Claude can put ANYTHING here
    // Examples:
    // - Amtrak: {"train": "Northeast Regional 190", "platform": "Track 7", "departure_time": "3:45 PM", "travel_time_mins": 18}
    // - Package: {"carrier": "UPS", "tracking": "1Z999AA10123456784", "delivery_window": "2:00 PM - 6:00 PM"}
    // - Timer: {"remaining_seconds": 180, "timer_name": "Pasta"}
    let data: [String: AnyCodable]

    let icon: String?
    let color: String?
    let imageUrl: String?

    let startTime: Date?
    let endTime: Date?
    let validUntil: Date

    let status: EventStatus
    let confidenceScore: Double?

    let shownAt: Date?
    let interactedAt: Date?
    let dismissedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case eventType = "event_type"
        case priority
        case title
        case subtitle
        case body
        case data
        case icon
        case color
        case imageUrl = "image_url"
        case startTime = "start_time"
        case endTime = "end_time"
        case validUntil = "valid_until"
        case status
        case confidenceScore = "confidence_score"
        case shownAt = "shown_at"
        case interactedAt = "interacted_at"
        case dismissedAt = "dismissed_at"
        case createdAt = "created_at"
    }
}

// MARK: - Event Type
enum EventType: String, Codable {
    case liveActivity = "live_activity"
    case dynamicIsland = "dynamic_island"
    case notification = "notification"
    case backgroundUpdate = "background_update"
}

// MARK: - Priority
enum Priority: String, Codable, Comparable {
    case critical
    case high
    case medium
    case low

    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Event Status
enum EventStatus: String, Codable {
    case pending
    case active
    case completed
    case cancelled
    case expired
}

// MARK: - AnyCodable (for dynamic JSON data)
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - API Response Models
struct AmbientEventsResponse: Codable {
    let success: Bool
    let events: [AmbientEvent]
}

struct EventInteractionRequest: Codable {
    let userId: String
    let interactionType: String
    let metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case userId = "userId"
        case interactionType = "interactionType"
        case metadata
    }
}

struct DeviceRegistrationRequest: Codable {
    let userId: String
    let deviceToken: String
    let deviceType: String
    let deviceName: String?
    let osVersion: String?
    let notificationsEnabled: Bool
    let liveActivitiesEnabled: Bool
    let dynamicIslandEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case userId
        case deviceToken
        case deviceType
        case deviceName
        case osVersion
        case notificationsEnabled
        case liveActivitiesEnabled
        case dynamicIslandEnabled
    }
}

// MARK: - Helper Extensions
extension AmbientEvent {
    var isExpired: Bool {
        validUntil < Date()
    }

    var isActive: Bool {
        status == .active && !isExpired
    }

    var isPending: Bool {
        status == .pending && !isExpired
    }

    // Dynamic data access helpers
    func dataValue<T>(forKey key: String) -> T? {
        data[key]?.value as? T
    }

    func dataString(forKey key: String) -> String? {
        dataValue(forKey: key)
    }

    func dataInt(forKey key: String) -> Int? {
        dataValue(forKey: key)
    }

    func dataDouble(forKey key: String) -> Double? {
        dataValue(forKey: key)
    }
}
