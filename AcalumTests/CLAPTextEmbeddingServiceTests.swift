@testable import Acalum
import XCTest

final class CLAPTextEmbeddingServiceTests: XCTestCase {

    func testInitLoadsModelWhenBundled() throws {
        guard Bundle.main.url(forResource: "AcalumCLAPTextEncoder", withExtension: "mlmodelc") != nil else {
            throw XCTSkip("AcalumCLAPTextEncoder.mlmodelc not bundled")
        }
        let service = try CLAPTextEmbeddingService()
        XCTAssertNotNil(service)
    }

    func testEmbedProduces512DimVectorWhenModelAvailable() async throws {
        guard let modelURL = Bundle.main
            .url(forResource: "AcalumCLAPTextEncoder", withExtension: "mlmodelc")
        else {
            throw XCTSkip("AcalumCLAPTextEncoder.mlmodelc not bundled for testing")
        }

        let service = try CLAPTextEmbeddingService(modelURL: modelURL)
        let vector = try await service.embed(prompt: "test", pills: [])

        XCTAssertEqual(vector.values.count, 512)
    }

    func testEmbedOutputIsNormalized() async throws {
        guard let modelURL = Bundle.main
            .url(forResource: "AcalumCLAPTextEncoder", withExtension: "mlmodelc")
        else {
            throw XCTSkip("AcalumCLAPTextEncoder.mlmodelc not bundled for testing")
        }

        let service = try CLAPTextEmbeddingService(modelURL: modelURL)
        let vector = try await service.embed(prompt: "quiet Spanish guitar", pills: [])

        let norm = vector.l2Norm()
        XCTAssertEqual(norm, 1.0, accuracy: 1e-4, "Output vector should be L2 normalized")
    }

    func testEmbedSamePromptProducesSameVector() async throws {
        guard let modelURL = Bundle.main
            .url(forResource: "AcalumCLAPTextEncoder", withExtension: "mlmodelc")
        else {
            throw XCTSkip("AcalumCLAPTextEncoder.mlmodelc not bundled for testing")
        }

        let service = try CLAPTextEmbeddingService(modelURL: modelURL)
        let v1 = try await service.embed(prompt: "melancholy piano", pills: [])
        let v2 = try await service.embed(prompt: "melancholy piano", pills: [])

        let cos = v1.cosineSimilarity(to: v2)
        XCTAssertEqual(cos, 1.0, accuracy: 1e-5, "Same prompt should produce near-identical vectors")
    }

    func testEmbedDifferentPromptsProduceDifferentVectors() async throws {
        guard Bundle.main.url(forResource: "AcalumCLAPTextEncoder", withExtension: "mlmodelc") != nil else {
            throw XCTSkip("AcalumCLAPTextEncoder.mlmodelc not bundled for testing")
        }

        let service = try CLAPTextEmbeddingService()
        let v1 = try await service.embed(prompt: "peaceful violin music", pills: [])
        let v2 = try await service.embed(prompt: "dramatic organ music", pills: [])

        let cos = v1.cosineSimilarity(to: v2)
        XCTAssertLessThan(cos, 0.99, "Different prompts should produce different vectors")
    }

    func testMatchPythonTestVectors() async throws {
        guard Bundle.main.url(forResource: "AcalumCLAPTextEncoder", withExtension: "mlmodelc") != nil,
              Bundle.main.url(forResource: "test_vectors", withExtension: "json") != nil
        else {
            throw XCTSkip("AcalumCLAPTextEncoder.mlmodelc or test_vectors.json not bundled for testing")
        }

        let service = try CLAPTextEmbeddingService()

        let prompts: [(String, Float)] = [
            ("quiet Spanish guitar at dusk", 0.995),
            ("melancholy piano for reading", 0.995),
            ("Gregorian chant in an old cathedral", 0.995),
            ("early jazz from the 1920s", 0.995),
            ("romantic classical guitar", 0.995),
            ("soft public domain music for sleep", 0.995),
            ("baroque strings and harpsichord", 0.995),
            ("nostalgic old recordings", 0.995),
            ("peaceful violin music", 0.995),
            ("dramatic organ music", 0.995),
        ]

        let testVectorsURL = Bundle.main.url(forResource: "test_vectors", withExtension: "json")!
        let data = try Data(contentsOf: testVectorsURL)
        let testVectors = try JSONSerialization.jsonObject(with: data) as! [String: [Double]]

        for (prompt, minCosine) in prompts {
            guard let refVec = testVectors[prompt] else {
                XCTFail("Missing reference vector for \"\(prompt)\"")
                continue
            }

            let iosVec = try await service.embed(prompt: prompt, pills: [])
            let refEmbedding = try Embedding512(values: refVec.map { Float($0) }).normalized()
            let cosine = iosVec.cosineSimilarity(to: refEmbedding)

            XCTAssertGreaterThanOrEqual(
                cosine, Float(minCosine),
                "\"\(prompt)\": cosine=\(cosine) < \(minCosine)"
            )
        }
    }
}
