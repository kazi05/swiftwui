import Foundation
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

    @Test func nanPercentClampsToZero() {
        let kf = Keyframes { $0.at(.nan) { $0.opacity(0) } }
        #expect(kf.ruleText.contains("0% { opacity: 0 }"))
        #expect(!kf.ruleText.contains("nan"))
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
        let hasStop = Keyframes("noop") { $0.to { $0.opacity(0) } }
        #expect(!hasStop.isEmpty)
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

@Suite struct AnimationModifierCSSTests {
    private var spin: Keyframes {
        Keyframes("spin") {
            $0.from { $0.opacity(0) }
            $0.to { $0.opacity(1) }
        }
    }

    @Test func htmlTagPathRegistersDefinitionAndGatedRule() {
        let kf = spin
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.animation(kf, duration: .s(1), timingFunction: .linear,
                                        iterations: .infinite))
        #expect(css.contains("@keyframes \(kf.cssName) { from { opacity: 0 } to { opacity: 1 } }"))
        #expect(css.contains("@media (prefers-reduced-motion: no-preference) { .swui-"))
        #expect(css.contains("animation: \(kf.cssName) 1s linear 0ms infinite normal none"))
    }

    @Test func tagPathRegistersDefinition() {
        struct Box: Tag {
            let kf: Keyframes
            var body: some Tag { Div { Text("x") } }
        }
        let kf = spin
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Box(kf: kf).animation(kf, duration: .ms(500)))
        #expect(css.contains("@keyframes \(kf.cssName)"))
        #expect(css.contains("animation: \(kf.cssName) 500ms ease 0ms 1 normal none"))
    }

    @Test func definitionSitsOutsideTheMediaWrapper() {
        let kf = spin
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.animation(kf, duration: .s(1)))
        let definition = css.firstRange(of: "@keyframes")
        let wrapper = css.firstRange(of: "@media (prefers-reduced-motion")
        #expect(definition != nil && wrapper != nil)
        // registerRaw inserts with media "" so at-rules sort before conditionals
        #expect(definition!.lowerBound < wrapper!.lowerBound)
    }

    @Test func respectsReducedMotionFalseEmitsUngatedRule() {
        let kf = spin
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.animation(kf, duration: .s(1), iterations: .infinite,
                                        respectsReducedMotion: false))
        #expect(css.contains("@keyframes \(kf.cssName)"))
        #expect(!css.contains("prefers-reduced-motion"))
        #expect(css.contains("animation: \(kf.cssName) 1s ease 0ms infinite normal none"))
    }

    @Test func identicalKeyframesRegisterOnce() {
        let kf = spin
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div {
                Div { Text("a") }.animation(kf, duration: .s(1))
                Div { Text("b") }.animation(kf, duration: .s(2))
            })
        var count = 0
        var cursor = css.startIndex
        while let found = css.range(of: "@keyframes", range: cursor..<css.endIndex) {
            count += 1
            cursor = found.upperBound
        }
        #expect(count == 1)
    }

    @Test func unusedKeyframesEmitNothing() {
        _ = spin
        let (_, css) = HTMLRenderer.renderWithStylesheet(Div { Text("x") }.opacity(1))
        #expect(!css.contains("@keyframes"))
    }

    @Test func emptyKeyframesEmitNothing() {
        let empty = Keyframes("noop") { _ in }
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.animation(empty, duration: .s(1)))
        #expect(!css.contains("@keyframes"))
        #expect(!css.contains("animation:"))
    }

    @Test func allSixOperandsInCanonicalOrder() {
        let kf = spin
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.animation(kf, duration: .ms(250),
                                        timingFunction: .steps(4, .end),
                                        delay: .s(1), iterations: .count(3),
                                        direction: .alternateReverse, fillMode: .both))
        #expect(css.contains("animation: \(kf.cssName) 250ms steps(4, end) 1s 3 alternate-reverse both"))
    }
}
