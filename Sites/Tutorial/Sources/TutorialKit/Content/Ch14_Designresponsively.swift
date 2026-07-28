/// Chapter 14 — Design responsively. Pinned to Samples/Tour.
public enum Ch14 {
    static let structuralCode = #"""
struct ResponsiveDemo: Tag, Styled {
    /// Reserve `\.media` for real tree differences. It reads `false` during
    /// SSG, so the phone list is what prerenders and the grid arrives with
    /// hydration — for pure styling use `responsive()`/`.media()` instead.
    @Environment(\.media) private var media

    var body: some Tag {
        Main(class: "tour") {
            H1("Responsive layout")
            if media.matches(.up(.md)) {
                CardGrid(cards: Gallery.cards)
            } else {
                Ul(class: "compact") {
                    ForEach(Gallery.cards, id: \.id) { card in
                        Li { Strong { Text(card.name) }; Text(" — " + card.blurb) }
                    }
                }
            }
            CardBox(card: Gallery.cards[1])
            P(class: "note") { "A list and a grid are different trees, not one tree styled twice." }
            Link("/") { Span { "Back to the tour" } }
        }
    }
"""#

    static let rulesCode = #"""
    /// Stylesheet level: the query lives in the rule, so nothing flashes before
    /// hydration. `media:` and `container:` are mutually exclusive on one Rule.
    @RulesBuilder var styles: [Rule] {
        Rule(class: "compact") { p in
            p.listStyleType(.none)
            p.padding(.zero)
            p.display(.grid); p.gap(.px(12))
        }
        // Combinators self-parenthesise, so they nest without producing invalid CSS.
        Rule(class: "compact", media: .or(.down(.sm), .orientation(.portrait))) { p in
            p.gap(.px(6))
        }
        Rule(class: "note", media: .prefersColorScheme(.dark)) { p in
            p.color(.hex("#a8a29e"))
        }
    }
"""#

    static let scaleCode = #"""
/// Per-breakpoint values. Each one desugars to a base class rule plus
/// non-overlapping `@media` ranges. Never pair a `responsive()` modifier with a
/// plain call for the same property on the same element: the plain call becomes
/// an inline style and out-specifies every override.
struct CardGrid: Tag {
    let cards: [Card]

    var body: some Tag {
        Div {
            ForEach(cards, id: \.id) { card in
                Article(class: "card") {
                    H3(card.name)
                    P { Text(card.blurb) }
                }
                .background(.hex("#ffffff"))
                .borderRadius(.px(10))
            }
        }
        .display(.grid)
        .gap(.px(16))
        .gridTemplateColumns(responsive("1fr", md: "1fr 1fr", lg: "repeat(3, 1fr)"))
        .padding(responsive(.px(12), md: .px(20), lg: .px(28)))
        .fontSize(responsive(.rem(0.95), lg: .rem(1.05)))
    }
}
"""#

    static let containerCode = #"""
/// A container query: the card measures the box it sits in, so the same card
/// restyles itself in a narrow sidebar without either side knowing the viewport
/// width. An unusable container name is dropped, never sanitised.
struct CardBox: Tag {
    let card: Card

    var body: some Tag {
        Section {
            Article(class: "card") {
                H3(card.name)
                P { Text(card.blurb) }
            }
            .borderRadius(.px(10))
            .border(.px(1), .solid, .hex("#e7e5e4"))
            .container(.up(.sm), name: "gallery") { p in
                p.display(.flex)
                p.alignItems(.center)
                p.gap(.px(16))
            }
        }
        .containerType(.inlineSize, name: "gallery")
    }
}
"""#

    public static let chapter = Chapter(
        slug: "responsive-design", track: .styles, kicker: "CHAPTER · STYLES",
        title: "Design responsively",
        tagline: "One media vocabulary across five surfaces — from a structural branch to a container query.",
        minutes: 20, kind: .chapter,
        sections: [
            Section(anchor: "resp-structural", kicker: "01 · MEDIA",
                    title: "Branch the tree, not the styles",
                    intro: "@Environment(\\.media) answers a media query inside body, so a component can build a different tree per viewport. Reserve it for differences that are structural — a list and a grid — and leave sizes and spacing to the styling surfaces.",
                    steps: [
                        Step("Read \\.media with @Environment, then ask it a question: media.matches(.up(.md)).",
                             detail: "The read is tracked, so a flip re-renders that component and nothing else."),
                        Step("Every query answers false when there is no live store — native builds and SSG.",
                             detail: "The compact branch is what prerenders; the wide branch arrives with hydration."),
                        Step("One matchMedia listener is registered per distinct condition string, not per call site."),
                        Step("For a change that is only visual, reach for responsive() or .media() instead.",
                             detail: "A structural branch costs a re-render and shows the wrong branch until the runtime boots."),
                    ],
                    panel: .code(CodePanel(file: "Responsive.swift", code: structuralCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/Responsive.swift",
                                                           marker: "tour-responsive-structural")))),
            Section(anchor: "resp-vocabulary", kicker: "02 · QUERIES",
                    title: "The breakpoint vocabulary",
                    intro: "Breakpoint is a four-stop mobile-first scale — sm 640, md 768, lg 1024, xl 1280 — and .up/.down turn a stop into a MediaQuery. Everything the scale does not cover composes from primitives.",
                    steps: [
                        Step(".up(bp) is (min-width: bp); .down(bp) is (max-width: bp - 0.02px).",
                             detail: "The fraction keeps .up(.md) and .down(.md) from both matching at exactly 768px."),
                        Step("Primitives cover the rest: .minWidth, .maxWidth, .minHeight, .maxHeight, .orientation, .prefersColorScheme."),
                        Step("Compose with .and, .or and .not — each wraps its operands in parentheses, so nesting stays valid CSS at any depth."),
                        Step(".custom(_:) is the escape hatch, and it is checked.",
                             detail: "An unsafe string becomes not all, which matches nothing; debug builds trip an assertion first."),
                    ],
                    panel: .terminal(title: "zsh — tour", lines: [
                        TermLine(.command, "swift run Tour ssg --out dist"),
                        TermLine(.note, "> generated 8 pages, 1 sitemap file(s)"),
                        TermLine(.command, "grep -Eo '@(media|container) [^{]*' dist/responsive/index.html"),
                        TermLine(.output, "@media (prefers-reduced-motion: reduce)"),
                        TermLine(.output, "@container gallery (min-width: 640px)"),
                        TermLine(.output, "@media ((max-width: 639.98px) or (orientation: portrait))"),
                        TermLine(.output, "@media (prefers-color-scheme: dark)"),
                    ])),
            Section(anchor: "resp-scale", kicker: "03 · SCALE",
                    title: "One value per breakpoint",
                    intro: "Styling across widths needs no branch: responsive(_:sm:md:lg:xl:) hands a modifier one value per stop. It rides on the typed modifier set that v0.4.0 widened to most of the CSS surface, so a raw .style(\"property\", \"value\") string is now the exception rather than the habit.",
                    steps: [
                        Step("responsive(base, sm:md:lg:xl:) builds a Responsive<Value>; only the stops you name become overrides.",
                             detail: "Overrides sort themselves by breakpoint, so the order you write them in does not matter."),
                        Step("It desugars to a base class rule plus non-overlapping @media ranges — never an inline style."),
                        Step("Never pair a responsive value with a plain call for the same property on the same element.",
                             detail: "The plain call becomes an inline style and out-specifies every override, without a warning."),
                        Step("The overload set is deliberately bounded to what varies by width.",
                             detail: "padding, margin, width, height, minWidth, maxWidth, fontSize, gap, display, flexDirection, textAlign, gridTemplateColumns."),
                    ],
                    panel: .code(CodePanel(file: "Responsive.swift", code: scaleCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/Responsive.swift",
                                                           marker: "tour-responsive-scale")))),
            Section(anchor: "resp-container", kicker: "04 · CONTAINER",
                    title: "Ask the box, not the window",
                    intro: "A container query measures the element's own box. The same card lays out one way in a wide gallery and another in a narrow sidebar, and neither side has to know the viewport width.",
                    steps: [
                        Step(".containerType(.inlineSize, name:) on a parent establishes the containment context."),
                        Step(".container(query, name:) on a child scopes styles to that container's size.",
                             detail: "It reuses the MediaQuery vocabulary — .up(.sm) reads the container, not the viewport."),
                        Step("The same nesting exists on StyleProxy, so a Rule body can carry a container query too."),
                        Step("An invalid container name is dropped, never sanitised and kept.",
                             detail: "Falling back to the unnamed @container form is the injection guard, and it holds in release."),
                    ],
                    panel: .code(CodePanel(file: "Responsive.swift", code: containerCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/Responsive.swift",
                                                           marker: "tour-responsive-container")))),
            Section(anchor: "resp-rules", kicker: "05 · RULES",
                    title: "The same query at stylesheet level",
                    intro: "Rule(class:media:) puts the query in the stylesheet instead of on the element. The browser answers it before any Swift runs, so the first paint is already correct.",
                    steps: [
                        Step("Adopt Styled and declare @RulesBuilder var styles for component-scoped rules."),
                        Step("App.globalStyles takes the same rules unscoped, registered once at mount."),
                        Step("media: and container: are mutually exclusive on one Rule — pick one.",
                             detail: "Passing both trips an assertion; a container rule also takes containerName:."),
                        Step("Combinators self-parenthesise here too, so a nested query survives the trip into CSS."),
                    ],
                    panel: .code(CodePanel(file: "Responsive.swift", code: rulesCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/Responsive.swift",
                                                           marker: "tour-responsive-rules")))),
        ],
        quiz: Quiz(questions: [
            Question(prompt: "An element declares .padding(responsive(.px(12), md: .px(24))) and, two lines later, .padding(.px(12)). What renders on a 1200px viewport?",
                     options: ["12px — the plain call becomes an inline style and out-specifies every breakpoint rule",
                               "24px — the md override is the more specific selector",
                               "24px — the responsive value is applied last and wins",
                               "A build error: one property cannot take both forms"],
                     correctIndex: 0,
                     explanation: "responsive() emits a base class rule plus @media overrides, while a plain modifier emits an inline style — and inline styles beat any class rule. Use one form per property per element."),
            Question(prompt: "A page is prerendered by SSG. Its component branches on media.matches(.up(.lg)). What is in the generated HTML?",
                     options: ["The else branch — with no live store, every query answers false",
                               "The .up(.lg) branch — SSG assumes a desktop viewport",
                               "Both branches, with CSS hiding the one that does not apply",
                               "Neither — the component is skipped until hydration"],
                     correctIndex: 0,
                     explanation: "MediaProxy has no MediaMatchStore during SSG or on a native build, so matches(_:) is false for every query and the wide branch only appears after hydration. That is the reason to keep \\.media for structural differences and use responsive()/.media() for styling."),
            Question(prompt: "In a release build a card calls .container(.up(.sm), name: \"gallery { }\") { … }. What is emitted?",
                     options: ["An unnamed @container rule — the invalid name is dropped, not repaired",
                               "@container gallery — the braces are stripped and the rest is kept",
                               "Nothing at all — the whole rule is discarded",
                               "The name verbatim; the check only runs in debug"],
                     correctIndex: 0,
                     explanation: "The name goes through isValidIdent and is dropped when it fails. Falling back to the unnamed @container form is the injection guard itself, so it applies in release as well as debug."),
        ]))
}
