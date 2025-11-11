//
//  AmbiaApp.swift
//  Ambia
//
//  Main app entry point with notification and activity setup
//

import SwiftUI

@main
struct AmbiaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var eventStore = EventStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(eventStore)
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Request notification permissions
        Task {
            do {
                let authorized = try await NotificationManager.shared.requestAuthorization()
                print("Notifications authorized: \(authorized)")
            } catch {
                print("Failed to request notifications: \(error)")
            }
        }

        return true
    }

    // Handle successful APNs registration
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // TODO: Get actual user ID from authentication
        let userId = "test-user-id"

        Task {
            await NotificationManager.shared.registerDeviceToken(deviceToken, userId: userId)
        }
    }

    // Handle failed APNs registration
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationManager.shared.handleRegistrationFailure(error)
    }
}

// MARK: - Event Store (ObservableObject for state management)
class EventStore: ObservableObject {
    @Published var events: [AmbientEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var pollTimer: Timer?

    /// Start polling for events
    func startPolling(userId: String) {
        // Initial fetch
        Task {
            await fetchEvents(userId: userId)
        }

        // Poll every 30 seconds
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchEvents(userId: userId)
            }
        }
    }

    /// Stop polling
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Fetch events from backend
    @MainActor
    func fetchEvents(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedEvents = try await AmbiaAPIClient.shared.fetchActiveEvents(for: userId)
            events = fetchedEvents

            // Sync with Live Activities
            if #available(iOS 16.1, *) {
                await LiveActivityManager.shared.syncActivities(with: fetchedEvents)
            }

            print("Fetched \(fetchedEvents.count) events")
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to fetch events: \(error)")
        }

        isLoading = false
    }

    /// Dismiss an event
    @MainActor
    func dismissEvent(_ event: AmbientEvent) async {
        guard let userId = event.userId else { return }

        do {
            try await AmbiaAPIClient.shared.trackInteraction(
                eventId: event.id,
                userId: userId,
                interactionType: .dismiss
            )

            // Remove from local state
            events.removeAll { $0.id == event.id }

            // End Live Activity
            if #available(iOS 16.1, *) {
                await LiveActivityManager.shared.endActivity(for: event.id)
            }
        } catch {
            print("Failed to dismiss event: \(error)")
        }
    }
}
