import SwiftWUI

// ===========================================================================
// Paper, Rail, Graphite — the tutorial site's design system.
// Spec: docs/superpowers/specs/2026-07-28-tutorial-visual-identity.md
//
// Three materials, never mixed: PAPER (the reading column), the RAIL (progress
// made physical), GRAPHITE (every code surface, theme-invariant).
// ===========================================================================

// MARK: - Tokens

public extension ColorToken {
    // Surfaces
    static let paper          = ColorToken("paper")
    static let paperSunken    = ColorToken("paper-sunken")
    static let card           = ColorToken("card")
    static let graphite       = ColorToken("graphite")
    static let graphiteBar    = ColorToken("graphite-bar")
    static let hairline       = ColorToken("hairline")
    static let hairlineStrong = ColorToken("hairline-strong")
    static let overlay        = ColorToken("overlay")
    static let glassBar       = ColorToken("glass-bar")
    static let hairlineOnDark = ColorToken("hairline-onDark")
    // Ink — three steps, no fourth. Quieter than --ink-3 means smaller or gone.
    static let ink            = ColorToken("ink")
    static let ink2           = ColorToken("ink-2")
    static let ink3           = ColorToken("ink-3")
    // Accent
    static let accent         = ColorToken("accent")
    static let accentHover    = ColorToken("accent-hover")
    static let accentActive   = ColorToken("accent-active")
    static let accentVivid    = ColorToken("accent-vivid")   // graphics only, never under text
    static let accentTint     = ColorToken("accent-tint")
    static let onAccent       = ColorToken("on-accent")
    // Status — never colour alone; always paired with a glyph and a text label.
    static let ok             = ColorToken("ok")
    static let okTint         = ColorToken("ok-tint")
    static let err            = ColorToken("err")
    static let errTint        = ColorToken("err-tint")
    static let focus          = ColorToken("focus")
    // Code — theme-invariant, always on --graphite. 5.82:1 … 13.99:1.
    static let codePlain      = ColorToken("code-plain")
    static let codeKw         = ColorToken("code-kw")
    static let codeType       = ColorToken("code-type")
    static let codeStr        = ColorToken("code-str")
    static let codeNum        = ColorToken("code-num")
    static let codeCmt        = ColorToken("code-cmt")
    static let codePunct      = ColorToken("code-punct")
    static let codeBar        = ColorToken("code-bar")
}

public extension LengthToken {
    // Spacing — 4px base. Layout rhythm comes from here and nowhere else.
    static let s1  = LengthToken("s-1")
    static let s2  = LengthToken("s-2")
    static let s3  = LengthToken("s-3")
    static let s4  = LengthToken("s-4")
    static let s5  = LengthToken("s-5")
    static let s6  = LengthToken("s-6")
    static let s7  = LengthToken("s-7")
    static let s8  = LengthToken("s-8")
    static let s9  = LengthToken("s-9")
    static let s10 = LengthToken("s-10")
    // Radius — scales with surface area, monotonically.
    static let r1    = LengthToken("r-1")
    static let r2    = LengthToken("r-2")
    static let r3    = LengthToken("r-3")
    static let r4    = LengthToken("r-4")
    static let r5    = LengthToken("r-5")
    static let rPill = LengthToken("r-pill")
    // Type — rem so a reader's browser font-size still governs.
    static let t1    = LengthToken("t-1")      // 13 — mono metadata
    static let tCode = LengthToken("t-code")   // 14 — code + terminal only
    static let t2    = LengthToken("t-2")      // 15 — UI
    static let t3    = LengthToken("t-3")      // 17 — prose body
    static let t4    = LengthToken("t-4")      // 19 — intro / hero body
    static let t5    = LengthToken("t-5")      // 22 — H3
    static let t6    = LengthToken("t-6")      // 28 — H2
    static let t7    = LengthToken("t-7")      // 36 — H2 at lg, CTA title
    // Page
    static let wPage = LengthToken("w-page")
}

/// A pre-serialized custom-property value. The framework has no
/// `StyleToken<Shadow>`, so elevations (and the two UA-chrome hints) are
/// themed through this rather than duplicating every shadowed rule under the
/// dark media query.
struct RawCSS: CSSValueConvertible {
    let css: String
}
typealias RawToken = StyleToken<RawCSS>

extension RawToken {
    static let elev1     = RawToken("elev-1")
    static let elev2     = RawToken("elev-2")
    static let elev3     = RawToken("elev-3")
    static let scheme    = RawToken("scheme")      // color-scheme: UA scrollbars + form chrome
    static let smoothing = RawToken("smoothing")   // -webkit-font-smoothing
}

// MARK: - Type stacks

public enum Fonts {
    public static let ui    = "\"Instrument Sans\", system-ui, -apple-system, sans-serif"
    public static let prose = "Literata, Charter, \"Iowan Old Style\", Georgia, serif"
    public static let mono  = "\"Commit Mono\", ui-monospace, \"SF Mono\", Menlo, monospace"
}

// MARK: - Palettes

public enum TutorialTheme {

    struct Palette {
        let colors: [(ColorToken, CSSColor)]
        let raws: [(RawToken, RawCSS)]
    }

    private static func shadow(_ layers: Shadow...) -> RawCSS {
        RawCSS(css: layers.map(\.boxShadowCSS).joined(separator: ", "))
    }

    static let light = Palette(
        colors: [
            (.paper, .hex("#FBFAF8")), (.paperSunken, .hex("#F2EFE9")), (.card, .hex("#FFFFFF")),
            (.graphite, .hex("#1A1714")), (.graphiteBar, .hex("#221E1ABF")),
            (.hairline, .hex("#E6E1D9")), (.hairlineStrong, .hex("#D5CEC3")),
            (.overlay, .hex("#FFFFFFF2")), (.glassBar, .hex("#FBFAF8D1")),
            (.hairlineOnDark, .hex("#FFFFFF14")),
            (.ink, .hex("#1A1714")), (.ink2, .hex("#57514A")), (.ink3, .hex("#6B6459")),
            (.accent, .hex("#AF3D12")), (.accentHover, .hex("#96330E")),
            (.accentActive, .hex("#7F2B0B")), (.accentVivid, .hex("#E2551F")),
            (.accentTint, .hex("#FBEDE5")), (.onAccent, .hex("#FFFFFF")),
            (.ok, .hex("#15703A")), (.okTint, .hex("#E7F3E9")),
            (.err, .hex("#B3261E")), (.errTint, .hex("#FBEAE8")), (.focus, .hex("#2F6FEB")),
            (.codePlain, .hex("#E9E3DA")), (.codeKw, .hex("#FF9068")),
            (.codeType, .hex("#E8C07D")), (.codeStr, .hex("#A9C98D")),
            (.codeNum, .hex("#C3A9F0")), (.codeCmt, .hex("#9A9289")),
            (.codePunct, .hex("#B9B2A7")), (.codeBar, .hex("#CFC7BB")),
        ],
        raws: [
            (.elev1, shadow(Shadow(offsetX: .zero, offsetY: .px(1), blur: .px(2), spread: .px(-1),
                                   color: .rgba(26, 23, 20, 0.06)))),
            (.elev2, shadow(Shadow(offsetX: .zero, offsetY: .px(2), blur: .px(4), spread: .px(-2),
                                   color: .rgba(26, 23, 20, 0.08)),
                            Shadow(offsetX: .zero, offsetY: .px(12), blur: .px(28), spread: .px(-10),
                                   color: .rgba(26, 23, 20, 0.14)))),
            (.elev3, shadow(Shadow(offsetX: .zero, offsetY: .px(8), blur: .px(16), spread: .px(-6),
                                   color: .rgba(26, 23, 20, 0.12)),
                            Shadow(offsetX: .zero, offsetY: .px(28), blur: .px(56), spread: .px(-16),
                                   color: .rgba(26, 23, 20, 0.24)))),
            (.scheme, RawCSS(css: "light")),
            (.smoothing, RawCSS(css: "auto")),
        ])

    static let dark = Palette(
        colors: [
            (.paper, .hex("#141210")), (.paperSunken, .hex("#100E0C")), (.card, .hex("#1C1917")),
            // graphite + its bar are THEME-INVARIANT: the code surface never
            // changes, so the syntax palette never has to be re-measured.
            (.graphite, .hex("#1A1714")), (.graphiteBar, .hex("#221E1ABF")),
            (.hairline, .hex("#272220")), (.hairlineStrong, .hex("#35302C")),
            (.overlay, .hex("#1C1917F2")), (.glassBar, .hex("#141210D1")),
            (.hairlineOnDark, .hex("#FFFFFF1A")),
            (.ink, .hex("#ECE7E0")), (.ink2, .hex("#B4ADA3")), (.ink3, .hex("#9C958A")),
            (.accent, .hex("#FF7A45")), (.accentHover, .hex("#FF8E60")),
            (.accentActive, .hex("#FF6A2E")), (.accentVivid, .hex("#FF9A6B")),
            (.accentTint, .hex("#2A1710")), (.onAccent, .hex("#241009")),
            (.ok, .hex("#5FD08A")), (.okTint, .hex("#12241A")),
            (.err, .hex("#FF8A80")), (.errTint, .hex("#2A1512")), (.focus, .hex("#7FA8FF")),
            (.codePlain, .hex("#E9E3DA")), (.codeKw, .hex("#FF9068")),
            (.codeType, .hex("#E8C07D")), (.codeStr, .hex("#A9C98D")),
            (.codeNum, .hex("#C3A9F0")), (.codeCmt, .hex("#9A9289")),
            (.codePunct, .hex("#B9B2A7")), (.codeBar, .hex("#CFC7BB")),
        ],
        raws: [
            (.elev1, shadow(Shadow(offsetX: .zero, offsetY: .px(1), color: .rgba(255, 255, 255, 0.04), inset: true),
                            Shadow(offsetX: .zero, offsetY: .px(1), blur: .px(2), color: .rgba(0, 0, 0, 0.5)))),
            (.elev2, shadow(Shadow(offsetX: .zero, offsetY: .px(1), color: .rgba(255, 255, 255, 0.05), inset: true),
                            Shadow(offsetX: .zero, offsetY: .px(12), blur: .px(28), spread: .px(-10),
                                   color: .rgba(0, 0, 0, 0.6)))),
            (.elev3, shadow(Shadow(offsetX: .zero, offsetY: .px(1), color: .rgba(255, 255, 255, 0.06), inset: true),
                            Shadow(offsetX: .zero, offsetY: .px(28), blur: .px(56), spread: .px(-16),
                                   color: .rgba(0, 0, 0, 0.7)))),
            (.scheme, RawCSS(css: "dark")),
            (.smoothing, RawCSS(css: "antialiased")),
        ])

    /// Scale tokens are theme-invariant — declared once, in the default theme.
    private static func scales(_ t: inout ThemeAssignments) {
        t.set(LengthToken.s1, .px(4));   t.set(LengthToken.s2, .px(8))
        t.set(LengthToken.s3, .px(12));  t.set(LengthToken.s4, .px(16))
        t.set(LengthToken.s5, .px(24));  t.set(LengthToken.s6, .px(32))
        t.set(LengthToken.s7, .px(48));  t.set(LengthToken.s8, .px(64))
        t.set(LengthToken.s9, .px(96));  t.set(LengthToken.s10, .px(128))

        t.set(LengthToken.r1, .px(6));   t.set(LengthToken.r2, .px(10))
        t.set(LengthToken.r3, .px(14));  t.set(LengthToken.r4, .px(20))
        t.set(LengthToken.r5, .px(28));  t.set(LengthToken.rPill, .px(999))

        t.set(LengthToken.t1, .rem(0.8125));  t.set(LengthToken.tCode, .rem(0.875))
        t.set(LengthToken.t2, .rem(0.9375));  t.set(LengthToken.t3, .rem(1.0625))
        t.set(LengthToken.t4, .rem(1.1875));  t.set(LengthToken.t5, .rem(1.375))
        t.set(LengthToken.t6, .rem(1.75));    t.set(LengthToken.t7, .rem(2.25))

        t.set(LengthToken.wPage, .px(1280))
    }

    static func emit(_ p: Palette, into t: inout ThemeAssignments) {
        for (token, value) in p.colors { t.set(token, value) }
        for (token, value) in p.raws { t.set(token, value) }
    }

    static func emit(_ p: Palette, into s: inout StyleProxy) {
        for (token, value) in p.colors { s.style("--" + token.name, value.css) }
        for (token, value) in p.raws { s.style("--" + token.name, value.css) }
    }

    /// Default theme → `:root { … }`. Light values plus the invariant scales.
    public static let definition = ThemeDefinition { t in
        emit(light, into: &t)
        scales(&t)
    }
    /// Manual override → `[data-theme="light"] { … }` on the mount container,
    /// which is a descendant of `body`, so it beats the dark media rule below
    /// by inheritance depth. Scales are not repeated — they never change.
    public static let lightTheme = ThemeDefinition(name: "light") { t in emit(light, into: &t) }
    public static let darkTheme  = ThemeDefinition(name: "dark")  { t in emit(dark, into: &t) }

    public static var fontFaces: [FontFace] {
        [FontFace(family: "Instrument Sans", src: "/assets/fonts/InstrumentSans-Variable.woff2",
                  format: .woff2, weight: 400...700, style: .normal, display: .swap),
         FontFace(family: "Literata", src: "/assets/fonts/Literata-Variable.woff2",
                  format: .woff2, weight: 300...700, style: .normal, display: .swap),
         FontFace(family: "Commit Mono", src: "/assets/fonts/CommitMono-Variable.woff2",
                  format: .woff2, weight: 300...700, style: .normal, display: .swap)]
    }
}

// MARK: - Motion vocabulary

public enum TutorialMotion {
    /// Everything entering or settling — the decelerate curve.
    public static let ease = TimingFunction.cubicBezier(0.2, 0, 0, 1)

    /// Quiz row, correct answer.
    public static let pop = Keyframes("pop") { k in
        k.from { $0.transform(.scale(x: 1, y: 1)) }
        k.at(55) { $0.transform(.scale(x: 1.035, y: 1.035)) }
        k.to { $0.transform(.scale(x: 1, y: 1)) }
    }
    /// Quiz row, wrong answer.
    public static let nudge = Keyframes("nudge") { k in
        k.from { $0.transform(.translateX(.zero)) }
        k.at(25) { $0.transform(.translateX(.px(-3))) }
        k.at(75) { $0.transform(.translateX(.px(3))) }
        k.to { $0.transform(.translateX(.zero)) }
    }
}

// MARK: - Rules

public enum TutorialStyles {

    /// One string, three call sites (spec risk 8). The typed
    /// `.transition(property:…)` overload writes the whole `transition`
    /// property, so two typed calls on one element overwrite each other —
    /// multi-property surfaces have to take the shorthand.
    private static let interactive =
        "background-color 160ms cubic-bezier(.2,0,0,1), border-color 160ms cubic-bezier(.2,0,0,1), "
        + "transform 160ms cubic-bezier(.2,0,0,1), box-shadow 160ms cubic-bezier(.2,0,0,1)"

    /// One query, ten rules (spec risk 9). `MediaQuery` has no
    /// `.prefersReducedMotion` constructor — worth a framework ticket.
    private static let reduceMotion = MediaQuery.custom("(prefers-reduced-motion: reduce)")

    /// The focus ring, identical on every interactive surface. `--focus` flips
    /// with the theme, so the same ring reads on paper and on graphite.
    private static func ring(_ p: inout StyleProxy, offset: CSSLength = .px(3)) {
        p.focusVisible { f in
            f.outlineWidth(.px(2)); f.outlineStyle(.solid)
            f.outlineColor(.token(.focus)); f.outlineOffset(offset)
        }
    }

    /// Rail geometry. The only lengths in the system off the spacing scale that
    /// are not component-internal optics: the gutter, the badge and the spine
    /// are one interlocking measurement (rail centre x = 12 = badge left edge
    /// 0 relative to `.tut-steps`, i.e. −44 relative to the row).
    private static let railGutter = CSSLength.px(44)
    private static let railInset  = CSSLength.px(11)
    private static let railWidth  = CSSLength.px(2)
    private static let badgeSize  = CSSLength.px(24)

    @RulesBuilder public static var rules: [Rule] {

        // — document —
        Rule(element: "html") { p in
            p.scrollBehavior(.smooth)
        }
        Rule(element: "html", media: reduceMotion) { p in
            p.scrollBehavior(.auto)
        }
        Rule(element: "body") { p in
            p.margin(.zero)
            p.background(.token(.paper))          // propagates to the canvas — never paint `html`
            p.color(.token(.ink))
            p.fontFamily(Fonts.ui)
            p.fontSize(.token(.t3))
            p.style("color-scheme", "var(--scheme)")
            p.style("-webkit-font-smoothing", "var(--smoothing)")
        }
        // THE DARK PALETTE. It is declared on `body`, not on `html`, and that is
        // load-bearing: `ThemeDefinition` can only emit `:root`, whose (0,1,0)
        // specificity beats `html`'s (0,0,1), and a media query adds no
        // specificity — an `html` override would be dead CSS. Custom properties
        // inherit, and every rendered element is inside `body`, so declaring the
        // dark set one level deeper wins by inheritance depth: order-independent,
        // specificity-independent, correct on the prerendered first paint.
        // COROLLARY: never paint a token on `html` or on any surface outside
        // `body` — it would silently read light values in dark mode.
        Rule(element: "body", media: .prefersColorScheme(.dark)) { p in
            TutorialTheme.emit(TutorialTheme.dark, into: &p)
        }
        Rule(element: "a") { p in
            p.color(.current)
            p.textDecoration(.none)
        }

        // — shell + container —
        Rule(class: "tut-shell") { p in
            p.minHeight(.dvh(100))
            p.background(.token(.paper))
            // Repeated from `body` so a MANUAL `[data-theme]` choice (which
            // lands on the mount container, inside body) also flips UA chrome.
            p.style("color-scheme", "var(--scheme)")
            p.style("-webkit-font-smoothing", "var(--smoothing)")
        }
        Rule(class: "tut-content") { p in
            p.boxSizing(.borderBox)
            p.maxWidth(.token(.wPage))
            p.marginInline(.auto)
            p.paddingInline(.token(.s5))
        }
        Rule(class: "tut-content", media: .down(.sm)) { p in p.paddingInline(.token(.s4)) }
        Rule(class: "tut-content", media: .up(.md)) { p in p.paddingInline(.token(.s6)) }
        Rule(class: "tut-content", media: .up(.lg)) { p in p.paddingInline(.token(.s7)) }

        // — kicker: the site's chrome, typeset as a Swift line comment —
        Rule(class: "tut-kicker-row") { p in
            p.display(.flex); p.alignItems(.center); p.gap(.token(.s3))
        }
        Rule(class: "tut-kicker") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.token(.t1)); p.fontWeight(.custom(500))
            p.lineHeight(1.3); p.letterSpacing(.em(0.01))
            p.textTransform(.lowercase)          // the mono-UPPERCASE cliché is out of the system
            p.fontVariantNumeric(.tabularNums)
            p.color(.token(.ink3))
            p.whiteSpace(.nowrap)
        }
        Rule(class: "tut-kicker-slash") { p in p.color(.token(.accent)) }
        // `::after` is unreachable, so the rule is a real element — which the
        // flex measurement needs anyway.
        Rule(class: "tut-kicker-rule") { p in
            p.flexGrow(1); p.height(.px(1)); p.background(.token(.hairline))
        }

        // — site nav —
        Rule(class: "tut-nav") { p in
            p.background(.token(.paper))
            p.border(.bottom, width: .px(1), style: .solid, color: .token(.hairline))
        }
        Rule(class: "tut-nav-inner") { p in
            p.display(.flex); p.flexWrap(.wrap); p.alignItems(.center)
            p.minHeight(.px(56)); p.columnGap(.token(.s3))
        }
        Rule(class: "tut-nav-inner", media: .up(.md)) { p in
            p.flexWrap(.nowrap); p.minHeight(.px(64))
        }
        Rule(class: "tut-brand") { p in
            p.display(.flex); p.alignItems(.baseline); p.gap(.px(2))
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t3)); p.fontWeight(.custom(600))
            p.color(.token(.ink))
            ring(&p)
        }
        Rule(class: "tut-brand-path") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.token(.t2)); p.color(.token(.ink3))
            p.transition(property: "color", duration: .ms(160), timingFunction: TutorialMotion.ease)
            p.hover { $0.color(.token(.accent)) }
        }
        // Row 2 on phones: a horizontally scrollable link row. Four links always
        // reachable, zero state, correct at first paint with no JS.
        Rule(class: "tut-nav-links") { p in
            p.order(2); p.width(.percent(100))
            p.display(.flex); p.flexWrap(.nowrap); p.gap(.px(20))
            p.overflowX(.auto); p.overscrollBehaviorX(.contain)
            p.paddingBlock(.px(10))
            p.border(.top, width: .px(1), style: .solid, color: .token(.hairline))
        }
        Rule(class: "tut-nav-links", media: .up(.md)) { p in
            p.order(0); p.width(.auto); p.marginInlineStart(.auto)
            p.overflowX(.visible); p.gap(.px(28))
            p.paddingBlock(.zero)
            p.border(.top, width: .zero, style: .none, color: .transparent)
        }
        Rule(class: "tut-nav-link") { p in
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t2)); p.fontWeight(.custom(500))
            p.color(.token(.ink2)); p.whiteSpace(.nowrap)
            p.transition(interactive)
            p.hover { h in
                h.color(.token(.ink))
                h.textDecorationLine(.underline)
                h.textUnderlineOffset(.px(4))
                h.textDecorationThickness(.px(1))
                h.textDecorationColor(.token(.accent))
            }
            p.active { $0.transform(.translateY(.px(1))) }
            ring(&p)
        }
        Rule(class: "tut-theme-toggle") { p in
            p.display(.inlineFlex); p.alignItems(.center); p.justifyContent(.center)
            p.marginInlineStart(.auto)
            p.width(.px(74)); p.height(.px(36))
            p.borderRadius(.token(.r2))
            p.border(.px(1), .solid, .token(.hairlineStrong))
            p.background(.transparent)
            p.fontFamily(Fonts.mono); p.fontSize(.px(12)); p.textTransform(.lowercase)
            p.fontVariantNumeric(.tabularNums); p.color(.token(.ink2))
            p.cursor(.pointer)
            p.transition(interactive)
            p.hover { $0.background(.token(.paperSunken)) }
            p.active { $0.transform(.translateY(.px(1))) }
            ring(&p)
        }

        // — chapter bar: the only sticky chrome. No shadow at any scroll
        //   position; it separates by translucency and one hairline. —
        Rule(class: "tut-chapterbar") { p in
            p.position(.sticky); p.top(.zero); p.zIndex(40)
            p.background(.token(.glassBar))
            p.backdropFilter(.blur(.px(20)), .saturate(1.8))
            p.border(.bottom, width: .px(1), style: .solid, color: .token(.hairline))
        }
        Rule(class: "tut-chapterbar-inner") { p in
            p.display(.flex); p.alignItems(.center); p.gap(.token(.s3)); p.height(.px(52))
        }
        Rule(class: "tut-chapterbar-inner", media: .up(.md)) { p in p.height(.px(56)) }
        Rule(class: "tut-series") { p in
            p.display(.none)                     // the nav brand already says it
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t2)); p.fontWeight(.custom(600))
            p.color(.token(.ink))
        }
        Rule(class: "tut-series", media: .up(.md)) { p in p.display(.flex); p.gap(.px(2)) }
        Rule(class: "tut-series-accent") { p in p.color(.token(.accent)) }
        Rule(class: "tut-divider") { p in
            p.width(.px(1)); p.height(.px(20)); p.background(.token(.hairlineStrong))
            p.flexShrink(0)
        }
        Rule(class: "tut-spacer") { p in p.flexGrow(1) }

        // chapter progress meter — `04 / 19` plus a 64×2 track
        Rule(class: "tut-progress") { p in
            p.display(.flex); p.alignItems(.center); p.gap(.token(.s2))
        }
        Rule(class: "tut-progress-label") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.token(.t1)); p.lineHeight(1.3)
            p.fontVariantNumeric(.tabularNums); p.color(.token(.ink3)); p.whiteSpace(.nowrap)
        }
        Rule(class: "tut-progress-track") { p in
            p.width(.px(64)); p.height(railWidth)
            p.background(.token(.hairlineStrong))
            p.borderRadius(.token(.rPill)); p.overflow(.hidden); p.flexShrink(0)
        }
        Rule(class: "tut-progress-fill") { p in
            p.height(railWidth); p.background(.token(.accentVivid))
            p.borderRadius(.token(.rPill))
            p.transition(property: "width", duration: .ms(320), timingFunction: TutorialMotion.ease)
        }

        // dropdown + pill share metrics; the skin classes are mutually exclusive
        Rule(class: "tut-dropdown-wrap") { p in p.position(.relative) }
        Rule(class: "tut-dropdown") { p in
            p.display(.inlineFlex); p.alignItems(.center); p.gap(.token(.s2))
            p.height(.px(34)); p.paddingInline(.token(.s3))
            p.borderRadius(.token(.r2))
            p.borderWidth(.px(1)); p.borderStyle(.solid)
            p.background(.transparent)
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t2)); p.fontWeight(.custom(500))
            p.color(.token(.ink)); p.cursor(.pointer); p.whiteSpace(.nowrap)
            p.transition(interactive)
            p.active { $0.transform(.translateY(.px(1))) }
            ring(&p)
        }
        Rule(class: "tut-dropdown-rest") { p in
            p.borderColor(.token(.hairlineStrong))
            p.hover { $0.background(.token(.paperSunken)) }
        }
        Rule(class: "tut-dropdown-open") { p in
            p.background(.token(.paperSunken)); p.borderColor(.token(.ink3))
        }
        // Mono, deliberately: the subset ships whatever glyph the site renders,
        // and Commit Mono is the only one of the three faces that carries the
        // geometric shapes (▼ ✓ ✕). Setting the family here keeps a missing
        // glyph from silently falling back to a system font at a different size.
        Rule(class: "tut-chevron") { p in
            p.display(.inlineBlock); p.fontFamily(Fonts.mono)
            p.fontSize(.px(8)); p.lineHeight(1)
            p.color(.token(.ink3))
            p.transition(property: "rotate", duration: .ms(160), timingFunction: TutorialMotion.ease)
        }
        Rule(class: "tut-pill") { p in
            p.display(.none)
            p.alignItems(.center); p.height(.px(34)); p.paddingInline(.token(.s3))
            p.borderRadius(.token(.rPill))
            p.border(.px(1), .solid, .token(.hairlineStrong))
            p.background(.transparent)
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t2)); p.fontWeight(.custom(500))
            p.color(.token(.ink2)); p.cursor(.pointer); p.whiteSpace(.nowrap)
            p.transition(interactive)
            p.hover { $0.background(.token(.paperSunken)) }
            p.active { $0.transform(.translateY(.px(1))) }
            ring(&p)
        }
        Rule(class: "tut-pill", media: .up(.md)) { p in p.display(.inlineFlex) }

        // — chapter menu: the only floating overlay in the site —
        Rule(class: "tut-menu") { p in
            // `.tut-menu-open` is the same specificity as `.tut-menu`, and
            // StyleRegistry breaks same-media ties by hash — an override pair
            // would be a coin flip. Reading a custom property the open class
            // sets makes the outcome order-independent.
            p.style("display", "var(--menu-display, none)")
            p.boxSizing(.borderBox)
            p.position(.static); p.width(.percent(100))
            p.maxHeight(.vh(60)); p.overflowY(.auto); p.overscrollBehavior(.contain)
            p.background(.token(.overlay))
            p.backdropFilter(.blur(.px(24)), .saturate(1.6))
            p.border(.top, width: .px(1), style: .solid, color: .token(.hairline))
            p.zIndex(50)
            p.padding(vertical: .token(.s4), horizontal: .token(.s3))
        }
        Rule(class: "tut-menu", media: .up(.md)) { p in
            p.position(.absolute); p.top(.px(46)); p.left(.zero)
            p.width(.px(340)); p.maxHeight(.vh(70))
            p.borderRadius(.token(.r4))
            p.border(.px(1), .solid, .token(.hairline))
            p.boxShadow("var(--elev-3)")
        }
        Rule(class: "tut-menu-open") { p in p.style("--menu-display", "block") }
        Rule(class: "tut-menu-group") { p in p.margin(.bottom, .token(.s4)) }
        Rule(class: "tut-menu-label") { p in p.margin(.bottom, .token(.s2)) }
        Rule(class: "tut-menu-item") { p in
            p.display(.flex); p.alignItems(.center); p.gap(.px(10))
            p.minHeight(.px(40)); p.padding(vertical: .token(.s2), horizontal: .token(.s3))
            p.borderRadius(.token(.r2))
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t2))
            p.transition(interactive)
            ring(&p, offset: .px(-2))            // inset, so it never clips the sheet edge
        }
        Rule(class: "tut-menu-item-rest") { p in
            p.color(.token(.ink2)); p.fontWeight(.custom(500))
            p.hover { h in h.background(.token(.paperSunken)); h.color(.token(.ink)) }
        }
        Rule(class: "tut-menu-item-active") { p in
            p.background(.token(.accentTint)); p.color(.token(.ink)); p.fontWeight(.custom(600))
        }
        Rule(class: "tut-menu-dot") { p in
            p.width(.px(6)); p.height(.px(6)); p.borderRadius(.token(.rPill))
            p.background(.token(.accentVivid)); p.flexShrink(0)
        }

        // — hero: on PAPER, never a dark band —
        Rule(class: "tut-hero") { p in p.paddingBlock(.px(56)) }
        Rule(class: "tut-hero", media: .up(.lg)) { p in p.paddingBlock(.px(88)) }
        Rule(class: "tut-hero-simple") { p in p.paddingBlock(.token(.s7)) }
        Rule(class: "tut-hero-simple", media: .up(.lg)) { p in p.paddingBlock(.px(72)) }
        Rule(class: "tut-hero-grid") { p in
            p.display(.grid); p.gridTemplateColumns("minmax(0, 1fr)"); p.gap(.token(.s6))
        }
        Rule(class: "tut-hero-grid", media: .up(.lg)) { p in
            p.gridTemplateColumns("minmax(0, 1fr) 480px"); p.gap(.px(56)); p.alignItems(.center)
        }
        Rule(class: "tut-hero-grid", media: .up(.xl)) { p in
            p.gridTemplateColumns("minmax(0, 1fr) 560px"); p.gap(.px(72))
        }
        Rule(class: "tut-hero-text") { p in p.minWidth(.zero) }
        // In the hero the panel comes SECOND — the title has to land first.
        Rule(class: "tut-hero-panel") { p in p.minWidth(.zero) }
        // Display steps are discrete: `clamp()` has no typed representation and
        // the system refuses a raw `font-size: clamp(…)`.
        Rule(class: "tut-hero-title") { p in
            p.margin(.zero)
            p.fontFamily(Fonts.ui); p.fontSize(.rem(2.125)); p.fontWeight(.custom(700))
            p.lineHeight(1.05); p.letterSpacing(.em(-0.02))
            p.textWrap(.balance); p.maxWidth(.ch(20)); p.color(.token(.ink))
        }
        Rule(class: "tut-hero-title", media: .up(.md)) { p in p.fontSize(.rem(2.75)) }
        Rule(class: "tut-hero-title", media: .up(.lg)) { p in p.fontSize(.rem(3.5)); p.lineHeight(1.06) }
        Rule(class: "tut-hero-title", media: .up(.xl)) { p in p.fontSize(.rem(3.75)) }
        Rule(class: "tut-hero-title-simple") { p in
            p.margin(.zero)
            p.fontFamily(Fonts.ui); p.fontSize(.rem(1.875)); p.fontWeight(.custom(700))
            p.lineHeight(1.06); p.letterSpacing(.em(-0.02))
            p.textWrap(.balance); p.maxWidth(.ch(20)); p.color(.token(.ink))
        }
        Rule(class: "tut-hero-title-simple", media: .up(.md)) { p in p.fontSize(.rem(2.5)) }
        Rule(class: "tut-hero-title-simple", media: .up(.lg)) { p in p.fontSize(.rem(3)) }
        Rule(class: "tut-hero-tagline") { p in
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t4)); p.lineHeight(1.5)
            p.color(.token(.ink2)); p.maxWidth(.ch(46))
        }
        Rule(class: "tut-hero-body") { p in
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t3)); p.lineHeight(1.65)
            p.color(.token(.ink2)); p.maxWidth(.ch(62))
        }
        Rule(class: "tut-hero-actions") { p in
            p.display(.flex); p.flexWrap(.wrap); p.gap(.token(.s3)); p.margin(.top, .token(.s5))
        }

        // — buttons. Two styles, no third, no disabled state. —
        Rule(class: "tut-btn") { p in
            p.boxSizing(.borderBox)
            p.display(.inlineFlex); p.alignItems(.center); p.justifyContent(.center)
            p.gap(.token(.s2))
            p.minHeight(.px(44)); p.paddingInline(.px(18))
            p.borderRadius(.token(.r2))
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t2)); p.fontWeight(.custom(600))
            p.lineHeight(1); p.cursor(.pointer); p.whiteSpace(.nowrap)
            p.transition(interactive)
            p.active { $0.transform(.translateY(.px(1))) }
            ring(&p)
        }
        Rule(class: "tut-btn-primary") { p in
            p.background(.token(.accent)); p.color(.token(.onAccent))
            p.borderStyle(.none)
            p.hover { $0.background(.token(.accentHover)) }
            p.active { $0.background(.token(.accentActive)) }
        }
        Rule(class: "tut-btn-ghost") { p in
            p.background(.transparent); p.color(.token(.ink))
            p.border(.px(1), .solid, .token(.hairlineStrong))
            p.hover { h in h.background(.token(.paperSunken)); h.borderColor(.token(.ink3)) }
        }
        Rule(class: "tut-btn-arrow") { p in
            p.display(.inlineBlock); p.lineHeight(1)
            p.transition(property: "transform", duration: .ms(120), timingFunction: TutorialMotion.ease)
            p.hover { $0.transform(.translateX(.px(3))) }
        }

        // — sections —
        Rule(class: "tut-section") { p in
            p.paddingBlock(.px(72)); p.scrollMargin(.top, .px(76))
        }
        Rule(class: "tut-section", media: .up(.md)) { p in p.scrollMargin(.top, .px(84)) }
        Rule(class: "tut-section", media: .up(.lg)) { p in p.paddingBlock(.token(.s9)) }
        Rule(class: "tut-section-divided") { p in
            p.border(.top, width: .px(1), style: .solid, color: .token(.hairline))
        }
        Rule(class: "tut-section-header") { p in p.margin(.bottom, .token(.s6)) }
        Rule(class: "tut-section-title") { p in
            p.margin(.zero); p.margin(.top, .token(.s3))
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t6)); p.fontWeight(.custom(700))
            p.lineHeight(1.15); p.letterSpacing(.em(-0.015))
            p.textWrap(.balance); p.maxWidth(.ch(30)); p.color(.token(.ink))
        }
        Rule(class: "tut-section-title", media: .up(.lg)) { p in p.fontSize(.token(.t7)) }
        Rule(class: "tut-section-intro") { p in
            p.margin(.zero); p.margin(.top, .token(.s3))
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t4)); p.lineHeight(1.6)
            p.color(.token(.ink2)); p.maxWidth(.ch(62))
        }
        // `minmax(0, 1fr)` is mandatory: a bare `1fr` track has min-width auto
        // and long code lines blow the layout out.
        Rule(class: "tut-section-body") { p in
            p.display(.grid); p.gridTemplateColumns("minmax(0, 1fr)"); p.gap(.token(.s6))
        }
        Rule(class: "tut-section-body", media: .up(.lg)) { p in
            p.gridTemplateColumns("minmax(0, 1fr) 460px"); p.gap(.token(.s7)); p.alignItems(.flexStart)
        }
        Rule(class: "tut-section-body", media: .up(.xl)) { p in
            p.gridTemplateColumns("minmax(0, 1fr) 560px"); p.gap(.token(.s8))
        }
        // The panel comes FIRST on narrow screens: see the code, then read the
        // numbered steps that explain it. Mobile reading order, not a fallback.
        Rule(class: "tut-panel") { p in
            p.order(-1); p.position(.static); p.minWidth(.zero)
        }
        Rule(class: "tut-panel", media: .up(.lg)) { p in
            p.order(0); p.position(.sticky); p.top(.px(76))
        }

        // — step list + rail (the signature) —
        Rule(class: "tut-steps") { p in
            p.position(.relative); p.padding(.left, railGutter)
        }
        Rule(class: "tut-rail") { p in
            p.position(.absolute); p.left(railInset); p.top(.token(.s3)); p.bottom(.token(.s3))
            p.width(railWidth); p.borderRadius(.token(.rPill))
            p.background(.token(.hairlineStrong))
        }
        Rule(class: "tut-rail-fill") { p in
            p.position(.absolute); p.left(.zero); p.top(.zero)
            p.width(railWidth); p.borderRadius(.token(.rPill))
            p.background(.token(.accentVivid))
            p.transition(property: "height", duration: .ms(320), timingFunction: TutorialMotion.ease)
        }
        // No border-top: the rail replaces the separators entirely.
        Rule(class: "tut-step") { p in
            p.position(.relative)
            p.padding(.top, .px(14)); p.padding(.bottom, .px(18)); p.paddingInline(.token(.s3))
            p.borderRadius(.token(.r2))
            p.transition(property: "background-color", duration: .ms(220), timingFunction: TutorialMotion.ease)
        }
        Rule(class: "tut-step-active") { p in p.background(.token(.accentTint)) }
        Rule(class: "tut-step-badge") { p in
            p.boxSizing(.borderBox)
            p.position(.absolute); p.left(.px(-44)); p.top(.px(16))
            p.width(badgeSize); p.height(badgeSize)
            p.borderRadius(.token(.rPill))
            p.display(.flex); p.alignItems(.center); p.justifyContent(.center)
            p.borderWidth(.px(1.5)); p.borderStyle(.solid)
            // 12px: the one documented exception below --t-1. Tabular mono
            // inside a 24px badge, decorative-redundant (the title carries the
            // meaning), measured 5.60:1.
            p.fontFamily(Fonts.mono); p.fontSize(.px(12)); p.fontWeight(.custom(500))
            p.lineHeight(1); p.fontVariantNumeric(.tabularNums)
            p.transition(property: "background-color", duration: .ms(220), timingFunction: TutorialMotion.ease)
        }
        Rule(class: "tut-step-badge-rest") { p in
            p.background(.token(.paper)); p.borderColor(.token(.hairlineStrong)); p.color(.token(.ink3))
        }
        Rule(class: "tut-step-badge-active") { p in
            p.background(.token(.accentVivid)); p.borderColor(.token(.accentVivid))
            p.color(.token(.onAccent))
        }
        Rule(class: "tut-step-title") { p in
            p.margin(.zero)
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t3)); p.lineHeight(1.5); p.maxWidth(.ch(62))
        }
        Rule(class: "tut-step-title-rest") { p in
            p.color(.token(.ink2)); p.fontWeight(.custom(400))
        }
        Rule(class: "tut-step-title-active") { p in
            p.color(.token(.ink)); p.fontWeight(.custom(600))
        }
        // ALWAYS rendered, never hidden: hiding it would shift layout on every
        // scroll-spy tick and lose the text for no-JS readers.
        Rule(class: "tut-step-detail") { p in
            p.margin(.zero); p.margin(.top, .token(.s1))
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t2)); p.lineHeight(1.6)
            p.color(.token(.ink3)); p.maxWidth(.ch(62))
        }

        // — panel: graphite, in BOTH themes. Light = recessed window cut into
        //   the paper; dark = card lifted off the ground. Same material,
        //   opposite depth cue, no colour retuning. —
        Rule(class: "tut-card-dark") { p in
            p.background(.token(.graphite))
            p.border(.px(1), .solid, .token(.hairlineOnDark))
            p.borderRadius(.token(.r4)); p.overflow(.hidden)
            p.boxShadow("var(--elev-2)")
            p.isolation(.isolate)                // the glass bar composites against the panel
            // Set here rather than on the Tag so the compact code variant below
            // cannot be broken by a component forgetting `.containerType`.
            p.style("container-type", "inline-size")
        }
        // The code scrolls under real frosted glass while the filename stays put.
        Rule(class: "tut-panel-bar") { p in
            p.position(.sticky); p.top(.zero); p.zIndex(1)
            p.display(.flex); p.alignItems(.center); p.gap(.px(10))
            p.height(.px(40)); p.paddingInline(.px(14))
            p.background(.token(.graphiteBar))
            p.backdropFilter(.blur(.px(14)), .saturate(1.6))
            p.border(.bottom, width: .px(1), style: .solid, color: .token(.hairlineOnDark))
        }
        Rule(class: "tut-lang-chip") { p in
            p.display(.inlineFlex); p.alignItems(.center)
            p.padding(vertical: .px(2), horizontal: .px(6))
            p.borderRadius(.token(.r1))
            p.background(.token(.accentVivid)); p.color(.token(.onAccent))
            p.fontFamily(Fonts.mono); p.fontSize(.px(10)); p.fontWeight(.custom(500))
            p.lineHeight(1.4); p.textTransform(.uppercase); p.letterSpacing(.em(0.04))
            p.flexShrink(0)
        }
        Rule(class: "tut-panel-file") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.token(.t1)); p.lineHeight(1.3)
            p.color(.token(.codeBar)); p.overflow(.hidden); p.textOverflow(.ellipsis)
            p.whiteSpace(.nowrap)
        }
        Rule(class: "tut-code") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.token(.tCode)); p.lineHeight(.px(22))
            p.color(.token(.codePlain))
            p.padding(.top, .px(14)); p.padding(.bottom, .px(20)); p.paddingInline(.px(18))
            p.overflowX(.auto); p.overscrollBehaviorX(.contain)
            // The only font-feature escape hatch in the system, in exactly one
            // rule: slashed zero on, ligatures off — code must not fuse `!=`
            // into a glyph a learner cannot type. Inherits to every token span.
            p.style("font-feature-settings", "\"zero\" 1, \"liga\" 0")
        }
        // What makes one panel legible in the 460px column, the 560px xl column
        // and full-bleed on a 320px phone.
        Rule(class: "tut-code", container: .maxWidth(.px(420))) { p in
            p.fontSize(.px(13)); p.lineHeight(.px(20)); p.paddingInline(.px(14))
        }
        Rule(class: "tut-code-line") { p in p.whiteSpace(.pre) }
        Rule(class: "tok-kw")    { p in p.color(.token(.codeKw)) }
        Rule(class: "tok-type")  { p in p.color(.token(.codeType)) }
        Rule(class: "tok-str")   { p in p.color(.token(.codeStr)) }
        Rule(class: "tok-num")   { p in p.color(.token(.codeNum)) }
        Rule(class: "tok-cmt")   { p in p.color(.token(.codeCmt)) }
        Rule(class: "tok-wrap")  { p in p.color(.token(.codePunct)) }
        Rule(class: "tut-term-line") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.token(.tCode)); p.lineHeight(.px(22))
            p.whiteSpace(.pre); p.color(.token(.codePlain))
        }
        Rule(class: "tut-term-prompt") { p in p.color(.token(.codeKw)) }
        Rule(class: "tut-term-out")    { p in p.color(.token(.codePunct)) }
        Rule(class: "tut-term-note")   { p in p.color(.token(.codeStr)) }

        // — browser mock —
        Rule(class: "tut-browser") { p in
            p.background(.token(.card))
            p.border(.px(1), .solid, .token(.hairline))
            p.borderRadius(.token(.r3)); p.overflow(.hidden)
            p.boxShadow("var(--elev-1)")
        }
        Rule(class: "tut-browser-chrome") { p in
            p.display(.flex); p.alignItems(.center)
            p.height(.px(40)); p.paddingInline(.token(.s3))
            p.background(.token(.paperSunken))
            p.border(.bottom, width: .px(1), style: .solid, color: .token(.hairline))
        }
        Rule(class: "tut-url") { p in
            p.boxSizing(.borderBox); p.flexGrow(1)
            p.background(.token(.card)); p.borderRadius(.token(.rPill))
            p.border(.px(1), .solid, .token(.hairline))
            p.padding(vertical: .px(5), horizontal: .token(.s3))
            p.fontFamily(Fonts.mono); p.fontSize(.px(12)); p.lineHeight(1.3)
            p.color(.token(.ink3)); p.overflow(.hidden); p.textOverflow(.ellipsis)
            p.whiteSpace(.nowrap)
        }
        // A missing or differently-sized screenshot cannot change the section's height.
        Rule(class: "tut-shot-frame") { p in
            p.aspectRatio(16, 10); p.overflow(.hidden); p.display(.block)
        }
        Rule(class: "tut-shot") { p in
            p.display(.block); p.width(.percent(100)); p.height(.percent(100))
            p.objectFit(.cover)
        }

        // — quiz —
        Rule(class: "tut-quiz") { p in
            p.background(.token(.paperSunken)); p.paddingBlock(.px(72))
            p.border(.top, width: .px(1), style: .solid, color: .token(.hairline))
            p.border(.bottom, width: .px(1), style: .solid, color: .token(.hairline))
        }
        Rule(class: "tut-quiz", media: .up(.lg)) { p in p.paddingBlock(.token(.s9)) }
        Rule(class: "tut-quiz-header") { p in p.margin(.bottom, .token(.s5)) }
        Rule(class: "tut-question") { p in
            p.margin(.zero); p.margin(.top, .token(.s3))
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t6)); p.fontWeight(.custom(700))
            p.lineHeight(1.15); p.letterSpacing(.em(-0.015)); p.color(.token(.ink))
        }
        Rule(class: "tut-quiz-counter") { p in
            p.display(.flex); p.alignItems(.center); p.gap(.token(.s3)); p.margin(.top, .token(.s3))
        }
        Rule(class: "tut-quiz-counter-label") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.token(.t1)); p.lineHeight(1.3)
            p.fontVariantNumeric(.tabularNums); p.color(.token(.ink3))
        }
        Rule(class: "tut-quiz-progress-track") { p in
            p.width(.px(120)); p.height(railWidth)
            p.background(.token(.hairlineStrong))
            p.borderRadius(.token(.rPill)); p.overflow(.hidden); p.flexShrink(0)
        }
        Rule(class: "tut-quiz-progress") { p in
            p.height(railWidth); p.background(.token(.accentVivid))
            p.borderRadius(.token(.rPill))
            p.transition(property: "width", duration: .ms(320), timingFunction: TutorialMotion.ease)
        }
        Rule(class: "tut-quiz-card") { p in
            p.boxSizing(.borderBox)
            p.background(.token(.card))
            p.border(.px(1), .solid, .token(.hairline))
            p.borderRadius(.token(.r4)); p.padding(.token(.s5))
            p.maxWidth(.px(720)); p.marginInline(.auto)
            p.boxShadow("var(--elev-1)")
        }
        Rule(class: "tut-quiz-card", media: .up(.md)) { p in p.padding(.token(.s6)) }
        Rule(class: "tut-quiz-prompt") { p in
            p.margin(.zero)
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t4)); p.lineHeight(1.6)
            p.color(.token(.ink)); p.maxWidth(.ch(62))
        }
        // Options are prose, not code — Instrument Sans, not mono.
        Rule(class: "tut-option") { p in
            p.boxSizing(.borderBox); p.width(.percent(100))
            p.display(.flex); p.alignItems(.flexStart); p.gap(.token(.s3))
            p.minHeight(.px(48))
            p.padding(vertical: .token(.s3), horizontal: .px(14))
            p.margin(.top, .token(.s3))
            p.borderRadius(.token(.r2))
            p.borderWidth(.px(1.5)); p.borderStyle(.solid)
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t2)); p.fontWeight(.custom(500))
            p.lineHeight(1.45); p.color(.token(.ink))
            p.textAlign(.left); p.cursor(.pointer)
            p.transition(interactive)
            p.active { $0.transform(.translateY(.px(1))) }
            ring(&p)
        }
        Rule(class: "tut-option-rest") { p in
            p.background(.token(.card)); p.borderColor(.token(.hairlineStrong))
            p.hover { h in h.background(.token(.paperSunken)); h.borderColor(.token(.ink3)) }
        }
        Rule(class: "tut-option-selected") { p in
            p.background(.token(.accentTint)); p.borderColor(.token(.accent))
        }
        // Three independent channels carry the result — border STYLE, a glyph
        // and a text label — so it survives colour blindness, greyscale print
        // and forced-colours mode.
        Rule(class: "tut-option-correct") { p in
            p.background(.token(.okTint)); p.borderColor(.token(.ok))
            p.borderStyle(.solid); p.borderWidth(.left, .px(3))
        }
        Rule(class: "tut-option-wrong") { p in
            p.background(.token(.errTint)); p.borderColor(.token(.err))
            p.borderStyle(.dashed); p.borderWidth(.left, .px(3))
        }
        Rule(class: "tut-option-label") { p in p.flexGrow(1) }
        Rule(class: "tut-option-verdict") { p in
            p.marginInlineStart(.auto); p.flexShrink(0)
            p.fontFamily(Fonts.mono); p.fontSize(.token(.t1)); p.lineHeight(1.6)
            p.whiteSpace(.nowrap)
        }
        Rule(class: "tut-option-verdict-ok")  { p in p.color(.token(.ok)) }
        Rule(class: "tut-option-verdict-err") { p in p.color(.token(.err)) }
        Rule(class: "tut-radio") { p in
            p.boxSizing(.borderBox); p.flexShrink(0)
            p.width(.px(20)); p.height(.px(20)); p.margin(.top, .px(1))
            p.borderRadius(.token(.rPill))
            p.borderWidth(.px(1.5)); p.borderStyle(.solid)
            p.display(.flex); p.alignItems(.center); p.justifyContent(.center)
            // Mono carries the ✓/✕ marks; the UI face has neither. See tut-chevron.
            p.fontFamily(Fonts.mono)
            p.fontSize(.px(12)); p.lineHeight(1)
        }
        Rule(class: "tut-radio-rest")     { p in p.borderColor(.token(.hairlineStrong)) }
        Rule(class: "tut-radio-selected") { p in p.borderColor(.token(.accent)) }
        Rule(class: "tut-radio-ok") { p in
            p.background(.token(.ok)); p.borderColor(.token(.ok)); p.color(.white)
        }
        Rule(class: "tut-radio-err") { p in
            p.borderColor(.token(.err)); p.color(.token(.err))
        }
        Rule(class: "tut-radio-dot") { p in
            p.width(.px(10)); p.height(.px(10)); p.borderRadius(.token(.rPill))
            p.background(.token(.accent))
        }
        Rule(class: "tut-quiz-submit") { p in p.margin(.top, .token(.s5)) }
        Rule(class: "tut-explain") { p in p.margin(.top, .token(.s4)) }
        Rule(class: "tut-explain-label") { p in
            p.display(.block); p.margin(.bottom, .token(.s1))
            p.fontFamily(Fonts.mono); p.fontSize(.token(.t1)); p.lineHeight(1.3)
        }
        Rule(class: "tut-explain-ok") { p in p.color(.token(.ok)) }
        Rule(class: "tut-explain-no") { p in p.color(.token(.err)) }
        // The explanation prose is never tinted; only its label is.
        Rule(class: "tut-explain-body") { p in
            p.margin(.zero)
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t3)); p.lineHeight(1.6)
            p.color(.token(.ink2)); p.maxWidth(.ch(62))
        }

        // — next-chapter CTA —
        Rule(class: "tut-cta") { p in p.paddingBlock(.token(.s8)) }
        Rule(class: "tut-cta", media: .up(.lg)) { p in p.paddingBlock(.token(.s9)) }
        Rule(class: "tut-cta-card") { p in
            p.boxSizing(.borderBox); p.position(.relative); p.overflow(.hidden)
            p.display(.flex); p.alignItems(.center); p.gap(.token(.s6))
            p.background(.token(.paperSunken))
            p.border(.px(1), .solid, .token(.hairline))
            p.borderRadius(.token(.r5))
            p.padding(vertical: .token(.s6), horizontal: .token(.s5))
        }
        Rule(class: "tut-cta-card", media: .up(.lg)) { p in p.padding(.token(.s7)) }
        Rule(class: "tut-cta-text") { p in p.flexGrow(1); p.minWidth(.zero) }
        Rule(class: "tut-cta-title") { p in
            p.margin(.zero); p.margin(.top, .token(.s3))
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t6)); p.fontWeight(.custom(700))
            p.lineHeight(1.15); p.letterSpacing(.em(-0.015)); p.color(.token(.ink))
        }
        Rule(class: "tut-cta-title", media: .up(.lg)) { p in p.fontSize(.token(.t7)) }
        Rule(class: "tut-cta-tagline") { p in
            p.margin(.zero); p.margin(.top, .token(.s2))
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t3)); p.lineHeight(1.6)
            p.color(.token(.ink3)); p.maxWidth(.ch(48))
        }
        Rule(class: "tut-cta-ghost-num") { p in
            p.display(.none)
            p.position(.absolute); p.right(.token(.s6)); p.bottom(.px(-12))
            p.fontFamily(Fonts.mono); p.fontSize(.px(96)); p.fontWeight(.custom(500))
            p.lineHeight(1); p.fontVariantNumeric(.tabularNums)
            p.color(.token(.hairlineStrong))
            p.pointerEvents(.none); p.userSelect(.none)
        }
        Rule(class: "tut-cta-ghost-num", media: .up(.md)) { p in p.display(.block) }

        // — footer —
        Rule(class: "tut-footer") { p in
            p.background(.token(.paper)); p.paddingBlock(.px(40))
            p.border(.top, width: .px(1), style: .solid, color: .token(.hairline))
        }
        Rule(class: "tut-footer-inner") { p in
            p.display(.flex); p.flexDirection(.column); p.gap(.token(.s4))
        }
        Rule(class: "tut-footer-inner", media: .up(.md)) { p in
            p.flexDirection(.row); p.alignItems(.center); p.justifyContent(.spaceBetween)
        }
        Rule(class: "tut-footer-brand") { p in
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t2)); p.lineHeight(1.5); p.color(.token(.ink3))
        }
        Rule(class: "tut-footer-links") { p in
            p.display(.flex); p.flexWrap(.wrap); p.gap(.token(.s5))
        }
        Rule(class: "tut-footer-link") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.token(.t1)); p.lineHeight(1.3)
            p.color(.token(.ink3))
            p.hover { h in
                h.color(.token(.ink))
                h.textDecorationLine(.underline); h.textUnderlineOffset(.px(4))
                h.textDecorationThickness(.px(1)); h.textDecorationColor(.token(.accent))
            }
            ring(&p)
        }

        // — overview —
        Rule(class: "tut-track") { p in p.paddingBlock(.token(.s6)) }
        Rule(class: "tut-track-label") { p in p.margin(.bottom, .px(20)) }
        Rule(class: "tut-cards") { p in
            p.display(.grid); p.gridTemplateColumns("minmax(0, 1fr)"); p.gap(.token(.s4))
        }
        Rule(class: "tut-cards", media: .up(.md)) { p in
            p.gridTemplateColumns("repeat(2, minmax(0, 1fr))")
        }
        Rule(class: "tut-cards", media: .up(.xl)) { p in
            p.gridTemplateColumns("repeat(3, minmax(0, 1fr))"); p.gap(.px(20))
        }
        Rule(class: "tut-card-link") { p in
            p.boxSizing(.borderBox)
            p.display(.flex); p.flexDirection(.column); p.gap(.token(.s2))
            p.minHeight(.px(172)); p.padding(.px(20))
            p.background(.token(.card))
            p.border(.px(1), .solid, .token(.hairline))
            p.borderRadius(.token(.r3))
            p.boxShadow("var(--elev-1)")
            p.transition(interactive)
            p.hover { h in
                h.transform(.translateY(.px(-2)))
                h.borderColor(.token(.hairlineStrong))
                h.boxShadow("var(--elev-2)")
            }
            p.active { $0.transform(.translateY(.zero)) }
            ring(&p)
        }
        Rule(class: "tut-card-kicker") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.token(.t1)); p.fontWeight(.custom(500))
            p.lineHeight(1.3); p.letterSpacing(.em(0.01))
            p.fontVariantNumeric(.tabularNums); p.color(.token(.ink3))
        }
        Rule(class: "tut-card-title") { p in
            p.display(.block)
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t4)); p.fontWeight(.custom(600))
            p.lineHeight(1.3); p.letterSpacing(.em(-0.01))
            p.textWrap(.balance); p.color(.token(.ink))
        }
        Rule(class: "tut-card-tagline") { p in
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t2)); p.lineHeight(1.55); p.color(.token(.ink3))
            p.lineClamp(2)
        }
        Rule(class: "tut-card-spacer") { p in p.flexGrow(1) }
        Rule(class: "tut-card-foot") { p in
            p.display(.flex); p.alignItems(.center); p.gap(.token(.s2))
            p.fontFamily(Fonts.mono); p.fontSize(.token(.t1)); p.lineHeight(1.3)
            p.fontVariantNumeric(.tabularNums); p.color(.token(.ink3))
        }
        Rule(class: "tut-card-minutes") { p in p.whiteSpace(.nowrap) }
        Rule(class: "tut-card-arrow") { p in
            p.marginInlineStart(.auto); p.lineHeight(1)
            p.transition(property: "transform", duration: .ms(120), timingFunction: TutorialMotion.ease)
            p.hover { h in h.color(.token(.accent)); h.transform(.translateX(.px(3))) }
        }
        Rule(class: "tut-recap") { p in
            p.listStyleType(.none); p.margin(.zero); p.padding(.zero)
        }
        Rule(class: "tut-recap-item") { p in
            p.paddingBlock(.token(.s4))
            p.border(.top, width: .px(1), style: .solid, color: .token(.hairline))
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t3)); p.lineHeight(1.65)
            p.color(.token(.ink)); p.maxWidth(.ch(62))
        }

        // — 404 —
        Rule(class: "tut-404") { p in
            p.minHeight(.dvh(60)); p.display(.grid)
            p.placeContent(.center, .center); p.textAlign(.center)
        }
        Rule(class: "tut-404-title") { p in
            p.margin(.zero); p.margin(.top, .token(.s3))
            p.fontFamily(Fonts.ui); p.fontSize(.token(.t7)); p.fontWeight(.custom(700))
            p.lineHeight(1.06); p.letterSpacing(.em(-0.02)); p.color(.token(.ink))
        }
        Rule(class: "tut-404-body") { p in
            p.margin(.zero); p.margin(.top, .token(.s3))
            p.fontFamily(Fonts.prose); p.fontOpticalSizing(.auto)
            p.fontSize(.token(.t3)); p.lineHeight(1.65); p.color(.token(.ink2))
        }

        // — reduced motion. `Keyframes` and the view-transition engine gate
        //   themselves; CSS transitions have to be switched off by hand. —
        Rule(class: "tut-btn", media: reduceMotion)            { p in p.transitionDuration(.ms(0.01)) }
        Rule(class: "tut-btn-arrow", media: reduceMotion)      { p in p.transitionDuration(.ms(0.01)) }
        Rule(class: "tut-card-link", media: reduceMotion)      { p in p.transitionDuration(.ms(0.01)) }
        Rule(class: "tut-card-arrow", media: reduceMotion)     { p in p.transitionDuration(.ms(0.01)) }
        Rule(class: "tut-option", media: reduceMotion)         { p in p.transitionDuration(.ms(0.01)) }
        Rule(class: "tut-step", media: reduceMotion)           { p in p.transitionDuration(.ms(0.01)) }
        Rule(class: "tut-step-badge", media: reduceMotion)     { p in p.transitionDuration(.ms(0.01)) }
        Rule(class: "tut-rail-fill", media: reduceMotion)      { p in p.transitionDuration(.ms(0.01)) }
        Rule(class: "tut-progress-fill", media: reduceMotion)  { p in p.transitionDuration(.ms(0.01)) }
        Rule(class: "tut-quiz-progress", media: reduceMotion)  { p in p.transitionDuration(.ms(0.01)) }
        Rule(class: "tut-chevron", media: reduceMotion)        { p in p.transitionDuration(.ms(0.01)) }
    }
}
