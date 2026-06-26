@testable import Acalum
import XCTest

final class PillTests: XCTestCase {
    func testPillEquality() {
        let a = Pill(id: "sound:guitar", label: "Guitar", category: .sound,
                     embeddingPhrase: "guitar", metadataTerms: ["guitar"])
        let b = Pill(id: "sound:guitar", label: "Guitar", category: .sound,
                     embeddingPhrase: "guitar", metadataTerms: ["guitar"])
        XCTAssertEqual(a, b)
    }

    func testPillSetToggle() {
        var selected: Set<Pill> = []
        let guitar = Pill(id: "sound:guitar", label: "Guitar", category: .sound,
                          embeddingPhrase: "guitar", metadataTerms: ["guitar"])
        selected.insert(guitar)
        XCTAssertTrue(selected.contains(guitar))
        selected.remove(guitar)
        XCTAssertFalse(selected.contains(guitar))
    }

    func testMockPillsNotEmpty() {
        XCTAssertFalse(MockData.pills.isEmpty)
    }

    func testMockPillsContainAllCategories() {
        let categories = Set(MockData.pills.map(\.category))
        XCTAssertTrue(categories.contains(.sound))
        XCTAssertTrue(categories.contains(.style))
        XCTAssertTrue(categories.contains(.tradition))
        XCTAssertTrue(categories.contains(.listeningMode))
    }

    func testLegacyInitPreservesCompatibility() {
        let pill = Pill(id: "legacy", label: "Old Pill", category: .instrument, semanticPhrase: "old phrase")
        XCTAssertEqual(pill.embeddingPhrase, "old phrase")
        XCTAssertTrue(pill.metadataTerms.isEmpty)
        XCTAssertFalse(pill.hasMetadataTerms)
    }

    func testHasMetadataTerms() {
        let with = Pill(id: "sound:piano", label: "Piano", category: .sound,
                        embeddingPhrase: "piano", metadataTerms: ["piano"])
        let without = Pill(id: "mode:focus", label: "Focus", category: .listeningMode,
                           embeddingPhrase: "focus music", metadataTerms: [])
        XCTAssertTrue(with.hasMetadataTerms)
        XCTAssertFalse(without.hasMetadataTerms)
    }
}
