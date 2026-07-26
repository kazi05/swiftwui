import Testing
@testable import SwiftWUI

@Suite struct KeyframesValueTests {
    @Test func fromToRuleText() {
        let spin = Keyframes("spin") {
            $0.from { $0.transform(.rotate(.deg(0))) }
            $0.to { $0.transform(.rotate(.deg(360))) }
        }
        #expect(spin.ruleText.hasPrefix("@keyframes spin-"))
        #expect(spin.ruleText.hasSuffix(" { from { transform: rotate(0deg) } to { transform: rotate(360deg) } }"))
    }

    @Test func percentageStopsKeepDeclarationOrder() {
        let pulse = Keyframes {
            $0.at(0) { $0.opacity(1) }
            $0.at(50) { $0.opacity(0.4) }
            $0.at(100) { $0.opacity(1) }
        }
        #expect(pulse.ruleText.hasPrefix("@keyframes swui-kf-"))
        #expect(pulse.ruleText.hasSuffix(" { 0% { opacity: 1 } 50% { opacity: 0.4 } 100% { opacity: 1 } }"))
    }

    @Test func percentClampedToRange() {
        let kf = Keyframes {
            $0.at(-30) { $0.opacity(0) }
            $0.at(180) { $0.opacity(1) }
        }
        #expect(kf.ruleText.contains("0% { opacity: 0 }"))
        #expect(kf.ruleText.contains("100% { opacity: 1 }"))
        #expect(!kf.ruleText.contains("-30%"))
        #expect(!kf.ruleText.contains("180%"))
    }

    @Test func identicalBodiesShareName() {
        let a = Keyframes("spin") { $0.to { $0.opacity(0) } }
        let b = Keyframes("spin") { $0.to { $0.opacity(0) } }
        #expect(a.cssName == b.cssName)
        #expect(a == b)
    }

    @Test func sameNameDifferentBodiesDoNotCollide() {
        let a = Keyframes("spin") { $0.to { $0.opacity(0) } }
        let b = Keyframes("spin") { $0.to { $0.opacity(0.5) } }
        #expect(a.cssName != b.cssName)
        #expect(a.cssName.hasPrefix("spin-"))
        #expect(b.cssName.hasPrefix("spin-"))
    }

    @Test func namelessGetsFrameworkPrefix() {
        let kf = Keyframes { $0.to { $0.opacity(0) } }
        #expect(kf.cssName.hasPrefix("swui-kf-"))
    }

    @Test func emptyKeyframesReportsEmpty() {
        let kf = Keyframes("noop") { _ in }
        #expect(kf.isEmpty)
        let onlyEmptyStop = Keyframes("noop") { $0.from { _ in } }
        #expect(onlyEmptyStop.isEmpty)
    }

    @Test func invalidNameFallsBackAndCannotBreakOutOfThePrelude() {
        let evil = Keyframes("spin { } body { background: red } x") { $0.to { $0.opacity(0) } }
        #expect(evil.cssName.hasPrefix("swui-kf-"))
        #expect(!evil.ruleText.contains("body {"))
        #expect(evil.ruleText.hasPrefix("@keyframes swui-kf-"))
    }

    @Test func validNameWithHyphensAndUnderscoresSurvives() {
        let kf = Keyframes("fade_in-slow") { $0.to { $0.opacity(1) } }
        #expect(kf.cssName.hasPrefix("fade_in-slow-"))
    }
}
