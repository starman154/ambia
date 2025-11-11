//
//  AmbiaAPIClient.swift
//  Ambia
//
//  Service layer for communicating with Ambia backend API
//

import Foundation

class AmbiaAPIClient {
    static let shared = AmbiaAPIClient()

    // Backend URL - Update this with your production URL
    private let baseURL = "http://localhost:3000/api"

    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = formatter.date(from: dateString) {
                return date
            }

            // Fallback without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }

        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Ambient Events API

    /// GET /ambient/events/:userId
    /// Fetch active ambient events for a user
    func fetchActiveEvents(
        for userId: String,
        type: EventType? = nil
    ) async throws -> [AmbientEvent] {
        var components = URLComponents(string: "\(baseURL)/ambient/events/\(userId)")!

        if let type = type {
            components.queryItems = [
                URLQueryItem(name: "type", value: type.rawValue)
            ]
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let eventsResponse = try jsonDecoder.decode(AmbientEventsResponse.self, from: data)
        return eventsResponse.events
    }

    /// GET /ambient/events/details/:eventId
    /// Get details of a specific event
    func fetchEvent(eventId: String) async throws -> AmbientEvent {
        guard let url = URL(string: "\(baseURL)/ambient/events/details/\(eventId)") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        struct EventResponse: Codable {
            let success: Bool
            let event: AmbientEvent
        }

        let eventResponse = try jsonDecoder.decode(EventResponse.self, from: data)
        return eventResponse.event
    }

    /// POST /ambient/events/:eventId/interact
    /// Track user interaction with an event
    func trackInteraction(
        eventId: String,
        userId: String,
        interactionType: InteractionType,
        metadata: [String: AnyCodable]? = nil
    ) async throws {
        guard let url = URL(string: "\(baseURL)/ambient/events/\(eventId)/interact") else {
            throw APIError.invalidURL
        }

        let requestBody = EventInteractionRequest(
            userId: userId,
            interactionType: interactionType.rawValue,
            metadata: metadata
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(requestBody)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Device Management API

    /// POST /ambient/devices/register
    /// Register or update device token for push notifications
    func registerDevice(
        userId: String,
        deviceToken: String,
        deviceName: String? = nil,
        osVersion: String? = nil,
        notificationsEnabled: Bool = true,
        liveActivitiesEnabled: Bool = true,
        dynamicIslandEnabled: Bool = true
    ) async throws {
        guard let url = URL(string: "\(baseURL)/ambient/devices/register") else {
            throw APIError.invalidURL
        }

        let requestBody = DeviceRegistrationRequest(
            userId: userId,
            deviceToken: deviceToken,
            deviceType: "ios",
            deviceName: deviceName,
            osVersion: osVersion,
            notificationsEnabled: notificationsEnabled,
            liveActivitiesEnabled: liveActivitiesEnabled,
            dynamicIslandEnabled: dynamicIslandEnabled
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(requestBody)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// PUT /ambient/devices/:deviceId/preferences
    /// Update device notification preferences
    func updateDevicePreferences(
        deviceId: String,
        notificationsEnabled: Bool? = nil,
        liveActivitiesEnabled: Bool? = nil,
        dynamicIslandEnabled: Bool? = nil
    ) async throws {
        guard let url = URL(string: "\(baseURL)/ambient/devices/\(deviceId)/preferences") else {
            throw APIError.invalidURL
        }

        var body: [String: Bool] = [:]
        if let notificationsEnabled = notificationsEnabled {
            body["notificationsEnabled"] = notificationsEnabled
        }
        if let liveActivitiesEnabled = liveActivitiesEnabled {
            body["liveActivitiesEnabled"] = liveActivitiesEnabled
        }
        if let dynamicIslandEnabled = dynamicIslandEnabled {
            body["dynamicIslandEnabled"] = dynamicIslandEnabled
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Interaction Types
enum InteractionType: String {
    case shown
    case tap
    case expand
    case dismiss
    case swipeAway = "swipe_away"
    case complete
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
