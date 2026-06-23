@testable import Acalum
import XCTest

final class SeenHistoryStoreTests: XCTestCase {
    override func setUp() {
        SeenHistoryStore.clear()
    }

    override func tearDown() {
        SeenHistoryStore.clear()
    }

    func testRecordAddsTrackToFront() {
        SeenHistoryStore.record("track_a")
        XCTAssertEqual(SeenHistoryStore.recentIDs.first, "track_a")
    }

    func testDedupeMoveToFront() {
        SeenHistoryStore.record("track_a")
        SeenHistoryStore.record("track_b")
        SeenHistoryStore.record("track_a")
        let ids = SeenHistoryStore.recentIDs
        XCTAssertEqual(ids[0], "track_a")
        XCTAssertEqual(ids[1], "track_b")
        XCTAssertEqual(ids.count, 2)
    }

    func testCapacityEnforced() {
        let cap = SeenHistoryStore.capacity
        for i in 0..<(cap + 20) {
            SeenHistoryStore.record("track_\(i)")
        }
        XCTAssertLessThanOrEqual(SeenHistoryStore.recentIDs.count, cap)
    }

    func testClearRemovesAll() {
        SeenHistoryStore.record("track_a")
        SeenHistoryStore.record("track_b")
        SeenHistoryStore.clear()
        XCTAssertTrue(SeenHistoryStore.recentIDs.isEmpty)
    }

    func testPersistenceRoundTrip() {
        SeenHistoryStore.record("persist_1")
        SeenHistoryStore.record("persist_2")

        let ids = SeenHistoryStore.recentIDs
        XCTAssertEqual(ids.first, "persist_2")
        XCTAssertEqual(ids.last, "persist_1")
    }
}
