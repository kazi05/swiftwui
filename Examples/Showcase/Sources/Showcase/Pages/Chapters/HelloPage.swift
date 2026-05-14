// HelloPage.swift — Chapter 1: Hello, SwiftWUI.
//
// This is the canonical chapter shape. Tasks 4.3-4.13 mirror its
// structure exactly, varying only the ChapterIntro text, the steps
// array, and the prev/next ChapterFooter values.

import SwiftWUI

public struct HelloPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 1 — Essentials",
                title: "Hello, SwiftWUI",
                lead: "Build your first declarative view by conforming a struct to Tag and returning a body. By the end of this chapter you will mount a real SwiftWUI app on a DOM element and render styled HTML.",
                meta: [
                    ("Estimated time", "5 min"),
                    ("Difficulty", "Beginner"),
                    ("Module", "SwiftWUICore"),
                ]
            )
            ScrollyTeller(steps: helloSteps)
            ChapterFooter(prev: nil, next: ("State & Bindings", "/learn/state"))
            HighlightOnMount()
        }
    }

    private var helloSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Conform a struct to Tag",
            prose: "Every SwiftWUI view starts the same way — declare a struct, conform to Tag, and define a body that returns more Tags.",
            code: """
            struct Greeting: Tag {
              var body: some Tag {
                H1 { Text("Hello, SwiftWUI") }
              }
            }
            """,
            highlightLines: [1, 2],
            preview: .live(AnyTag(
                Div {
                    H1 { Text("Hello, SwiftWUI") }
                        .fontFamily("var(--font-display)")
                        .style("margin", "0")
                }
            ))
        ),
        .init(
            number: 2,
            title: "Compose with @TagBuilder",
            prose: "The @TagBuilder result builder lets you write a list of children directly inside the body without commas or arrays.",
            code: """
            var body: some Tag {
              Div {
                H1 { Text("Hello") }
                P  { Text("Welcome.") }
              }
            }
            """,
            highlightLines: [2, 3, 4],
            preview: .live(AnyTag(
                Div {
                    H1 { Text("Hello") }
                        .fontFamily("var(--font-display)")
                        .style("margin", "0")
                    P { Text("Welcome.") }
                        .foregroundColor(.token("swui-fg-2"))
                        .style("margin", "8px 0 0")
                }
            ))
        ),
        .init(
            number: 3,
            title: "Mount on a DOM element",
            prose: "Application { … } collects routes, then mount() boots the runtime and renders into an element by id.",
            code: """
            let app = Application(page: { Greeting() })
            app.mount()
            """,
            highlightLines: [2],
            // Demo: opts into PreviewKind.screenshot. The PNG itself is generated
            // by `make showcase-snapshots` against a running dev server (requires
            // SwiftWasm SDK) and committed selectively. Until then the Img path
            // resolves to a 404; the wiring is intentionally complete so the
            // first author with an SDK can commit the PNG and immediately ship.
            preview: .screenshot("hello-step-3.png")
        ),
        .init(
            number: 4,
            title: "Style with chained modifiers",
            prose: "Add style by chaining modifiers. They are type-safe; raw CSS escape hatches via .style() when no typed modifier exists yet.",
            code: """
            H1 { Text("Hello") }
              .style("font-size", "28px")
              .style("padding", "16px")
              .style("color", "var(--swui-accent)")
            """,
            highlightLines: [2, 3, 4],
            preview: .live(AnyTag(
                H1 { Text("Hello") }
                    .fontSize(.px(28))
                    .padding(.px(16))
                    .foregroundColor(.token("swui-accent"))
                    .style("margin", "0")
            ))
        ),
    ] }
}
