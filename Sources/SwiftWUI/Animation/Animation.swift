/// Rounds to at most 4 decimal places, then formats via the shared `cssNumber`
/// (Foundation-free, no trailing-zero noise) — see Styles/CSSValues.swift.
func cssNumber4(_ d: Double) -> String {
    cssNumber((d * 10_000).rounded() / 10_000)
}

public struct Animation: Equatable {
    enum Curve: Equatable {
        case linear
        case cubicBezier(Double, Double, Double, Double)
        case spring(duration: Double, bounce: Double)
    }

    var curve: Curve
    var duration: Double
    var delay: Double = 0
    var speedFactor: Double = 1
    var repeatCount: Double = 1
    var autoreverses: Bool = false
    var isForever: Bool = false

    private init(curve: Curve, duration: Double) {
        self.curve = curve
        self.duration = duration
    }

    public static func linear(duration: Double) -> Animation {
        Animation(curve: .linear, duration: duration)
    }
    public static func easeIn(duration: Double) -> Animation {
        Animation(curve: .cubicBezier(0.42, 0, 1, 1), duration: duration)
    }
    public static func easeOut(duration: Double) -> Animation {
        Animation(curve: .cubicBezier(0, 0, 0.58, 1), duration: duration)
    }
    public static func easeInOut(duration: Double) -> Animation {
        Animation(curve: .cubicBezier(0.42, 0, 0.58, 1), duration: duration)
    }
    public static func timingCurve(_ c0x: Double, _ c0y: Double, _ c1x: Double, _ c1y: Double, duration: Double) -> Animation {
        Animation(curve: .cubicBezier(c0x, c0y, c1x, c1y), duration: duration)
    }
    public static func spring(duration: Double = 0.5, bounce: Double = 0.0) -> Animation {
        Animation(curve: .spring(duration: duration, bounce: bounce), duration: duration)
    }

    public static let smooth = Animation.spring(duration: 0.55, bounce: 0)
    public static let snappy = Animation.spring(duration: 0.4, bounce: 0.15)
    public static let bouncy = Animation.spring(duration: 0.5, bounce: 0.3)
    public static let `default` = Animation.smooth

    public func delay(_ s: Double) -> Animation {
        var copy = self
        copy.delay = s
        return copy
    }
    public func speed(_ factor: Double) -> Animation {
        var copy = self
        copy.speedFactor = factor
        return copy
    }
    public func repeatCount(_ n: Int, autoreverses: Bool = true) -> Animation {
        var copy = self
        copy.repeatCount = Double(n)
        copy.autoreverses = autoreverses
        copy.isForever = false
        return copy
    }
    public func repeatForever(autoreverses: Bool = true) -> Animation {
        var copy = self
        copy.isForever = true
        copy.autoreverses = autoreverses
        return copy
    }

    public func resolved() -> ResolvedTiming {
        let easing: String
        var durationSeconds = duration
        switch curve {
        case .linear:
            easing = "linear"
        case .cubicBezier(let x1, let y1, let x2, let y2):
            easing = Animation.bezierEasing(x1, y1, x2, y2)
        case .spring(let springDuration, let bounce):
            let (settleMs, easingStr) = SpringSolver.solve(duration: springDuration, bounce: bounce)
            durationSeconds = settleMs / 1000
            easing = easingStr
        }
        return ResolvedTiming(
            durationMs: durationSeconds * 1000 / speedFactor,
            easing: easing,
            delayMs: delay * 1000 / speedFactor,
            iterations: isForever ? .infinity : repeatCount,
            autoreverses: autoreverses
        )
    }

    /// CSS defines `ease-in`/`ease-out`/`ease-in-out` as these exact bezier constants —
    /// emit the keyword directly rather than the equivalent `cubic-bezier(...)`.
    private static func bezierEasing(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> String {
        if (x1, y1, x2, y2) == (0.42, 0, 1, 1) { return "ease-in" }
        if (x1, y1, x2, y2) == (0, 0, 0.58, 1) { return "ease-out" }
        if (x1, y1, x2, y2) == (0.42, 0, 0.58, 1) { return "ease-in-out" }
        return "cubic-bezier(\(cssNumber4(x1)), \(cssNumber4(y1)), \(cssNumber4(x2)), \(cssNumber4(y2)))"
    }
}

public struct ResolvedTiming: Equatable {
    public var durationMs: Double
    public var easing: String
    public var delayMs: Double
    public var iterations: Double
    public var autoreverses: Bool
    public var isInfinite: Bool { iterations == .infinity }

    public init(durationMs: Double, easing: String, delayMs: Double, iterations: Double = 1, autoreverses: Bool) {
        self.durationMs = durationMs
        self.easing = easing
        self.delayMs = delayMs
        self.iterations = iterations
        self.autoreverses = autoreverses
    }
}
