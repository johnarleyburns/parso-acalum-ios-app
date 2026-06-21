import Foundation

struct CLAPTokenizerOutput {
    let inputIDs: [Int]
    let attentionMask: [Int]
}

struct CLAPTokenizerTrace {
    struct PretokenDetail {
        let pretoken: String
        let utf8Bytes: [UInt8]
        let byteSymbols: [String]
        let bpeMergeSteps: [(step: Int, pair0: String, pair1: String, rank: Int)]
        let bpeResult: [String]
    }
    let text: String
    let pretokens: [String]
    let details: [PretokenDetail]
    let allBPETokens: [String]
    let tokenIDs: [Int]
    let tokenIDMap: [(token: String, id: Int)]
    let attentionMask: [Int]
}

protocol CLAPTokenizerProtocol {
    func encode(_ text: String, maxLength: Int) throws -> CLAPTokenizerOutput
    func encodeWithTrace(_ text: String, maxLength: Int) throws -> (CLAPTokenizerOutput, CLAPTokenizerTrace)
}

enum CLAPTokenizerError: Error, LocalizedError {
    case vocabNotLoaded
    case mergesNotLoaded
    case configNotLoaded

    var errorDescription: String? {
        switch self {
        case .vocabNotLoaded:
            return "Tokenizer vocabulary could not be loaded."
        case .mergesNotLoaded:
            return "BPE merge rules could not be loaded."
        case .configNotLoaded:
            return "Tokenizer config could not be loaded."
        }
    }
}

final class CLAPTokenizer: CLAPTokenizerProtocol {

    private let vocab: [String: Int]
    private let mergeRanks: [String: Int]
    private let bosTokenID: Int
    private let eosTokenID: Int
    private let padTokenID: Int
    private let byteEncoder: [UInt8: String]
    private let pretokenizer: NSRegularExpression

    init() throws {
        guard let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "json"),
              let mergesURL = Bundle.main.url(forResource: "merges", withExtension: "txt"),
              let configURL = Bundle.main.url(forResource: "tokenizer_config", withExtension: "json")
        else {
            throw CLAPTokenizerError.vocabNotLoaded
        }

        let vocabData = try Data(contentsOf: vocabURL)
        self.vocab = try JSONDecoder().decode([String: Int].self, from: vocabData)

        let mergesText = try String(contentsOf: mergesURL, encoding: .utf8)
        var ranks: [String: Int] = [:]
        let lines = mergesText.components(separatedBy: "\n")
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            ranks[trimmed] = idx
        }
        self.mergeRanks = ranks

        let configData = try Data(contentsOf: configURL)
        let config = try JSONDecoder().decode(TokenizerConfig.self, from: configData)
        self.bosTokenID = config.bosTokenID
        self.eosTokenID = config.eosTokenID
        self.padTokenID = config.padTokenID

        if let beURL = Bundle.main.url(forResource: "byte_encoder", withExtension: "json") {
            let beData = try Data(contentsOf: beURL)
            let beMap = try JSONDecoder().decode([String: Int].self, from: beData)
            var encoder: [UInt8: String] = [:]
            for (key, value) in beMap {
                if let byte = UInt8(key), let scalar = UnicodeScalar(value) {
                    encoder[byte] = String(scalar)
                }
            }
            self.byteEncoder = encoder
        } else {
            self.byteEncoder = CLAPTokenizer.buildByteEncoder()
        }

        self.pretokenizer = try NSRegularExpression(
            pattern: #"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"#
        )
    }

    func encode(_ text: String, maxLength: Int = 77) throws -> CLAPTokenizerOutput {
        let (output, _) = try encodeWithTrace(text, maxLength: maxLength)
        return output
    }

    func encodeWithTrace(_ text: String, maxLength: Int = 77) throws -> (CLAPTokenizerOutput, CLAPTokenizerTrace) {
        let pretokens = applyPretokenizer(text)

        var bpeTokens: [String] = []
        var traceDetails: [CLAPTokenizerTrace.PretokenDetail] = []

        for pretoken in pretokens {
            let utf8Bytes = Array(pretoken.utf8)
            let symbols = utf8Bytes.compactMap { byteEncoder[$0] }

            var bpeSteps: [(step: Int, pair0: String, pair1: String, rank: Int)] = []
            let merged: String
            if symbols.isEmpty {
                merged = ""
            } else {
                let (mergedStr, steps) = bpeWithTrace(symbols)
                merged = mergedStr
                bpeSteps = steps
            }

            let pieces = merged.components(separatedBy: " ").filter { !$0.isEmpty }

            traceDetails.append(CLAPTokenizerTrace.PretokenDetail(
                pretoken: pretoken,
                utf8Bytes: utf8Bytes,
                byteSymbols: symbols,
                bpeMergeSteps: bpeSteps,
                bpeResult: pieces
            ))

            bpeTokens.append(contentsOf: pieces)
        }

        var tokenIDs = [bosTokenID]
        var tokenIDMap: [(token: String, id: Int)] = []
        for token in bpeTokens {
            if let id = vocab[token] {
                tokenIDs.append(id)
                tokenIDMap.append((token: token, id: id))
            }
        }
        tokenIDs.append(eosTokenID)

        var attentionMask: [Int]
        if tokenIDs.count > maxLength {
            tokenIDs[tokenIDs.count - 1] = eosTokenID
            tokenIDs = Array(tokenIDs.prefix(maxLength))
            attentionMask = [Int](repeating: 1, count: tokenIDs.count)
        } else {
            attentionMask = [Int](repeating: 1, count: tokenIDs.count)
            let padCount = maxLength - tokenIDs.count
            attentionMask.append(contentsOf: [Int](repeating: 0, count: padCount))
            tokenIDs.append(contentsOf: [Int](repeating: padTokenID, count: padCount))
        }

        let trace = CLAPTokenizerTrace(
            text: text,
            pretokens: pretokens,
            details: traceDetails,
            allBPETokens: bpeTokens,
            tokenIDs: tokenIDs,
            tokenIDMap: tokenIDMap,
            attentionMask: attentionMask
        )

        return (CLAPTokenizerOutput(inputIDs: tokenIDs, attentionMask: attentionMask), trace)
    }

    private func applyPretokenizer(_ text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        let matches = pretokenizer.matches(in: text, range: range)
        return matches.compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    private func bpe(_ symbols: [String]) -> String {
        let (result, _) = bpeWithTrace(symbols)
        return result
    }

    private func bpeWithTrace(_ symbols: [String]) -> (String, [(step: Int, pair0: String, pair1: String, rank: Int)]) {
        var word = symbols
        var pairs = getPairs(word)
        var steps: [(step: Int, pair0: String, pair1: String, rank: Int)] = []
        var stepCount = 0

        while true {
            guard let bestPair = pairs.min(by: { pairRank($0) < pairRank($1) }),
                  pairRank(bestPair) < Int.max
            else { break }

            steps.append((step: stepCount, pair0: bestPair.0, pair1: bestPair.1, rank: pairRank(bestPair)))

            var newWord: [String] = []
            var i = 0
            while i < word.count {
                if i < word.count - 1,
                   word[i] == bestPair.0,
                   word[i + 1] == bestPair.1
                {
                    newWord.append(bestPair.0 + bestPair.1)
                    i += 2
                } else {
                    newWord.append(word[i])
                    i += 1
                }
            }
            word = newWord
            if word.count == 1 { break }
            pairs = getPairs(word)
            stepCount += 1
        }

        return (word.joined(separator: " "), steps)
    }

    private func getPairs(_ word: [String]) -> [(String, String)] {
        guard word.count >= 2 else { return [] }
        var pairs: [(String, String)] = []
        for i in 0..<(word.count - 1) {
            pairs.append((word[i], word[i + 1]))
        }
        return pairs
    }

    private func pairRank(_ pair: (String, String)) -> Int {
        let key = "\(pair.0) \(pair.1)"
        return mergeRanks[key] ?? Int.max
    }

    static func buildByteEncoder() -> [UInt8: String] {
        var mapping: [UInt8: String] = [:]

        for b: UInt8 in 33...126 {
            mapping[b] = String(UnicodeScalar(b))
        }
        for b: UInt8 in 161...172 {
            mapping[b] = String(UnicodeScalar(b))
        }
        for b: UInt8 in 174...255 {
            mapping[b] = String(UnicodeScalar(b))
        }

        let gaps: [UInt8] = (0...32).map(UInt8.init) + [
            127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138,
            139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150,
            151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 173,
        ]
        var n: UInt16 = 256
        for b in gaps {
            if let scalar = UnicodeScalar(n) {
                mapping[b] = String(scalar)
            }
            n += 1
        }

        return mapping
    }
}

private struct TokenizerConfig: Decodable {
    let bosTokenID: Int
    let eosTokenID: Int
    let padTokenID: Int

    enum CodingKeys: String, CodingKey {
        case bosTokenID = "bos_token_id"
        case eosTokenID = "eos_token_id"
        case padTokenID = "pad_token_id"
    }
}
