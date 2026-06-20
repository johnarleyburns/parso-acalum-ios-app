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
    // TODO: Load AcalumCLAPTextEncoder.mlpackage via Core ML
    // private var model: MLModel?

    // TODO: Load exported tokenizer from the same laion/clap-htsat-fused checkpoint
    // private var tokenizer: CLAPTokenizer?

    func embed(prompt: String, pills: [DiscoveryPill]) async throws -> Embedding512 {
        // TODO: Full pipeline when Core ML model is available:
        //
        // 1. Build query text
        //    let queryText = QueryTextBuilder.buildQuery(prompt: prompt, pills: pills)
        //
        // 2. Tokenize
        //    let tokens = try tokenizer.encode(queryText)
        //    // tokens.inputIDs: [Int]
        //    // tokens.attentionMask: [Int]
        //
        // 3. Create Core ML input
        //    let input = AcalumCLAPTextEncoderInput(
        //        input_ids: MLMultiArray(tokens.inputIDs),
        //        attention_mask: MLMultiArray(tokens.attentionMask)
        //    )
        //
        // 4. Run prediction
        //    let output = try model.prediction(from: input)
        //
        // 5. Extract 512-dim vector from output
        //    let rawVector = output.featureValue(for: "text_embedding")
        //
        // 6. L2 normalize
        //    return try Embedding512(values: rawFloats).normalized()

        throw CLAPTextEmbeddingError.modelNotBundled
    }
}
