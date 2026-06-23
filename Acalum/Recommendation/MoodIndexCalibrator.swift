import Foundation

struct MoodIndexCalibrator {
    let k: Float
    let s0: Float

    init(sLo: Float = 0.18, pLo: Float = 0.12, sHi: Float = 0.80, pHi: Float = 0.92) {
        func L(_ p: Float) -> Float { log(p / (1 - p)) }
        k  = (L(pHi) - L(pLo)) / (sHi - sLo)
        s0 = sHi - L(pHi) / k
    }

    func index(_ s: Float) -> Int { Int((100 / (1 + exp(-k * (s - s0)))).rounded()) }
}
