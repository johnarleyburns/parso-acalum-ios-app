@testable import Acalum
import XCTest

final class Embedding512Tests: XCTestCase {
    func testRejectsWrongDimension() {
        XCTAssertThrowsError(try Embedding512(values: [1.0, 2.0, 3.0])) { error in
            guard case Embedding512Error.invalidDimension(let count) = error else {
                XCTFail("Expected invalidDimension, got \(error)")
                return
            }
            XCTAssertEqual(count, 3)
        }
    }

    func testRejectsEmptyVector() {
        XCTAssertThrowsError(try Embedding512(values: []))
    }

    func testAccepts512Dimensions() {
        let values = [Float](repeating: 1.0, count: 512)
        XCTAssertNoThrow(try Embedding512(values: values))
    }

    func testL2Norm() {
        var values = [Float](repeating: 0, count: 512)
        values[0] = 3.0
        values[1] = 4.0
        let vec = try! Embedding512(values: values)
        XCTAssertEqual(vec.l2Norm(), 5.0, accuracy: 1e-5)
    }

    func testNormalizedHasUnitNorm() {
        var values = [Float](repeating: 0, count: 512)
        for i in 0..<512 { values[i] = Float(i) }
        let vec = try! Embedding512(values: values)
        let normed = vec.normalized()
        XCTAssertEqual(normed.l2Norm(), 1.0, accuracy: 1e-5)
    }

    func testCosineSimilarityWithSelf() {
        var values = [Float](repeating: 0, count: 512)
        for i in 0..<512 { values[i] = Float(i % 17) - 8.0 }
        let vec = try! Embedding512(values: values).normalized()
        XCTAssertEqual(vec.cosineSimilarity(to: vec), 1.0, accuracy: 1e-5)
    }

    func testCosineSimilarityOrthogonal() {
        var a = [Float](repeating: 0, count: 512)
        var b = [Float](repeating: 0, count: 512)
        for i in 0..<256 { a[i] = 1.0 }
        for i in 256..<512 { b[i] = 1.0 }
        let vecA = try! Embedding512(values: a).normalized()
        let vecB = try! Embedding512(values: b).normalized()
        XCTAssertEqual(vecA.cosineSimilarity(to: vecB), 0.0, accuracy: 1e-5)
    }

    func testDotProductNormalized() {
        var values = [Float](repeating: 0, count: 512)
        for i in 0..<512 { values[i] = Float.random(in: -1...1) }
        let normed = try! Embedding512(values: values).normalized()
        XCTAssertEqual(normed.dot(normed), 1.0, accuracy: 1e-4)
    }

    func testZeroVectorHasZeroNorm() {
        XCTAssertEqual(Embedding512.zero.l2Norm(), 0.0)
    }

    func testCosineSimilarityWithZeroReturnsZero() {
        var values = [Float](repeating: 0, count: 512)
        values[0] = 1.0
        let vec = try! Embedding512(values: values)
        XCTAssertEqual(vec.cosineSimilarity(to: .zero), 0.0)
    }
}
