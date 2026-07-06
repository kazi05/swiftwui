/// Chapter 6 — Style in Swift (Figma 11:26 + authored sections).
public enum Ch06 {
    static let bubbleCode = #"""
struct Bubble: Tag {
    var body: some Tag {
        P { "Knock, knock." }
            .padding(.px(12))
            .background(.hex("#F2F0EC"))
            .borderRadius(.px(10))
            .fontSize(.rem(1.1))
            .style("backdrop-filter", "blur(4px)")
    }
}
"""#

    // These are the marked regions of Samples/StyleBubble/Sources/main.swift
    // (Task 11 Step 1) — byte-identical incl. member indentation; ExcerptSyncTests
    // fails on any drift, including whitespace.
    static let rulesCode = #"""
    @RulesBuilder static var globalStyles: [Rule] {
        Rule(element: "body") { p in
            p.margin(.zero)
            p.background(.token(.stageBg))
            p.color(.token(.stageInk))
            p.fontFamily("system-ui, sans-serif")
        }
        Rule(class: "stage") { p in
            p.padding(.px(48))
            p.display(.flex); p.flexDirection(.column); p.gap(.px(16))
            p.alignItems(.flexStart)
        }
        Rule(class: "stage-toggle") { p in
            p.padding(vertical: .px(8), horizontal: .px(14))
            p.borderRadius(.px(8)); p.cursor(.pointer)
            p.hover { h in h.opacity(0.8) }
        }
    }
"""#
    static let themeCode = #"""
    static var themes: [ThemeDefinition] {
        [
            ThemeDefinition { t in                      // default → :root
                t.set(ColorToken.stageBg, .hex("#faf9f7"))
                t.set(ColorToken.stageInk, .hex("#1c1917"))
            },
            ThemeDefinition(name: "dark") { t in        // → [data-theme="dark"]
                t.set(ColorToken.stageBg, .hex("#17140f"))
                t.set(ColorToken.stageInk, .hex("#f5f1ea"))
            },
        ]
    }
"""#

    public static let chapter = Chapter(
        slug: "style-in-swift", track: .styles, kicker: "CHAPTER · STYLES",
        title: "Style in Swift",
        tagline: "Type-safe CSS modifiers cover the common cases; a raw string escape hatch covers the rest.",
        minutes: 20, kind: .chapter,
        sections: [
            Section(anchor: "modifiers", kicker: "01 · MODIFIERS",
                    title: "Style without leaving Swift",
                    intro: "Modifiers chain on any Tag and collapse into a single inline style.",
                    steps: [
                        Step("Chain type-safe modifiers on any Tag: .padding, .background, .borderRadius."),
                        Step("Values are typed — .px(12), .rem(1.1), .percent(50) — not strings."),
                        Step("Consecutive modifiers collapse into one style attribute — no wrapper soup."),
                        Step(".style(\"property\", \"value\") is the raw escape hatch when the DSL lacks a property."),
                    ],
                    panel: .code(CodePanel(file: "Bubble.swift", code: bubbleCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/StyleBubble/Sources/main.swift",
                                                           marker: "bubble")))),
            Section(anchor: "rules", kicker: "02 · RULES",
                    title: "Rule classes and stylesheets",
                    intro: "Shared styles belong in a real stylesheet, not on every node.",
                    steps: [
                        Step("Register document-level rules once via App.globalStyles."),
                        Step("Rule(class:) writes an actual stylesheet — inspect it in devtools."),
                        Step("Pseudo-selectors nest as blocks: hover { … }, focus { … }."),
                        Step("Media queries scope any rule: media(.maxWidth(.px(1080))) { … }."),
                    ],
                    panel: .code(CodePanel(file: "StyleBubble.swift", code: rulesCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/StyleBubble/Sources/main.swift",
                                                           marker: "bubble-rules")))),
            Section(anchor: "themes", kicker: "03 · THEMES",
                    title: "Design tokens and themes",
                    intro: "Tokens become CSS variables; themes swap them without re-rendering.",
                    steps: [
                        Step("Declare tokens as ColorToken statics; read them with .token(.stageInk).",
                             panel: .code(CodePanel(file: "StyleBubble.swift", code: themeCode,
                                                    origin: .sample(path: "Sites/Tutorial/Samples/StyleBubble/Sources/main.swift",
                                                                    marker: "bubble-theme")))),
                        Step("The default ThemeDefinition emits :root variables."),
                        Step("Named themes emit [data-theme=\"…\"] blocks — switching is one attribute write, zero re-render."),
                    ],
                    panel: .browser(url: "localhost:8080", screenshot: "screens/style-bubble.png")),
        ])
}
