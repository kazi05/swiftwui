import SwiftWUI

public extension ColorToken {
    static let pageBg      = ColorToken("page-bg")
    static let bandBg      = ColorToken("band-bg")
    static let darkBg      = ColorToken("dark-bg")
    static let darkCard    = ColorToken("dark-card")
    static let overlayBg   = ColorToken("overlay-bg")
    static let ink         = ColorToken("ink")
    static let muted       = ColorToken("muted")
    static let faint       = ColorToken("faint")
    static let borderLight = ColorToken("border-light")
    static let darkText    = ColorToken("dark-text")
    static let darkMuted   = ColorToken("dark-muted")
    static let accent      = ColorToken("accent")
    static let accentSoft  = ColorToken("accent-soft")
    static let onAccent    = ColorToken("on-accent")
    static let codeType    = ColorToken("code-type")
    static let codeString  = ColorToken("code-string")
}

public enum Fonts {
    public static let ui = "system-ui, -apple-system, 'Segoe UI', sans-serif"
    public static let mono = "ui-monospace, 'SF Mono', Menlo, monospace"
}

public enum TutorialTheme {
    public static let definition = ThemeDefinition { t in
        t.set(ColorToken.pageBg, .hex("#faf9f7"))
        t.set(ColorToken.bandBg, .hex("#f2f0ec"))
        t.set(ColorToken.darkBg, .hex("#17140f"))
        t.set(ColorToken.darkCard, .hex("#211d17"))
        t.set(ColorToken.overlayBg, .hex("#1d1a15"))
        t.set(ColorToken.ink, .hex("#1c1917"))
        t.set(ColorToken.muted, .hex("#57534e"))
        t.set(ColorToken.faint, .hex("#a8a29e"))
        t.set(ColorToken.borderLight, .hex("#e7e5e0"))
        t.set(ColorToken.darkText, .hex("#f5f1ea"))
        t.set(ColorToken.darkMuted, .hex("#c9c3b8"))
        t.set(ColorToken.accent, .hex("#d9552f"))
        t.set(ColorToken.accentSoft, .hex("#e8794f"))
        t.set(ColorToken.onAccent, .hex("#fffaf5"))
        t.set(ColorToken.codeType, .hex("#dfb07e"))
        t.set(ColorToken.codeString, .hex("#a8b892"))
    }
}

public enum TutorialStyles {
    @RulesBuilder public static var rules: [Rule] {
        Rule(element: "body") { p in
            p.margin(.zero)
            p.background(.token(.pageBg))
            p.color(.token(.ink))
            p.fontFamily(Fonts.ui)
        }
        Rule(element: "a") { p in
            p.color(.current)
            p.textDecoration(.none)
        }
        Rule(class: "tut-content") { p in
            p.maxWidth(.px(1040)); p.margin(vertical: .zero, horizontal: .auto)
            p.padding(vertical: .zero, horizontal: .px(24))
        }
        // — nav / footer —
        Rule(class: "tut-nav") { p in
            p.background(.token(.pageBg))
            p.style("border-bottom", "1px solid var(--border-light)")
        }
        Rule(class: "tut-nav-inner") { p in
            p.display(.flex); p.alignItems(.center)
            p.height(.px(64)); p.gap(.px(32))
        }
        Rule(class: "tut-brand") { p in
            p.display(.flex); p.gap(.px(8))
            p.fontSize(.px(17)); p.fontWeight(.custom(600))
        }
        Rule(class: "tut-nav-links") { p in
            p.display(.flex); p.gap(.px(28))
            p.fontSize(.px(14)); p.fontWeight(.custom(500))
            p.color(.token(.muted))
            p.style("margin-left", "auto")
        }
        Rule(class: "tut-footer") { p in
            p.style("border-top", "1px solid var(--border-light)")
            p.padding(vertical: .px(28), horizontal: .zero)
            p.fontSize(.px(13)); p.color(.token(.muted))
        }
        Rule(class: "tut-footer-inner") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.display(.flex); p.alignItems(.center)
            p.style("justify-content", "space-between")
        }
        Rule(class: "tut-footer-links") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.display(.flex); p.gap(.px(28))
        }
        // — chapter bar (dark) —
        Rule(class: "tut-chapterbar") { p in
            p.background(.token(.darkBg))
            p.style("border-bottom", "1px solid rgba(255,255,255,0.10)")
            p.position(.sticky); p.top(.zero); p.zIndex(40)
        }
        Rule(class: "tut-chapterbar-inner") { p in
            p.display(.flex); p.height(.px(56)); p.alignItems(.center); p.gap(.px(20))
        }
        Rule(class: "tut-series") { p in
            p.fontSize(.px(15)); p.fontWeight(.custom(600)); p.color(.token(.darkText))
        }
        Rule(class: "tut-series-accent") { p in p.color(.token(.accentSoft)) }
        Rule(class: "tut-divider") { p in
            p.width(.px(1)); p.height(.px(20))
            p.style("background", "rgba(255,255,255,0.15)")
        }
        Rule(class: "tut-dropdown-wrap") { p in p.position(.relative) }
        Rule(class: "tut-spacer") { p in p.flexGrow(1) }
        Rule(class: "tut-dropdown") { p in
            p.style("background", "rgba(255,255,255,0.06)")
            p.style("border", "1px solid rgba(255,255,255,0.14)")
            p.borderRadius(.px(8)); p.color(.token(.darkText))
            p.fontSize(.px(14)); p.cursor(.pointer)
            p.padding(vertical: .px(8), horizontal: .px(14))
        }
        Rule(class: "tut-pill") { p in
            p.style("border", "1px solid rgba(255,255,255,0.14)")
            p.borderRadius(.px(999)); p.color(.token(.darkMuted))
            p.fontSize(.px(13)); p.cursor(.pointer)
            p.padding(vertical: .px(7), horizontal: .px(14))
        }
        // — chapter menu overlay —
        Rule(class: "tut-menu") { p in
            p.display(.none)
            p.position(.absolute); p.style("top", "52px"); p.left(.zero)
            p.width(.px(340)); p.background(.token(.overlayBg))
            p.style("border", "1px solid rgba(255,255,255,0.12)")
            p.borderRadius(.px(14)); p.zIndex(50)
            p.padding(vertical: .px(20), horizontal: .px(12))
            p.boxShadow("0px 20px 50px -10px rgba(0,0,0,0.35)")
        }
        Rule(class: "tut-menu-open") { p in p.display(.block) }
        Rule(class: "tut-menu-group") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.style("margin-bottom", "20px")
        }
        Rule(class: "tut-menu-label") { p in
            p.display(.block)
            p.fontFamily(Fonts.mono); p.fontSize(.px(11))
            p.letterSpacing(.px(1)); p.style("text-transform", "uppercase")
            p.style("color", "rgba(201,195,184,0.55)")
            p.style("margin-bottom", "8px")
        }
        Rule(class: "tut-menu-item") { p in
            p.display(.block)
            p.style("color", "rgba(245,241,234,0.8)")
            p.fontSize(.px(14)); p.borderRadius(.px(8))
            p.padding(vertical: .px(8), horizontal: .px(12))
            p.hover { h in h.style("background", "rgba(255,255,255,0.05)") }
        }
        Rule(class: "tut-menu-item-active") { p in
            p.style("background", "rgba(255,255,255,0.08)")
            p.color(.token(.darkText)); p.fontWeight(.custom(600))
        }
        Rule(class: "tut-menu-dot") { p in
            p.display(.inlineBlock)
            p.width(.px(6)); p.height(.px(6)); p.borderRadius(.px(999))
            p.background(.token(.accent))
            p.style("margin-right", "8px")
        }
        // — hero —
        Rule(class: "tut-hero") { p in
            p.background(.token(.darkBg)); p.color(.token(.darkText))
            p.padding(vertical: .px(104), horizontal: .zero)
        }
        Rule(class: "tut-hero-grid") { p in
            p.display(.grid); p.gridTemplateColumns("1fr 460px"); p.gap(.px(72))
            p.alignItems(.center)
        }
        Rule(class: "tut-hero-text") { p in
            // ponytail: grid text columns default to min-width:auto and can
            // overflow their track; min-width 0 lets long titles wrap instead.
            p.style("min-width", "0")
        }
        Rule(class: "tut-hero-title") { p in
            p.fontSize(.px(54)); p.fontWeight(.bold)
            p.letterSpacing(.px(-1.5)); p.margin(.zero)
        }
        Rule(class: "tut-hero-title-simple") { p in
            // ponytail: standalone (not paired with tut-hero-title anymore) —
            // StyleRegistry emits hash-ordered rules, so a same-specificity
            // override pair is a coin flip; this carries the full declaration set.
            p.fontSize(.px(44)); p.fontWeight(.bold)
            p.letterSpacing(.px(-1)); p.margin(.zero)
        }
        Rule(class: "tut-hero-tagline") { p in
            p.fontSize(.px(21)); p.fontWeight(.custom(500)); p.color(.token(.darkMuted))
        }
        Rule(class: "tut-hero-body") { p in
            p.fontSize(.px(16)); p.style("line-height", "26px")
            p.style("color", "rgba(201,195,184,0.85)")
        }
        Rule(class: "tut-hero-simple") { p in
            // ponytail: no unique visuals of its own — it opts out of the
            // grid layout (default block flow) and inherits the dark band
            // from .tut-hero; marker rule keeps it in the registered set.
            p.style("--noop", "0")
        }
        Rule(class: "tut-hero-actions") { p in
            p.display(.flex); p.gap(.px(12)); p.style("padding-top", "8px")
        }
        Rule(class: "tut-btn-primary") { p in
            p.background(.token(.accent)); p.color(.token(.onAccent))
            p.borderRadius(.px(10)); p.fontSize(.px(15)); p.fontWeight(.custom(600))
            p.padding(vertical: .px(12), horizontal: .px(20))
            p.display(.inlineBlock); p.cursor(.pointer)
            p.style("border", "none")
        }
        Rule(class: "tut-btn-ghost") { p in
            p.style("border", "1px solid rgba(245,241,234,0.25)")
            p.color(.token(.darkText)); p.borderRadius(.px(10))
            p.fontSize(.px(15)); p.fontWeight(.custom(600))
            p.padding(vertical: .px(12), horizontal: .px(20))
            p.display(.inlineBlock); p.cursor(.pointer)
            p.style("background", "transparent")
        }
        // — kickers —
        Rule(class: "tut-kicker") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.px(12)); p.fontWeight(.custom(500))
            p.letterSpacing(.px(1.5)); p.color(.token(.accent))
            p.style("text-transform", "uppercase")
        }
        Rule(class: "tut-kicker-dark") { p in p.color(.token(.accentSoft)) }
        // — dark cards (code + terminal) —
        Rule(class: "tut-card-dark") { p in
            p.background(.token(.darkCard))
            p.style("border", "1px solid rgba(255,255,255,0.08)")
            p.borderRadius(.px(14)); p.overflow(.hidden)
            p.boxShadow("0px 16px 40px -8px rgba(28,26,23,0.12)")
        }
        Rule(class: "tut-chrome") { p in
            p.display(.flex); p.alignItems(.center); p.gap(.px(8))
            p.padding(vertical: .px(13), horizontal: .px(18))
        }
        Rule(class: "tut-dot")   { p in p.width(.px(10)); p.height(.px(10)); p.borderRadius(.px(999)) }
        Rule(class: "tut-dot-r") { p in p.background(.hex("#ff5f57")) }
        Rule(class: "tut-dot-y") { p in p.background(.hex("#febc2e")) }
        Rule(class: "tut-dot-g") { p in p.background(.hex("#28c840")) }
        Rule(class: "tut-chrome-title") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.px(12))
            p.style("color", "rgba(201,195,184,0.7)")
        }
        Rule(class: "tut-code") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.px(13)); p.color(.token(.darkText))
            p.padding(vertical: .zero, horizontal: .px(18))
            p.style("padding-bottom", "20px")
            p.overflow(.auto)
        }
        Rule(class: "tut-code-line") { p in p.style("line-height", "21px"); p.style("white-space", "pre") }
        Rule(class: "tok-kw")   { p in p.color(.token(.accentSoft)) }
        Rule(class: "tok-type") { p in p.color(.token(.codeType)) }
        Rule(class: "tok-str")  { p in p.color(.token(.codeString)) }
        Rule(class: "tok-num")  { p in p.color(.token(.codeString)) }
        Rule(class: "tok-cmt")  { p in p.color(.token(.faint)) }
        Rule(class: "tok-wrap") { p in p.color(.token(.accentSoft)) }
        // — terminal lines —
        Rule(class: "tut-term-line") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.px(13))
            p.style("line-height", "22px"); p.style("white-space", "pre")
        }
        Rule(class: "tut-term-prompt") { p in p.color(.token(.accentSoft)) }
        Rule(class: "tut-term-out")    { p in p.color(.token(.darkMuted)) }
        Rule(class: "tut-term-note")   { p in p.color(.token(.codeString)) }
        // — sections —
        Rule(class: "tut-section") { p in
            p.padding(vertical: .zero, horizontal: .zero)
            p.style("padding-top", "88px"); p.style("padding-bottom", "56px")
        }
        Rule(class: "tut-section-header") { p in
            // ponytail: caps the intro copy's measure for readability.
            p.maxWidth(.px(720))
        }
        Rule(class: "tut-section-title") { p in
            p.fontSize(.px(30)); p.fontWeight(.bold); p.letterSpacing(.px(-0.5))
            p.margin(.zero); p.style("margin-top", "12px")
        }
        Rule(class: "tut-section-intro") { p in
            p.fontSize(.px(16)); p.style("line-height", "26px"); p.color(.token(.muted))
        }
        Rule(class: "tut-section-body") { p in
            p.display(.grid); p.gridTemplateColumns("1fr 480px"); p.gap(.px(56))
            p.style("margin-top", "40px"); p.style("align-items", "start")
        }
        // ponytail: StyleProxy.media(_:) inside a Rule builder is a dead end —
        // Rule.register only reads proxy.declarations/pseudoBlocks, never
        // proxy.mediaBlocks (that's Style-bundle-only, see Style.swift). Use
        // Rule's own `media:` param instead, which register() does wire up.
        Rule(class: "tut-section-body", media: .maxWidth(.px(1080))) { m in
            m.gridTemplateColumns("1fr")
        }
        Rule(class: "tut-steps") { p in
            // ponytail: pure grouping div — visuals live on child .tut-step.
            p.style("--noop", "0")
        }
        Rule(class: "tut-step") { p in
            p.display(.flex); p.gap(.px(16))
            p.padding(vertical: .px(16), horizontal: .zero)
            p.style("border-top", "1px solid var(--border-light)")
        }
        Rule(class: "tut-step-num") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.px(13)); p.fontWeight(.custom(500))
            p.color(.token(.faint))
        }
        Rule(class: "tut-step-title") { p in
            p.fontSize(.px(15)); p.style("line-height", "23px"); p.color(.token(.muted))
            p.margin(.zero)
        }
        Rule(class: "tut-step-active") { p in p.style("--noop", "0") }  // marker class; children styled below
        Rule(class: "tut-step-detail") { p in
            p.fontSize(.px(14)); p.style("line-height", "22px"); p.color(.token(.faint))
            p.margin(.zero); p.style("margin-top", "4px")
        }
        Rule(class: "tut-panel") { p in
            p.position(.sticky); p.style("top", "96px")
        }
        Rule(class: "tut-panel", media: .maxWidth(.px(1080))) { m in m.position(.static) }
        // — browser mock —
        Rule(class: "tut-browser") { p in
            p.background(.white); p.style("border", "1px solid var(--border-light)")
            p.borderRadius(.px(14)); p.overflow(.hidden)
            p.boxShadow("0px 16px 40px -8px rgba(28,26,23,0.10)")
        }
        Rule(class: "tut-browser-chrome") { p in
            p.background(.token(.bandBg)); p.display(.flex); p.alignItems(.center)
            p.gap(.px(10)); p.padding(vertical: .px(12), horizontal: .px(16))
        }
        Rule(class: "tut-url") { p in
            p.background(.white); p.borderRadius(.px(6)); p.flexGrow(1)
            p.fontFamily(Fonts.mono); p.fontSize(.px(12)); p.color(.token(.muted))
            p.padding(vertical: .px(5), horizontal: .px(12))
        }
        Rule(class: "tut-shot") { p in p.display(.block); p.width(.percent(100)) }
        // — quiz —
        Rule(class: "tut-quiz") { p in
            p.background(.token(.bandBg))
            p.padding(vertical: .px(72), horizontal: .zero)
        }
        Rule(class: "tut-quiz-header") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.style("margin-bottom", "24px")
        }
        Rule(class: "tut-question") { p in
            p.fontSize(.px(26)); p.fontWeight(.bold); p.letterSpacing(.px(-0.4))  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.margin(.zero); p.style("margin-top", "8px")
        }
        Rule(class: "tut-quiz-card") { p in
            p.background(.white); p.style("border", "1px solid var(--border-light)")
            p.borderRadius(.px(14)); p.padding(.px(28))
            p.maxWidth(.px(720)); p.margin(vertical: .zero, horizontal: .auto)
        }
        Rule(class: "tut-quiz-prompt") { p in
            p.fontSize(.px(18)); p.fontWeight(.custom(600)); p.style("line-height", "26px")
        }
        Rule(class: "tut-option") { p in
            p.display(.flex); p.alignItems(.center); p.gap(.px(12))
            p.style("border", "1px solid var(--border-light)")
            p.borderRadius(.px(10)); p.cursor(.pointer)
            p.padding(vertical: .px(13), horizontal: .px(16))
            p.fontFamily(Fonts.mono); p.fontSize(.px(14))
            p.style("margin-top", "14px")
        }
        Rule(class: "tut-option-selected") { p in
            p.style("background", "rgba(217,85,47,0.06)")
            p.style("border", "1.5px solid var(--accent)")
        }
        Rule(class: "tut-option-correct") { p in
            p.style("background", "rgba(90,140,60,0.08)")
            p.style("border", "1.5px solid #5a8c3c")
        }
        Rule(class: "tut-option-wrong") { p in
            p.style("background", "rgba(217,85,47,0.06)")
            p.style("border", "1.5px solid var(--accent)")
        }
        Rule(class: "tut-radio") { p in
            p.width(.px(18)); p.height(.px(18)); p.borderRadius(.px(999))
            p.style("border", "1.5px solid var(--border-light)")
            p.boxSizing(.borderBox)
        }
        Rule(class: "tut-option-label") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.flexGrow(1)
        }
        Rule(class: "tut-quiz-submit") { p in
            p.background(.token(.accent)); p.color(.token(.onAccent))
            p.borderRadius(.px(10)); p.fontSize(.px(14)); p.fontWeight(.custom(600))
            p.padding(vertical: .px(11), horizontal: .px(20))
            p.style("border", "none"); p.cursor(.pointer)
            p.style("margin-top", "18px")
        }
        Rule(class: "tut-explain") { p in
            p.fontSize(.px(14)); p.style("line-height", "22px")
            p.style("margin-top", "16px")
        }
        Rule(class: "tut-explain-ok") { p in p.color(.hex("#5a8c3c")) }
        Rule(class: "tut-explain-no") { p in p.color(.token(.accent)) }
        // — CTA / footer / overview: transcribe header values —
        Rule(class: "tut-cta") { p in
            p.padding(vertical: .px(88), horizontal: .zero)
        }
        Rule(class: "tut-cta-card") { p in
            p.background(.token(.darkBg)); p.color(.token(.darkText))
            p.borderRadius(.px(18)); p.display(.flex); p.alignItems(.center); p.gap(.px(48))
            p.padding(vertical: .px(44), horizontal: .px(48))
        }
        Rule(class: "tut-cta-text") { p in p.flexGrow(1) }
        Rule(class: "tut-cta-title") { p in
            p.fontSize(.px(28)); p.fontWeight(.bold); p.letterSpacing(.px(-0.5))  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.margin(.zero); p.style("margin-top", "8px")
        }
        Rule(class: "tut-cta-tagline") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.fontSize(.px(16)); p.style("line-height", "24px"); p.color(.token(.darkMuted))
        }
        Rule(class: "tut-overview-hero") { p in
            // ponytail: same as tut-hero-simple — no unique visuals, marker only.
            p.style("--noop", "0")
        }
        Rule(class: "tut-track") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.padding(vertical: .px(32), horizontal: .zero)
        }
        Rule(class: "tut-track-label") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.style("margin-bottom", "20px")
        }
        Rule(class: "tut-cards") { p in
            p.display(.grid); p.gridTemplateColumns("repeat(3, 1fr)"); p.gap(.px(20))
        }
        Rule(class: "tut-cards", media: .maxWidth(.px(1080))) { m in m.gridTemplateColumns("1fr") }
        Rule(class: "tut-card-link") { p in
            p.display(.block); p.background(.white)
            p.style("border", "1px solid var(--border-light)")
            p.borderRadius(.px(14)); p.padding(.px(24))
            p.hover { h in h.style("border-color", "var(--accent)") }
        }
        Rule(class: "tut-card-kicker") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.fontFamily(Fonts.mono); p.fontSize(.px(12)); p.fontWeight(.custom(500))
            p.letterSpacing(.px(1.5)); p.color(.token(.accent))
            p.style("text-transform", "uppercase")
        }
        Rule(class: "tut-card-title") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.display(.block)
            p.fontSize(.px(17)); p.fontWeight(.custom(600)); p.color(.token(.ink))
            p.style("margin-top", "8px")
        }
        Rule(class: "tut-card-tagline") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.display(.block)
            p.fontSize(.px(14)); p.style("line-height", "20px"); p.color(.token(.muted))
            p.style("margin-top", "4px")
        }
        Rule(class: "tut-card-minutes") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.display(.block)
            p.fontFamily(Fonts.mono); p.fontSize(.px(12)); p.color(.token(.faint))
            p.style("margin-top", "12px")
        }
        Rule(class: "tut-recap") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.listStyle("none"); p.margin(.zero); p.padding(.zero)
        }
        Rule(class: "tut-recap-item") { p in  // ponytail: derived — no Figma spec, matched to sibling pattern
            p.padding(vertical: .px(16), horizontal: .zero)
            p.style("border-top", "1px solid var(--border-light)")
            p.fontSize(.px(15)); p.style("line-height", "24px"); p.color(.token(.ink))
        }
    }
}
