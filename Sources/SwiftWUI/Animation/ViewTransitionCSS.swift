/// CSS emitted for view transitions (view-transitions spec §5). Everything here
/// is built from validated idents and `CSSValueConvertible` values, which is
/// what lets it go through `StyleRegistry.registerRaw`'s
/// caller-guarantees-safety contract.
enum ViewTransitionCSS {
    /// Registered once at mount. Without this the transition overlay sits above
    /// all content and swallows every click for the transition's duration.
    /// Consequence, deliberate: clicks land on the new page while the old frame
    /// is still visible.
    static let baseRuleText = "::view-transition { pointer-events: none }"

    /// Per-element tuning for one named group. Timing goes on the group (only
    /// the two timing longhands — setting `animation-name` or the `animation`
    /// shorthand there deletes the UA's measured morph keyframes, spec §5.2);
    /// `object-fit` goes on old/new, for the same reason.
    /// Registered as raw document-level text rather than a class rule: the
    /// selectors target pseudo-elements of the document, not this element.
    static func groupRule(name: String, duration: CSSDuration?,
                          timingFunction: TimingFunction?,
                          contentFit: TransitionContentFit?) -> PendingStyleRule? {
        var text = ""
        if duration != nil || timingFunction != nil {
            var declarations: [StyleDeclaration] = []
            if let duration { declarations.append(.init(property: "animation-duration", value: duration.css)) }
            if let timingFunction {
                declarations.append(.init(property: "animation-timing-function", value: timingFunction.css))
            }
            text += "::view-transition-group(\(name)) { \(StyleRegistry.body(declarations)) }\n"
        }
        if let contentFit {
            text += "::view-transition-old(\(name)) { object-fit: \(contentFit.rawValue) }\n"
            text += "::view-transition-new(\(name)) { object-fit: \(contentFit.rawValue) }"
        }
        guard !text.isEmpty else { return nil }
        return PendingStyleRule(pseudo: nil, media: nil, rawText: text, declarations: [])
    }
}

extension PageTransition {
    /// `<html data-swui-vt="…">` value: preset name plus a hash over everything
    /// that changes the emitted CSS, so two configurations of one preset cannot
    /// collide and the value stays readable in devtools. Same convention as
    /// `Keyframes.cssName`.
    var cssAttributeValue: String {
        let seed: String
        switch kind {
        case .fade: seed = "fade"
        case .slide(let edge): seed = "slide|\(edge)"
        case .zoom(let source): seed = "zoom|\(source)"
        case .custom(let old, let new): seed = "custom|\(old.cssName)|\(new.cssName)"
        }
        let full = "\(seed)|\(durationValue.css)|\(timingValue.css)|\(reducedMotionRespected)"
        return presetSlug + "-" + String(StyleRegistry.fnv1a(full), radix: 36)
    }

    private var presetSlug: String {
        switch kind {
        case .fade: return "fade"
        case .slide: return "slide"
        case .zoom: return "zoom"
        case .custom: return "custom"
        }
    }

    /// Registers everything this transition needs. Idempotent: the registry
    /// dedupes by text hash, so calling it per navigation is free.
    func register(into registry: StyleRegistry) {
        let attr = cssAttributeValue
        let scope = "html[data-swui-vt=\"\(attr)\"]"
        let duration = durationValue.css
        let easing = timingValue.css

        // Named groups otherwise animate at the UA's 0.25s while the root uses
        // ours. `(*)` covers every group; old/new inherit timing from the group.
        registry.registerRaw("\(scope)::view-transition-group(*) { animation-duration: \(duration); animation-timing-function: \(easing) }")

        var body = ""
        switch kind {
        case .fade:
            // The UA cross-fade is already correct; only its timing needed
            // overriding, which the group rule above did.
            break
        case .slide(let edge):
            let (outKF, inKF, outRev, inRev) = ViewTransitionCSS.slideKeyframes(edge: edge)
            for kf in [outKF, inKF, outRev, inRev] { registry.registerRaw(kf.ruleText) }
            body += "\(scope)::view-transition-old(root) { animation: \(outKF.cssName) \(duration) \(easing) both; mix-blend-mode: plus-lighter }\n"
            body += "\(scope)::view-transition-new(root) { animation: \(inKF.cssName) \(duration) \(easing) both; mix-blend-mode: plus-lighter }\n"
            body += "\(scope)[data-swui-nav=\"pop\"]::view-transition-old(root) { animation-name: \(outRev.cssName) }\n"
            body += "\(scope)[data-swui-nav=\"pop\"]::view-transition-new(root) { animation-name: \(inRev.cssName) }"
        case .zoom(let sourceID):
            body = ViewTransitionCSS.zoomRules(scope: scope, name: sourceID,
                                               duration: duration, easing: easing)
        case .custom(let old, let new):
            registry.registerRaw(old.ruleText)
            registry.registerRaw(new.ruleText)
            body += "\(scope)::view-transition-old(root) { animation: \(old.cssName) \(duration) \(easing) both; mix-blend-mode: plus-lighter }\n"
            body += "\(scope)::view-transition-new(root) { animation: \(new.cssName) \(duration) \(easing) both; mix-blend-mode: plus-lighter }"
        }
        if !body.isEmpty {
            // CSS can only ENABLE under a condition, hence `no-preference`
            // rather than `reduce` — same shape as the keyframes feature. The
            // wrapper is emitted ONLY when reduced motion is respected: with the
            // opt-out the transition IS armed, and wrapping would leave it
            // playing the UA cross-fade instead of the requested animation.
            registry.registerRaw(reducedMotionRespected
                ? "@media (prefers-reduced-motion: no-preference) {\n\(body)\n}"
                : body)
        }
        // Kill switch for a setting that flips mid-transition: the
        // `no-preference` rules stop matching and the UA cross-fade would take
        // over, which is motion where an instant swap was promised. This is the
        // one sanctioned place that sets `animation` on a group.
        registry.registerRaw("@media (prefers-reduced-motion: reduce) { html[data-swui-vt]::view-transition-group(*) { animation: none } }")
    }
}

extension ViewTransitionCSS {
    /// out/in plus their mirrored variants for `pop`. Built as `Keyframes` values
    /// so they hash and dedupe like every other at-rule in the registry.
    static func slideKeyframes(edge: Edge) -> (Keyframes, Keyframes, Keyframes, Keyframes) {
        func offset(_ e: Edge, sign: Double) -> String {
            switch e {
            case .leading:  return "\(cssNumber(-30 * sign))% 0"
            case .trailing: return "\(cssNumber(30 * sign))% 0"
            case .top:      return "0 \(cssNumber(-30 * sign))%"
            case .bottom:   return "0 \(cssNumber(30 * sign))%"
            }
        }
        let out = Keyframes("swui-vt-slide-out") {
            $0.to { $0.style("translate", offset(edge, sign: -1)); $0.opacity(0) }
        }
        let into = Keyframes("swui-vt-slide-in") {
            $0.from { $0.style("translate", offset(edge, sign: 1)); $0.opacity(0) }
        }
        let outRev = Keyframes("swui-vt-slide-out-rev") {
            $0.to { $0.style("translate", offset(edge, sign: 1)); $0.opacity(0) }
        }
        let inRev = Keyframes("swui-vt-slide-in-rev") {
            $0.from { $0.style("translate", offset(edge, sign: -1)); $0.opacity(0) }
        }
        return (out, into, outRev, inRev)
    }

    /// Task 5 replaces the body with the real radius/clip interpolation. Until
    /// then a zoom animates like a fade with the group timing already set.
    static func zoomRules(scope: String, name: String,
                          duration: String, easing: String) -> String { "" }
}
