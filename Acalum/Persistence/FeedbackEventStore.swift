import Foundation

extension Notification.Name {
    static let feedbackEventRecorded = Notification.Name("acalum.feedbackEventRecorded")
}

final class FeedbackEventStore {
    private static let eventsKey = "acalum_unsent_events"

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("acalum_pending_events.json")
    }

    static func loadPendingEvents() -> [FeedbackEvent] {
        if let events = loadFromFile() {
            return events
        }
        let migrated = migrateFromUserDefaults()
        if !migrated.isEmpty {
            saveToFile(migrated)
        }
        return migrated
    }

    static func savePendingEvents(_ events: [FeedbackEvent]) {
        saveToFile(events)
    }

    static func appendEvent(_ event: FeedbackEvent) {
        var events = loadFromFile() ?? migrateFromUserDefaults()
        events.append(event)
        saveToFile(events)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .feedbackEventRecorded, object: nil)
        }
    }

    static func removePendingEvents(_ eventIDs: Set<UUID>) {
        var events = loadFromFile() ?? []
        events.removeAll { eventIDs.contains($0.id) }
        saveToFile(events)
    }

    static func clearAllPending() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func loadFromFile() -> [FeedbackEvent]? {
        guard let data = try? Data(contentsOf: fileURL),
              let events = try? JSONDecoder().decode([FeedbackEvent].self, from: data) else {
            return nil
        }
        return events
    }

    private static func saveToFile(_ events: [FeedbackEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func migrateFromUserDefaults() -> [FeedbackEvent] {
        guard let data = UserDefaults.standard.data(forKey: eventsKey),
              let events = try? JSONDecoder().decode([FeedbackEvent].self, from: data) else {
            return []
        }
        UserDefaults.standard.removeObject(forKey: eventsKey)
        return events
    }
}
