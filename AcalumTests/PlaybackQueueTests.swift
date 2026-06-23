@testable import Acalum
import XCTest

final class PlaybackQueueTests: XCTestCase {
    func testInitWithTracks() {
        let queue = PlaybackQueue(tracks: MockData.tracks)
        XCTAssertNotNil(queue.current)
        XCTAssertEqual(queue.current?.id, MockData.tracks.first?.id)
        XCTAssertEqual(queue.upcomingCount, MockData.tracks.count - 1)
    }

    func testInitEmpty() {
        let queue = PlaybackQueue()
        XCTAssertNil(queue.current)
        XCTAssertTrue(queue.isEmpty)
    }

    func testSkipToNext() {
        var queue = PlaybackQueue(tracks: MockData.tracks)
        let first = queue.current
        let next = queue.skipToNext()
        XCTAssertNotNil(next)
        XCTAssertNotEqual(next?.id, first?.id)
        XCTAssertEqual(queue.history.count, 1)
        XCTAssertEqual(queue.history.first?.id, first?.id)
    }

    func testSkipExhaustsQueue() {
        var queue = PlaybackQueue(tracks: Array(MockData.tracks.prefix(2)))
        _ = queue.skipToNext()
        let last = queue.skipToNext()
        XCTAssertNil(last)
        XCTAssertNil(queue.current)
        XCTAssertEqual(queue.history.count, 2)
    }

    func testAppendTracksDeduplicates() {
        var queue = PlaybackQueue(tracks: Array(MockData.tracks.prefix(2)))
        queue.appendTracks(MockData.tracks)
        let totalExpected = MockData.tracks.count - 1
        XCTAssertEqual(queue.upcomingCount, totalExpected)
    }

    func testJumpToFirstUpcoming() {
        var queue = PlaybackQueue(tracks: MockData.tracks)
        let originalCurrent = queue.current
        let targetUpcoming = queue.upcoming[0]
        let originalUpcomingCount = queue.upcomingCount

        let result = queue.jumpTo(index: 0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, targetUpcoming.id)
        XCTAssertEqual(queue.history.count, 1)
        XCTAssertEqual(queue.history.first?.id, originalCurrent?.id)
        XCTAssertEqual(queue.upcomingCount, originalUpcomingCount - 1)
    }

    func testJumpToMiddleUpcoming() {
        var queue = PlaybackQueue(tracks: MockData.tracks)
        let targetIndex = 2
        let targetTrack = queue.upcoming[targetIndex]
        let result = queue.jumpTo(index: targetIndex)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, targetTrack.id)
        XCTAssertEqual(queue.history.count, targetIndex + 1)
        XCTAssertNotEqual(queue.current?.id, MockData.tracks.first?.id)
    }

    func testJumpToOutOfBoundsReturnsNil() {
        var queue = PlaybackQueue(tracks: MockData.tracks)
        let result = queue.jumpTo(index: 999)
        XCTAssertNil(result)
    }
}
