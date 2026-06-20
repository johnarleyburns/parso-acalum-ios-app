import Foundation

final class FeedbackEventStore {
    private static let eventsKey = "acalum_unsent_events"

    static func loadUnsentEvents() -> [FeedbackEvent] {
        guard let data = UserDefaults.standard.data(forKey: eventsKey),
              let events = try? JSONDecoder().decode([FeedbackEvent].self, from: data) else {
            return []
        }
        return events
    }

    static func saveUnsentEvents(_ events: [FeedbackEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: eventsKey)
        }
    }

    static func appendEvent(_ event: FeedbackEvent) {
        var events = loadUnsentEvents()
        events.append(event)
        saveUnsentEvents(events)
    }
}
