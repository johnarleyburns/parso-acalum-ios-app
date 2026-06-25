import Accelerate
import Foundation

enum Embedding512Error: Error, LocalizedError {
    case invalidDimension(Int)

    var errorDescription: String? {
        switch self {
        case .invalidDimension(let count):
            return "Expected 512 dimensions, got \(count)"
        }
    }
}

struct Embedding512: Equatable, Codable {
    static let dimension = 512

    let values: [Float]

    init(values: [Float]) throws {
        guard values.count == Self.dimension else {
            throw Embedding512Error.invalidDimension(values.count)
        }
        self.values = values
    }

    static var zero: Embedding512 {
        try! Embedding512(values: [Float](repeating: 0, count: dimension))
    }

    func l2Norm() -> Float {
        var sumOfSquares: Float = 0
        vDSP_dotpr(values, 1, values, 1, &sumOfSquares, vDSP_Length(Self.dimension))
        return sqrt(sumOfSquares)
    }

    func normalized() -> Embedding512 {
        let norm = l2Norm()
        guard norm > 0 else { return self }
        var result = values
        var divisor = norm
        vDSP_vsdiv(result, 1, &divisor, &result, 1, vDSP_Length(Self.dimension))
        return try! Embedding512(values: result)
    }

    func dot(_ other: Embedding512) -> Float {
        var result: Float = 0
        vDSP_dotpr(values, 1, other.values, 1, &result, vDSP_Length(Self.dimension))
        return result
    }

    func cosineSimilarity(to other: Embedding512) -> Float {
        let normA = l2Norm()
        let normB = other.l2Norm()
        guard normA > 0, normB > 0 else { return 0 }
        return dot(other) / (normA * normB)
    }

    func weightedAdding(_ other: Embedding512, selfWeight: Float, otherWeight: Float) -> Embedding512 {
        var result = [Float](repeating: 0, count: Self.dimension)
        var selfW = selfWeight
        var otherW = otherWeight
        vDSP_vsmul(values, 1, &selfW, &result, 1, vDSP_Length(Self.dimension))
        vDSP_vsma(other.values, 1, &otherW, result, 1, &result, 1, vDSP_Length(Self.dimension))
        return try! Embedding512(values: result)
    }
}
