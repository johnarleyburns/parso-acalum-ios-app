import CoreML
import Foundation

enum CLAPTextEmbeddingError: Error, LocalizedError {
    case modelNotBundled
    case tokenizerNotLoaded
    case predictionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotBundled:
            return "AcalumCLAPTextEncoder.mlpackage is not bundled in this build."
        case .tokenizerNotLoaded:
            return "CLAP tokenizer could not be loaded."
        case .predictionFailed(let detail):
            return "Core ML prediction failed: \(detail)"
        }
    }
}

final class CLAPTextEmbeddingService: TextEmbeddingService {
    private let model: MLModel
    private let tokenizer: CLAPTokenizer

    init() throws {
        guard let modelURL = Bundle.main.url(
            forResource: "AcalumCLAPTextEncoder",
            withExtension: "mlmodelc"
        ) else {
            throw CLAPTextEmbeddingError.modelNotBundled
        }
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        self.model = try MLModel(contentsOf: modelURL, configuration: config)
        self.tokenizer = try CLAPTokenizer()
    }

    init(modelURL: URL, tokenizer: CLAPTokenizer = try! CLAPTokenizer()) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        self.model = try MLModel(contentsOf: modelURL, configuration: config)
        self.tokenizer = tokenizer
    }

    func embed(prompt: String, pills: [DiscoveryPill]) async throws -> Embedding512 {
        let queryText = QueryTextBuilder.buildQuery(prompt: prompt, pills: pills)

        let maxLength = 77
        let tokenOutput = try tokenizer.encode(queryText, maxLength: maxLength)

        let inputIDs = try MLMultiArray(
            shape: [1, NSNumber(value: maxLength)],
            dataType: .int32
        )
        let attentionMask = try MLMultiArray(
            shape: [1, NSNumber(value: maxLength)],
            dataType: .float32
        )

        for i in 0..<tokenOutput.inputIDs.count {
            inputIDs[[0, NSNumber(value: i)] as [NSNumber]] = NSNumber(value: tokenOutput.inputIDs[i])
            attentionMask[[0, NSNumber(value: i)] as [NSNumber]] = NSNumber(value: Float(tokenOutput.attentionMask[i]))
        }

        guard let inputFeatures = try? MLDictionaryFeatureProvider(dictionary: [
            "input_ids": inputIDs,
            "attention_mask": attentionMask,
        ]) else {
            throw CLAPTextEmbeddingError.predictionFailed("Failed to create input features")
        }

        let prediction = try await model.prediction(from: inputFeatures)

        guard let outputMLArray = prediction.featureValue(for: "text_embedding")?.multiArrayValue else {
            throw CLAPTextEmbeddingError.predictionFailed("Missing text_embedding output")
        }

        let dim = Embedding512.dimension
        var values = [Float](repeating: 0, count: dim)
        for i in 0..<min(dim, outputMLArray.count) {
            values[i] = Float(truncating: outputMLArray[[0, NSNumber(value: i)] as [NSNumber]])
        }

        return try Embedding512(values: values).normalized()
    }
}
