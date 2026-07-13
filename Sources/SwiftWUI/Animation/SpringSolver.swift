// ponytail: sin/cos/exp/cosh/sinh aren't in the stdlib — need libm directly.
// FoundationEssentials doesn't re-export libm on wasm32, so import the platform
// libc where these symbols actually live.
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

/// Closed-form damped harmonic oscillator sampled into a CSS `linear()` easing (anim spec §6.3).
enum SpringSolver {
    /// Apple spring parameter convention: `duration` sets the natural frequency,
    /// `bounce` maps to damping ratio (`bounce > 0` underdamped/overshoots,
    /// `bounce < 0` overdamped).
    /// - Returns: settle duration in ms (≥ perceptual `duration` for bounce > 0)
    ///   and a `linear(v1 p1%, v2 p2%, …)` easing string.
    static func solve(duration: Double, bounce: Double) -> (durationMs: Double, easing: String) {
        let zeta = 1 - min(1, max(-1, bounce))
        let omega = 2 * Double.pi / duration
        let settle = settleSeconds(omega: omega, zeta: zeta, duration: duration)
        let n = min(200, max(16, Int(settle * 120)))
        var stops: [String] = []
        stops.reserveCapacity(n)
        for i in 0..<n {
            let t = settle * Double(i) / Double(n - 1)
            let x: Double
            if i == 0 { x = 0 } else if i == n - 1 { x = 1 } else { x = position(t: t, omega: omega, zeta: zeta) }
            let percent = 100 * Double(i) / Double(n - 1)
            stops.append("\(cssNumber4(x)) \(cssNumber4(percent))%")
        }
        return (settle * 1000, "linear(\(stops.joined(separator: ", ")))")
    }

    private static func position(t: Double, omega: Double, zeta: Double) -> Double {
        if zeta < 1 {
            let omegaD = omega * (1 - zeta * zeta).squareRoot()
            let envelope = exp(-zeta * omega * t)
            let coeff = zeta * omega / omegaD
            let oscillation = cos(omegaD * t) + coeff * sin(omegaD * t)
            return 1 - envelope * oscillation
        } else if zeta == 1 {
            return 1 - exp(-omega * t) * (1 + omega * t)
        } else {
            let omegaD = omega * (zeta * zeta - 1).squareRoot()
            let envelope = exp(-zeta * omega * t)
            let coeff = zeta * omega / omegaD
            let oscillation = cosh(omegaD * t) + coeff * sinh(omegaD * t)
            return 1 - envelope * oscillation
        }
    }

    /// First `t` where `|x-1| < 0.001` and it stays inside that band thereafter,
    /// found by scanning forward in 1ms steps (capped at 5x duration).
    private static func settleSeconds(omega: Double, zeta: Double, duration: Double) -> Double {
        let cap = duration * 5
        let step = 0.001
        var t = 0.0
        var settled: Double?
        while t <= cap {
            let x = position(t: t, omega: omega, zeta: zeta)
            if abs(x - 1) < 0.001 {
                if settled == nil { settled = t }
            } else {
                settled = nil
            }
            t += step
        }
        return settled ?? cap
    }
}
