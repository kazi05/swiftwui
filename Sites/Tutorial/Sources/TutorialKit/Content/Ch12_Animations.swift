/// Chapter 12 — Animations (authored sections; no Figma reference).
public enum Ch12 {
    static let springCode = #"""
            Button(pulsed ? "Shrink" : "Grow") {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { pulsed.toggle() }
            }
"""#
    static let valueCode = #"""
            Div { "●" }
                .opacity(pulsed ? 1 : 0.3)
                .scaleEffect(pulsed ? 1.2 : 1.0)
                .animation(.spring(duration: 0.4, bounce: 0.3), value: pulsed)
"""#
    static let transitionCode = #"""
            if showBanner {
                P { "Hello from a transitioning banner." }
                    .transition(.opacity.combined(with: .offset(y: 12)))
            }
"""#
    static let transformCode = #"""
struct SpinAndSlide: Tag {
    @State private var active = false
    var body: some Tag {
        Div {
            Div { "▲" }
                .offset(x: active ? 40 : 0)
                .rotationEffect(active ? 45 : 0)
                .scaleEffect(active ? 1.3 : 1.0)
                .animation(.snappy, value: active)
            Button(active ? "Reset" : "Animate") { active.toggle() }
        }
    }
}
"""#
    static let completionCode = #"""
struct SaveButton: Tag {
    @State private var saved = false
    var body: some Tag {
        Div {
            Span { saved ? "✓ Saved" : "" }
                .opacity(saved ? 1 : 0)
                .animation(.smooth, value: saved)
            Button("Save") {
                withAnimation(.smooth, completion: { saved = false }) {
                    saved = true
                }
            }
        }
    }
}
"""#
    static let reducedMotionCode = #"""
struct MotionStatus: Tag {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var body: some Tag {
        P { reduceMotion ? "Reduced motion: ON — animations play instantly." : "Reduced motion: OFF." }
    }
}
"""#

    public static let chapter = Chapter(
        slug: "animations", track: .motion, kicker: "CHAPTER · MOTION",
        title: "Animations",
        tagline: "Spring-based motion for state changes and structural transitions — interruptible and accessible by default.",
        minutes: 20, kind: .chapter,
        sections: [
            Section(anchor: "springs", kicker: "01 · SPRINGS",
                    title: "withAnimation and springs",
                    intro: "Wrap state writes in withAnimation(_:) and every style change that write causes animates with that curve — physically based, interruptible, no durations to hand-tune.",
                    steps: [
                        Step("withAnimation(_:) sets the animation for every write inside its closure."),
                        Step(".smooth (the default) — spring(duration: 0.55, bounce: 0) — calm settle, no overshoot."),
                        Step(".snappy — spring(duration: 0.4, bounce: 0.15) — quick, with a light bounce."),
                        Step(".bouncy — spring(duration: 0.5, bounce: 0.3) — playful overshoot."),
                        Step("Scope an implicit animation to one value with .animation(_:value:) — it fires only when that value actually changes, never for unrelated updates to the same view.",
                             panel: .code(CodePanel(file: "AnimationDemo.swift", code: valueCode,
                                                    origin: .sample(path: "Examples/Counter/Sources/CounterApp.swift",
                                                                    marker: "anim-value")))),
                    ],
                    panel: .code(CodePanel(file: "AnimationDemo.swift", code: springCode,
                                           origin: .sample(path: "Examples/Counter/Sources/CounterApp.swift",
                                                           marker: "anim-spring")))),
            Section(anchor: "transitions", kicker: "02 · TRANSITIONS",
                    title: "Enter and exit with .transition",
                    intro: ".transition(_:) animates a view onto and off the page whenever its structural identity appears or disappears — an if branch, an optional, a keyed list row.",
                    steps: [
                        Step("Build an AnyTransition from .opacity, .scale(anchor:), .offset(x:y:), .move(edge:), or .slide."),
                        Step("Compose with .combined(with:) or split insertion/removal with .asymmetric(insertion:removal:)."),
                        Step("Enter plays active → identity on mount; exit plays identity → active, and the element is only removed from the DOM once the exit animation settles — never mid-flight."),
                        Step("The old CSS shorthand modifier is renamed to .cssTransition(String) — .transition(_:) now belongs to AnyTransition exclusively."),
                    ],
                    panel: .code(CodePanel(file: "AnimationDemo.swift", code: transitionCode,
                                           origin: .sample(path: "Examples/Counter/Sources/CounterApp.swift",
                                                           marker: "anim-transition")))),
            Section(anchor: "transform", kicker: "03 · TRANSFORMS",
                    title: "offset, scaleEffect, rotationEffect",
                    intro: "Each transform modifier writes its own CSS property — translate, rotate, scale — so every channel animates and retargets independently, even when several are chained on the same element.",
                    steps: [
                        Step(".offset(x:y:) translates via the translate property."),
                        Step(".scaleEffect(_:anchor:) and .rotationEffect(_:anchor:) write scale/rotate; anchor maps to transform-origin."),
                        Step("An element has exactly one transform-origin — combining .scaleEffect and .rotationEffect with two different non-center anchors on the same element isn't supported; wrap one in an extra element instead."),
                    ],
                    panel: .code(CodePanel(file: "SpinAndSlide.swift", code: transformCode,
                                           origin: .sample(path: "Examples/Counter/Sources/CounterApp.swift",
                                                           marker: "anim-transform")))),
            Section(anchor: "polish", kicker: "04 · POLISH",
                    title: "Completion handlers and reduced motion",
                    intro: "withAnimation(_:completion:) runs a closure once everything that transaction started has settled; \\.accessibilityReduceMotion reports the OS preference.",
                    steps: [
                        Step("withAnimation(_:completion:) fires completion once every animation the block started has settled — useful for chaining a follow-up state change."),
                        Step("With no animatable change (or reduced motion on) completion still fires, on the next microtask — it's never skipped."),
                        Step("\\.accessibilityReduceMotion mirrors prefers-reduced-motion: reduce. The engine already collapses every animation to duration ≈ 0 automatically — read the key yourself only if you want to change what's shown, not just how it moves.",
                             panel: .code(CodePanel(file: "MotionStatus.swift", code: reducedMotionCode,
                                                    origin: .sample(path: "Examples/Counter/Sources/CounterApp.swift",
                                                                    marker: "anim-reduced-motion")))),
                    ],
                    panel: .code(CodePanel(file: "SaveButton.swift", code: completionCode,
                                           origin: .sample(path: "Examples/Counter/Sources/CounterApp.swift",
                                                           marker: "anim-completion")))),
        ])
}
