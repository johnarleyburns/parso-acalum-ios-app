@testable import Acalum
import XCTest

final class TrackTests: XCTestCase {
    func testMockTracksNotEmpty() {
        XCTAssertFalse(MockData.tracks.isEmpty)
    }

    func testTrackHasRequiredFields() {
        for track in MockData.tracks {
            XCTAssertFalse(track.id.isEmpty)
            XCTAssertFalse(track.title.isEmpty)
            XCTAssertFalse(track.sourceName.isEmpty)
            XCTAssertGreaterThan(track.durationSeconds, 0)
        }
    }

    func testTrackDTOMapping() {
        let dto = TrackDTO(
            id: "test_id",
            title: "Test Track",
            composer: "Composer",
            performer: "Performer",
            audioURL: URL(string: "https://example.com/audio.mp3")!,
            durationSeconds: 180,
            sourceName: "Test Source",
            sourceURL: nil,
            license: "Public Domain",
            year: 1920,
            explanation: TrackExplanationDTO(
                reasons: ["Reason 1"],
                matchedPills: ["Guitar"],
                similarityScore: 0.9,
                userTasteScore: 0.7
            )
        )

        let track = dto.toTrack()
        XCTAssertEqual(track.id, "test_id")
        XCTAssertEqual(track.title, "Test Track")
        XCTAssertEqual(track.explanation?.reasons.count, 1)
        XCTAssertEqual(track.explanation?.matchedPills.first, "Guitar")
    }
}
