//
//  ContentView.swift
//  Ambia
//
//  Main view with dynamic event rendering - NO HARDCODING
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var eventStore: EventStore
    @State private var userId = "test-user-id" // TODO: Get from authentication

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if eventStore.isLoading && eventStore.events.isEmpty {
                        ProgressView("Loading events...")
                            .padding()
                    } else if let errorMessage = eventStore.errorMessage {
                        ErrorView(message: errorMessage) {
                            Task {
                                await eventStore.fetchEvents(userId: userId)
                            }
                        }
                    } else if eventStore.events.isEmpty {
                        EmptyStateView()
                    } else {
                        ForEach(eventStore.events) { event in
                            DynamicEventCard(event: event)
                                .transition(.opacity)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Ambient Events")
            .refreshable {
                await eventStore.fetchEvents(userId: userId)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await eventStore.fetchEvents(userId: userId)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            eventStore.startPolling(userId: userId)
        }
        .onDisappear {
            eventStore.stopPolling()
        }
    }
}

// MARK: - Dynamic Event Card (NO HARDCODING!)
struct DynamicEventCard: View {
    let event: AmbientEvent
    @EnvironmentObject var eventStore: EventStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                if let icon = event.icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(eventColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)

                    if let subtitle = event.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                PriorityIndicator(priority: event.priority)
            }

            // Body
            if let body = event.body {
                Text(body)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            // Dynamic data rendering - NO HARDCODING!
            if !event.data.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(event.data.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(formatKey(key))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            if let value = event.data[key] {
                                Text(valueToString(value.value))
                                    .font(.caption)
                                    .bold()
                            }
                        }
                    }
                }
            }

            // Time info
            HStack {
                if let endTime = event.endTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(endTime, style: .relative)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Event type badge
                Text(event.eventType.rawValue.replacingOccurrences(of: "_", with: " ").uppercased())
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }

            // Actions
            HStack {
                Button(action: {
                    Task {
                        if #available(iOS 16.1, *) {
                            if event.eventType == .liveActivity {
                                try? await LiveActivityManager.shared.startActivity(for: event)
                            }
                        }
                    }
                }) {
                    Label("Show Live Activity", systemImage: "rectangle.stack.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: {
                    Task {
                        await eventStore.dismissEvent(event)
                    }
                }) {
                    Label("Dismiss", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    var eventColor: Color {
        guard let colorString = event.color else { return .blue }
        return parseEventColor(colorString)
    }

    func parseEventColor(_ colorString: String) -> Color {
        if colorString.hasPrefix("#") {
            let hex = String(colorString.dropFirst())
            guard hex.count == 6,
                  let r = Int(hex.prefix(2), radix: 16),
                  let g = Int(hex.dropFirst(2).prefix(2), radix: 16),
                  let b = Int(hex.dropFirst(4).prefix(2), radix: 16) else {
                return .blue
            }
            return Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
        }

        switch colorString.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        case "pink": return .pink
        default: return .blue
        }
    }

    func formatKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

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
        default:
            return "\(value)"
        }
    }
}

// MARK: - Priority Indicator
struct PriorityIndicator: View {
    let priority: Priority

    var body: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 12, height: 12)
    }

    var priorityColor: Color {
        switch priority {
        case .critical:
            return .red
        case .high:
            return .orange
        case .medium:
            return .blue
        case .low:
            return .gray
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Ambient Events")
                .font(.title2)
                .bold()

            Text("When Claude detects time-sensitive moments, they'll appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Error")
                .font(.title2)
                .bold()

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: retry) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let store = EventStore()
        store.events = [
            AmbientEvent(
                id: "1",
                userId: "test",
                eventType: .liveActivity,
                priority: .high,
                title: "Amtrak to NYC",
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
                imageUrl: nil,
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                validUntil: Date().addingTimeInterval(3600),
                status: .active,
                confidenceScore: 0.95,
                shownAt: nil,
                interactedAt: nil,
                dismissedAt: nil,
                createdAt: Date()
            )
        ]

        return ContentView()
            .environmentObject(store)
    }
}
