@testable import Acalum
import XCTest

final class QueryTextBuilderTests: XCTestCase {
    func testPromptWithPills() {
        let pills = [
            Pill(id: "instrument:guitar", label: "Guitar", category: .instrument, semanticPhrase: "solo classical guitar"),
            Pill(id: "mood:calm", label: "Calm", category: .mood, semanticPhrase: "calm, peaceful"),
            Pill(id: "context:reading", label: "Reading", category: .context, semanticPhrase: "reading music, unobtrusive background music"),
        ]
        let result = QueryTextBuilder.buildQuery(
            prompt: "quiet Spanish guitar at dusk",
            pills: pills
        )
        XCTAssertEqual(
            result,
            "quiet Spanish guitar at dusk. Music qualities: solo classical guitar, calm, peaceful, reading music, unobtrusive background music."
        )
    }

    func testEmptyPromptWithPills() {
        let pills = [
            Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano"),
        ]
        let result = QueryTextBuilder.buildQuery(prompt: "", pills: pills)
        XCTAssertEqual(result, "public domain music. Music qualities: solo piano.")
    }

    func testPromptWithoutPills() {
        let result = QueryTextBuilder.buildQuery(
            prompt: "melancholy piano for reading",
            pills: []
        )
        XCTAssertEqual(result, "melancholy piano for reading")
    }

    func testEmptyPromptNoPills() {
        let result = QueryTextBuilder.buildQuery(prompt: "", pills: [])
        XCTAssertEqual(result, "public domain music")
    }

    func testWhitespaceOnlyPromptTreatedAsEmpty() {
        let result = QueryTextBuilder.buildQuery(prompt: "   ", pills: [])
        XCTAssertEqual(result, "public domain music")
    }

    func testTrailingPeriodNotDuplicated() {
        let result = QueryTextBuilder.buildQuery(
            prompt: "quiet guitar.",
            pills: [Pill(id: "mood:calm", label: "Calm", category: .mood, semanticPhrase: "calm, peaceful")]
        )
        XCTAssertFalse(result.contains(".."))
        XCTAssertTrue(result.hasPrefix("quiet guitar."))
    }

    func testPillWithoutSemanticPhraseFallsBackToLabel() {
        let pill = Pill(id: "instrument:guitar", label: "Guitar", category: .instrument)
        let result = QueryTextBuilder.buildQuery(prompt: "", pills: [pill])
        XCTAssertTrue(result.contains("guitar"))
    }

    func testDeterministicOutput() {
        let pills = [Pill(id: "mood:calm", label: "Calm", category: .mood, semanticPhrase: "calm, peaceful")]
        let a = QueryTextBuilder.buildQuery(prompt: "test", pills: pills)
        let b = QueryTextBuilder.buildQuery(prompt: "test", pills: pills)
        XCTAssertEqual(a, b)
    }
}
