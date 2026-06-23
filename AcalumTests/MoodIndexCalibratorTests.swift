@testable import Acalum
import XCTest

final class MoodIndexCalibratorTests: XCTestCase {
    func testAnchorsMapToTargetPercent() {
        let cal = MoodIndexCalibrator(sLo: 0.18, pLo: 0.12, sHi: 0.45, pHi: 0.92)
        let lo = cal.index(0.18)
        let hi = cal.index(0.45)
        XCTAssertTrue((0...20).contains(lo), "Expected ~12, got \(lo)")
        XCTAssertTrue((85...100).contains(hi), "Expected ~92, got \(hi)")
    }

    func testMonotonic() {
        let cal = MoodIndexCalibrator()
        let idx1 = cal.index(0.1)
        let idx2 = cal.index(0.3)
        let idx3 = cal.index(0.5)
        let idx4 = cal.index(0.8)
        XCTAssertLessThanOrEqual(idx1, idx2)
        XCTAssertLessThanOrEqual(idx2, idx3)
        XCTAssertLessThanOrEqual(idx3, idx4)
    }

    func testClampsZeroToHundred() {
        let cal = MoodIndexCalibrator()
        for raw in stride(from: -1.0, through: 2.0, by: 0.1) {
            let idx = cal.index(Float(raw))
            XCTAssertTrue((0...100).contains(idx), "Index \(idx) out of range for raw \(raw)")
        }
    }

    func testZeroInputGivesLowOutput() {
        let cal = MoodIndexCalibrator()
        let idx = cal.index(0)
        XCTAssertLessThan(idx, 20)
    }

    func testOneInputGivesHighOutput() {
        let cal = MoodIndexCalibrator()
        let idx = cal.index(1.0)
        XCTAssertGreaterThan(idx, 80)
    }
}
