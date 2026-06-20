@testable import Acalum
import XCTest

final class FeedbackTrackerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        FeedbackEventStore.saveUnsentEvents([])
    }

    func testLogCreatesEvent() {
        let tracker = FeedbackTracker(sessionID: "test-session")
        tracker.log(type: .favorited, trackID: "track_001")

        let events = FeedbackEventStore.loadUnsentEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.type, .favorited)
        XCTAssertEqual(events.first?.trackID, "track_001")
        XCTAssertEqual(events.first?.sessionID, "test-session")
    }

    func testLogMultipleEvents() {
        let tracker = FeedbackTracker(sessionID: "test-session")
        tracker.log(type: .playStarted, trackID: "track_001")
        tracker.log(type: .skipped, trackID: "track_001", listenSeconds: 12)
        tracker.log(type: .pillSelected, selectedPillIDs: ["instrument:guitar"])

        let events = FeedbackEventStore.loadUnsentEvents()
        XCTAssertEqual(events.count, 3)
    }
}
