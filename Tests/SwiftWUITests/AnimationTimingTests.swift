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

    // Invalid-timing guards (crash-class): `element.animate` throws on non-finite
    // or negative numbers → wasm trap. Every ResolvedTiming numeric field must be
    // finite and non-negative (iterations may be `.infinity` by design), and the
    // spring solver's easing string must never contain "nan"/"inf".
    private func assertSane(_ t: ResolvedTiming, file: StaticString = #filePath, line: UInt = #line) {
        #expect(t.durationMs.isFinite && t.durationMs >= 0)
        #expect(t.delayMs.isFinite && t.delayMs >= 0)
        #expect(t.iterations >= 0)                     // finite or +infinity, never negative/nan
        #expect(!t.easing.lowercased().contains("nan"))
        #expect(!t.easing.lowercased().contains("inf"))
    }
    @Test func springZeroDurationIsSane() {
        assertSane(Animation.spring(duration: 0).resolved())
        let (ms, easing) = SpringSolver.solve(duration: 0, bounce: 0)
        #expect(ms.isFinite && ms >= 0)
        #expect(!easing.lowercased().contains("nan") && !easing.lowercased().contains("inf"))
    }
    @Test func linearNegativeDurationIsSane() {
        assertSane(Animation.linear(duration: -1).resolved())
    }
    @Test func speedZeroTreatedAsOne() {
        assertSane(Animation.linear(duration: 1).speed(0).resolved())
    }
    @Test func speedInfinityTreatedAsOne() {
        assertSane(Animation.linear(duration: 1).speed(.infinity).resolved())
    }
}
