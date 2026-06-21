@testable import Acalum
import XCTest

final class VectorMathTests: XCTestCase {
    func testDecodeFloat16BlobEmptyData() {
        let result = VectorMath.decodeFloat16Blob(Data())
        XCTAssertEqual(result, [])
    }

    func testDecodeFloat16BlobSingleValue() {
        let one: Float16 = 1.0
        let data = withUnsafeBytes(of: one) { Data($0) }
        let result = VectorMath.decodeFloat16Blob(data)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], 1.0, accuracy: 1e-3)
    }

    func testDecodeFloat16BlobFourValues() {
        let values: [Float16] = [-1.0, 0.0, 0.5, 1.0]
        let data = values.withUnsafeBytes { Data($0) }
        let result = VectorMath.decodeFloat16Blob(data)
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0], -1.0, accuracy: 1e-3)
        XCTAssertEqual(result[1], 0.0, accuracy: 1e-3)
        XCTAssertEqual(result[2], 0.5, accuracy: 1e-3)
        XCTAssertEqual(result[3], 1.0, accuracy: 1e-3)
    }

    func testDecodeFloat16BlobRoundtrip() {
        var floatValues = [Float](repeating: 0, count: 512)
        for i in 0..<512 { floatValues[i] = Float.random(in: -1...1) }

        let float16Values = floatValues.map { Float16($0) }
        let data = float16Values.withUnsafeBytes { Data($0) }

        let decoded = VectorMath.decodeFloat16Blob(data)
        XCTAssertEqual(decoded.count, 512)

        for i in 0..<512 {
            XCTAssertEqual(decoded[i], floatValues[i], accuracy: 1e-3,
                           "Mismatch at index \(i): expected \(floatValues[i]), got \(decoded[i])")
        }
    }

    func testDecodeFloat16Blob512CountMatchesCLAP() {
        let values = [Float16](repeating: Float16(0.25), count: 512)
        let data = values.withUnsafeBytes { Data($0) }
        XCTAssertEqual(data.count, 1024)

        let result = VectorMath.decodeFloat16Blob(data)
        XCTAssertEqual(result.count, 512)
    }
}
