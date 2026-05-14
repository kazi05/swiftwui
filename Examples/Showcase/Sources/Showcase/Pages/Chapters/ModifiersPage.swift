// ModifiersPage.swift — Chapter 3: Modifiers

import SwiftWUI

public struct ModifiersPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 3 — Essentials",
                title: "Modifiers",
                lead: "Modifiers are methods that return a new, wrapped tag with one property changed. Chain them fluently to build up styling, attributes, and behaviour — each call is a pure value transformation with no hidden mutation.",
                meta: [
                    ("Estimated time", "7 min"),
                    ("Difficulty", "Beginner"),
                    ("Module", "SwiftWUICore / SwiftWUIStyles"),
                ]
            )
            ScrollyTeller(steps: modifierSteps)
            ChapterFooter(prev: ("State & Bindings", "/learn/state"), next: ("Lists & ForEach", "/learn/lists"))
            HighlightOnMount()
        }
    }

    private var modifierSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Add padding with typed units",
            prose: "`.padding(.px(16))` is a typed modifier — it accepts a `LengthUnit` enum value so the compiler rejects bare strings. For spacing, prefer typed modifiers over raw CSS when they exist.",
            code: """
            Div { Text("Hello") }
              .padding(.px(16))
            """,
            preview: AnyTag(
                Div {
                    Div { Text("Hello") }
                        .padding(.px(16))
                        .backgroundColor(.token("swui-surface-2"))
                        .borderRadius(.px(6))
                        .display(.inlineBlock)
                        .foregroundColor(.token("swui-fg"))
                }
            )
        ),
        .init(
            number: 2,
            title: "Change font size fluently",
            prose: "`.fontSize(.px(20))` modifies the rendered font size. Because modifiers are pure value transformations, the original `Div` value is unchanged — you always get back a `ModifiedContent<Div, …>` wrapper.",
            code: """
            H2 { Text("Welcome") }
              .fontSize(.px(20))
              .style("color", "var(--swui-accent)")
            """,
            preview: AnyTag(
                H2 { Text("Welcome") }
                    .fontSize(.px(20))
                    .foregroundColor(.token("swui-accent"))
                    .style("margin", "0")
            )
        ),
        .init(
            number: 3,
            title: "Raw CSS with .style fallback",
            prose: "`.style(\"property\", \"value\")` is the escape hatch for any CSS not yet wrapped in a typed modifier. It takes two plain strings and sets the attribute directly on the element's inline style.",
            code: """
            Span { Text("Badge") }
              .style("background", "#0a84ff")
              .style("color", "#fff")
              .style("border-radius", "999px")
              .style("padding", "2px 10px")
            """,
            preview: AnyTag(
                Span { Text("Badge") }
                    .backgroundColor(.css("#0a84ff"))
                    .foregroundColor(.css("#fff"))
                    .borderRadius(.px(999))
                    .padding(.px(2), .px(10))
                    .fontSize(.px(12))
                    .fontWeight(.w600)
            )
        ),
        .init(
            number: 4,
            title: "Order matters: last call wins",
            prose: "If you call `.style(\"color\", \"red\")` and then `.style(\"color\", \"blue\")`, the rendered colour is blue. Modifiers compose left-to-right; each returns a new wrapped value that the next modifier sees.",
            code: """
            // Final colour is "blue" — last call wins.
            P { Text("Ordering demo") }
              .style("color", "red")
              .style("color", "blue")
            """,
            preview: AnyTag(
                P { Text("Ordering demo — last style wins") }
                    .foregroundColor(.css("red"))
                    .foregroundColor(.css("blue"))
                    .style("margin", "0")
                    .fontSize(.px(15))
            )
        ),
    ] }
}
