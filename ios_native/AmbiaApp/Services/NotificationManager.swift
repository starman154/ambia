//
//  NotificationManager.swift
//  Ambia
//
//  Manages push notifications and APNs device registration
//

import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var deviceToken: String?
    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    // MARK: - Permission Request

    /// Request notification permissions from user
    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]

        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)

            if granted {
                // Register for remote notifications on main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }

            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            throw error
        }
    }

    /// Check current notification authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Device Token Management

    /// Store device token and register with backend
    func registerDeviceToken(_ deviceToken: Data, userId: String) async {
        // Convert device token to string
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString

        print("Device token registered: \(tokenString)")

        // Get device info
        let deviceName = UIDevice.current.name
        let osVersion = UIDevice.current.systemVersion

        // Register with backend API
        do {
            try await AmbiaAPIClient.shared.registerDevice(
                userId: userId,
                deviceToken: tokenString,
                deviceName: deviceName,
                osVersion: osVersion,
                notificationsEnabled: true,
                liveActivitiesEnabled: true,
                dynamicIslandEnabled: true
            )
            print("Device registered with backend successfully")
        } catch {
            print("Failed to register device with backend: \(error)")
        }
    }

    /// Handle failed device token registration
    func handleRegistrationFailure(_ error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    /// Handle user tapping on notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Extract event ID from notification payload
        if let eventId = userInfo["event_id"] as? String,
           let userId = userInfo["user_id"] as? String {
            print("User tapped notification for event: \(eventId)")

            // Track interaction
            Task {
                try? await AmbiaAPIClient.shared.trackInteraction(
                    eventId: eventId,
                    userId: userId,
                    interactionType: .tap
                )
            }

            // TODO: Navigate to event details view
        }

        completionHandler()
    }

    // MARK: - Local Notifications

    /// Schedule a local notification (for testing)
    func scheduleLocalNotification(
        title: String,
        body: String,
        subtitle: String? = nil,
        timeInterval: TimeInterval = 5
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        if let subtitle = subtitle {
            content.subtitle = subtitle
        }

        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule local notification: \(error)")
            } else {
                print("Local notification scheduled successfully")
            }
        }
    }
}
