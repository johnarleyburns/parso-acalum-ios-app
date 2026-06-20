@testable import Acalum
import XCTest

final class PillTests: XCTestCase {
    func testPillEquality() {
        let a = Pill(id: "instrument:guitar", label: "Guitar", category: .instrument)
        let b = Pill(id: "instrument:guitar", label: "Guitar", category: .instrument)
        XCTAssertEqual(a, b)
    }

    func testPillSetToggle() {
        var selected: Set<Pill> = []
        let guitar = Pill(id: "instrument:guitar", label: "Guitar", category: .instrument)
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
        XCTAssertTrue(categories.contains(.instrument))
        XCTAssertTrue(categories.contains(.mood))
        XCTAssertTrue(categories.contains(.context))
        XCTAssertTrue(categories.contains(.era))
    }
}
