import Testing
@testable import SwiftWUI

/// Parses `linear(v1 p1%, v2 p2%, …)` back into its sampled values.
private func parseLinearValues(_ easing: String) -> [Double] {
    guard easing.hasPrefix("linear("), easing.hasSuffix(")") else { return [] }
    let inner = easing.dropFirst("linear(".count).dropLast()
    let tokens = inner.split(whereSeparator: { $0 == "," || $0 == " " })
    return tokens.enumerated().compactMap { index, token in
        index.isMultiple(of: 2) ? Double(token) : nil   // even tokens are values, odd are "N%" percents
    }
}

@Suite struct AnimationTimingTests {
    @Test func criticallyDampedNeverOvershoots() {
        let (_, easing) = SpringSolver.solve(duration: 0.55, bounce: 0)
        #expect(easing.hasPrefix("linear("))
        let values = parseLinearValues(easing)
        #expect(!values.isEmpty)
        #expect(values.allSatisfy { $0 >= 0 && $0 <= 1.0001 })
    }
    @Test func bouncyOvershoots() {
        let (_, easing) = SpringSolver.solve(duration: 0.5, bounce: 0.3)
        let values = parseLinearValues(easing)
        #expect(values.contains { $0 > 1.0 })
    }
    @Test func settleTimeGrowsWithBounce() {
        #expect(SpringSolver.solve(duration: 0.5, bounce: 0.3).durationMs > 500)
    }
    @Test func presets() {
        #expect(Animation.default == .smooth)
    }
    @Test func speedHalvesDuration() {
        #expect(Animation.linear(duration: 1.0).speed(2).resolved().durationMs == 500)
    }
    @Test func repeatForeverIsInfinite() {
        #expect(Animation.linear(duration: 1).repeatForever().resolved().isInfinite)
    }
}
