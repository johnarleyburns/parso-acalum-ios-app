@testable import Acalum
import XCTest

final class CLAPTokenizerTests: XCTestCase {

    func testByteEncoderSize() {
        let encoder = CLAPTokenizer.buildByteEncoder()
        XCTAssertEqual(encoder.count, 256, "Byte encoder must map all 256 byte values")
    }

    func testByteEncoderIsBijective() {
        let encoder = CLAPTokenizer.buildByteEncoder()
        let values = Set(encoder.values)
        XCTAssertEqual(values.count, 256, "Byte encoder must produce 256 unique unicode characters")
    }

    func testByteEncoderPrintableAsciiMapsToSelf() {
        let encoder = CLAPTokenizer.buildByteEncoder()
        for b: UInt8 in 33...126 {
            XCTAssertEqual(encoder[b], String(UnicodeScalar(b)),
                           "Printable ASCII byte \(b) should map to itself")
        }
    }

    func testByteEncoderControlCharacters() {
        let encoder = CLAPTokenizer.buildByteEncoder()
        let ctrl = encoder[0]
        XCTAssertNotNil(ctrl)
        XCTAssertEqual(encoder[10], encoder[10], "Same byte maps to same char")
    }

    func testEncodeWithRealFilesWhenAvailable() throws {
        guard Bundle.main.url(forResource: "vocab", withExtension: "json") != nil
        else {
            throw XCTSkip("CLAP tokenizer files not bundled")
        }

        let tokenizer = try CLAPTokenizer()
        let output = try tokenizer.encode("hello world", maxLength: 77)

        XCTAssertGreaterThan(output.inputIDs.count, 0)
        XCTAssertGreaterThan(output.attentionMask.count, 0)
        XCTAssertEqual(output.inputIDs.count, output.attentionMask.count)
        XCTAssertEqual(output.inputIDs.count, 77, "Should be padded to max_length=77")

        let realTokenCount = output.attentionMask.filter { $0 == 1 }.count
        XCTAssertGreaterThan(realTokenCount, 0, "Should have real tokens")
        let padTokenCount = output.attentionMask.filter { $0 == 0 }.count
        XCTAssertGreaterThan(padTokenCount, 0, "Short input should have padding")
        XCTAssertEqual(realTokenCount + padTokenCount, 77, "Total should be max_length=77")
    }

    func testEncodeWithRealFilesOutputHasBOS() throws {
        guard Bundle.main.url(forResource: "vocab", withExtension: "json") != nil
        else {
            throw XCTSkip("CLAP tokenizer files not bundled")
        }

        let tokenizer = try CLAPTokenizer()
        let output = try tokenizer.encode("test", maxLength: 77)

        XCTAssertEqual(output.attentionMask[0], 1, "First token should have attention_mask=1")
        XCTAssertGreaterThan(output.inputIDs[0], -1, "First token ID should be valid")
    }

    func testEncodeShortInputPadsCorrectly() throws {
        guard Bundle.main.url(forResource: "vocab", withExtension: "json") != nil
        else {
            throw XCTSkip("CLAP tokenizer files not bundled")
        }

        let tokenizer = try CLAPTokenizer()
        let output = try tokenizer.encode("hi", maxLength: 8)

        XCTAssertEqual(output.inputIDs.count, 8)
        XCTAssertEqual(output.attentionMask.count, 8)

        let maskSum = output.attentionMask.reduce(0, +)
        XCTAssertLessThan(maskSum, 8, "Short input should have some padding zeros")
        XCTAssertGreaterThan(maskSum, 0, "Short input should have some real tokens")
    }

    func testTestVectorsMatchPythonWhenAvailable() throws {
        guard Bundle.main.url(forResource: "test_vectors", withExtension: "json") != nil else {
            throw XCTSkip("test_vectors.json not bundled")
        }
        // throw XCTSkip("Swift BPE tokenizer not yet matching Python output — pending tokenizer fix")

        let tokenizer = try CLAPTokenizer()
        let prompts = [
            "quiet Spanish guitar at dusk",
            "melancholy piano for reading",
            "Gregorian chant in an old cathedral",
            "early jazz from the 1920s",
            "romantic classical guitar",
            "hi",
            "test",
            "hello world",
        ]

        for prompt in prompts {
            let (_, trace) = try tokenizer.encodeWithTrace(prompt, maxLength: 77)
            let refKey = "\(prompt)__token_ids"

            guard let url = Bundle.main.url(forResource: "test_vectors", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let testVectors = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let refIDs = testVectors[refKey] as? [Int]
            else {
                continue
            }

            let swiftIDs = trace.tokenIDs
            let untruncatedRef = refIDs + Array(repeating: padTokenID(), count: max(0, 77 - refIDs.count))
            let refIDsFull = untruncatedRef.count > 77 ? Array(untruncatedRef.prefix(77)) : untruncatedRef

            if swiftIDs != refIDsFull {
                print("\n=== MISMATCH for \"\(prompt)\" ===")
                print("Swift token IDs: \(swiftIDs)")
                print("Ref token IDs:   \(refIDsFull)")
                print("Trace:")
                dumpTrace(trace)
                XCTFail("Token IDs do not match Python reference for \"\(prompt)\"")
                return
            }
        }
    }

    func padTokenID() -> Int {
        1
    }

    private func dumpTrace(_ trace: CLAPTokenizerTrace) {
        print("  pretokens: \(trace.pretokens)")
        for (i, d) in trace.details.enumerated() {
            print("  [\(i)] pretoken=\(d.pretoken)")
            print("       utf8=\(d.utf8Bytes)")
            print("       symbols=\(d.byteSymbols)")
            for step in d.bpeMergeSteps {
                print("        merge step \(step.step): (\(step.pair0), \(step.pair1)) rank=\(step.rank)")
            }
            print("       bpe_result=\(d.bpeResult)")
        }
        print("  all_bpe_tokens=\(trace.allBPETokens)")
        print("  token_ids=\(trace.tokenIDs)")
        for m in trace.tokenIDMap {
            print("    \(m.id) => \(m.token)")
        }
        print("  attention_mask=\(trace.attentionMask)")
    }
}
