import Accelerate
import Foundation

enum VectorMath {
    static func decodeFloat16Blob(_ data: Data) -> [Float] {
        let count = data.count / 2
        guard count > 0 else { return [] }

        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt16.self).baseAddress else {
                return []
            }

            var result = [Float](repeating: 0, count: count)

            baseAddress.withMemoryRebound(to: Float16.self, capacity: count) { float16Ptr in
                var sourceBuffer = vImage_Buffer(
                    data: UnsafeMutableRawPointer(mutating: float16Ptr),
                    height: 1,
                    width: vImagePixelCount(count),
                    rowBytes: count * MemoryLayout<Float16>.stride
                )

                result.withUnsafeMutableBufferPointer { floatPtr in
                    var destBuffer = vImage_Buffer(
                        data: floatPtr.baseAddress!,
                        height: 1,
                        width: vImagePixelCount(count),
                        rowBytes: count * MemoryLayout<Float>.stride
                    )

                    vImageConvert_Planar16FtoPlanarF(&sourceBuffer, &destBuffer, 0)
                }
            }

            return result
        }
    }
}
