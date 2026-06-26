@testable import Acalum
import XCTest

final class PlaybackHistoryStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PlaybackHistoryStore.clear()
    }

    override func tearDown() {
        PlaybackHistoryStore.clear()
        super.tearDown()
    }

    private func track(_ id: String) -> Track {
        Track(
            id: id, title: "Track \(id)", composer: "Composer", performer: nil,
            sourceName: "Internet Archive", sourceURL: URL(string: "https://archive.org/details/\(id)"),
            audioURL: URL(string: "https://archive.org/download/\(id).mp3")!,
            durationSeconds: 200, artworkURL: nil, license: "Public Domain", year: nil,
            explanation: nil)
    }

    func testEmptyInitially() {
        XCTAssertTrue(PlaybackHistoryStore.isEmpty)
        XCTAssertNil(PlaybackHistoryStore.pop())
    }

    func testPushAndPopIsLIFO() {
        PlaybackHistoryStore.push(track("a"))
        PlaybackHistoryStore.push(track("b"))
        XCTAssertEqual(PlaybackHistoryStore.pop()?.id, "b")
        XCTAssertEqual(PlaybackHistoryStore.pop()?.id, "a")
        XCTAssertTrue(PlaybackHistoryStore.isEmpty)
    }

    func testPushDeduplicatesAndMovesToFront() {
        PlaybackHistoryStore.push(track("a"))
        PlaybackHistoryStore.push(track("b"))
        PlaybackHistoryStore.push(track("a"))
        XCTAssertEqual(PlaybackHistoryStore.loadPreviousTracks().map(\.id), ["a", "b"])
    }

    func testCapacityIsCapped() {
        for i in 0..<(PlaybackHistoryStore.capacity + 10) {
            PlaybackHistoryStore.push(track("t\(i)"))
        }
        XCTAssertEqual(PlaybackHistoryStore.loadPreviousTracks().count, PlaybackHistoryStore.capacity)
    }

    func testPersistsAcrossLoad() {
        PlaybackHistoryStore.push(track("a"))
        let reloaded = PlaybackHistoryStore.loadPreviousTracks()
        XCTAssertEqual(reloaded.first?.id, "a")
    }

    func testClear() {
        PlaybackHistoryStore.push(track("a"))
        PlaybackHistoryStore.clear()
        XCTAssertTrue(PlaybackHistoryStore.isEmpty)
    }
}
