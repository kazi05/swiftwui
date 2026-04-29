// ListsPage.swift — Chapter 4: Lists & ForEach

import SwiftWUI

public struct ListsPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 4 — Building UI",
                title: "Lists & ForEach",
                lead: "ForEach turns any RandomAccessCollection of Identifiable items into a sequence of tags. The reconciler uses each element's stable id to diff, reorder, and patch the DOM surgically — no full rewrite on sort.",
                meta: [
                    ("Estimated time", "8 min"),
                    ("Difficulty", "Intermediate"),
                    ("Module", "SwiftWUICore"),
                ]
            )
            ScrollyTeller(steps: listSteps)
            ChapterFooter(prev: ("Modifiers", "/learn/modifiers"), next: ("Forms & Inputs", "/learn/forms"))
            HighlightOnMount()
        }
    }

    private var listSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Iterate an Identifiable collection",
            prose: "`ForEach` requires each element to conform to `Identifiable`. The framework stamps each rendered element with the item's `id` as a DOM key so it can match elements across renders.",
            code: """
            struct Fruit: Identifiable {
              let id: String
              let name: String
            }

            let fruits = [
              Fruit(id: "a", name: "Apple"),
              Fruit(id: "b", name: "Banana"),
            ]

            Ul {
              ForEach(fruits) { fruit in
                Li { Text(fruit.name) }
              }
            }
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Apple") }
                            .style("display", "block")
                            .style("padding", "6px 10px")
                            .style("border-bottom", "1px solid var(--swui-border)")
                            .style("font-size", "14px")
                            .style("color", "var(--swui-fg)")
                        Span { Text("Banana") }
                            .style("display", "block")
                            .style("padding", "6px 10px")
                            .style("font-size", "14px")
                            .style("color", "var(--swui-fg)")
                    }
                    .style("border", "1px solid var(--swui-border)")
                    .style("border-radius", "6px")
                    .style("overflow", "hidden")
                }
            )
        ),
        .init(
            number: 2,
            title: "Stable id enables keyed reorder",
            prose: "When you sort items, the reconciler matches existing DOM nodes by `id` and physically moves them rather than destroying and recreating. Animations, focus, and in-flight timers survive the reorder.",
            code: """
            // Before sort: [Apple(id:a), Banana(id:b), Cherry(id:c)]
            // After sort:  [Banana(id:b), Apple(id:a), Cherry(id:c)]
            //
            // DOM move: node(b) → position 0, node(a) → position 1
            items.sort { $0.name < $1.name }
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Banana  id=b  [moved, not recreated]") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("background", "var(--swui-surface-2)")
                            .style("font-size", "12px")
                            .style("font-family", "var(--font-mono)")
                            .style("color", "var(--swui-fg-2)")
                        Span { Text("Apple   id=a  [moved, not recreated]") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("font-size", "12px")
                            .style("font-family", "var(--font-mono)")
                            .style("color", "var(--swui-fg-2)")
                        Span { Text("Cherry  id=c  [unchanged]") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("background", "var(--swui-surface-2)")
                            .style("font-size", "12px")
                            .style("font-family", "var(--font-mono)")
                            .style("color", "var(--swui-fg-2)")
                    }
                    .style("border-radius", "6px")
                    .style("overflow", "hidden")
                }
            )
        ),
        .init(
            number: 3,
            title: "Conditional row rendering",
            prose: "Embed an `if` inside the `ForEach` closure to conditionally render rows. The `@TagBuilder` result builder translates `if/else` branches into a `ConditionalTag` that the reconciler handles gracefully.",
            code: """
            ForEach(items) { item in
              if item.isActive {
                Li { Text(item.name) }
                  .style("font-weight", "600")
              } else {
                Li { Text(item.name) }
                  .style("opacity", "0.4")
              }
            }
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Swift  (active)") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("font-weight", "600")
                            .style("font-size", "14px")
                            .style("color", "var(--swui-fg)")
                        Span { Text("Rust  (inactive)") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("opacity", "0.4")
                            .style("font-size", "14px")
                            .style("color", "var(--swui-fg)")
                        Span { Text("Go  (active)") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("font-weight", "600")
                            .style("font-size", "14px")
                            .style("color", "var(--swui-fg)")
                    }
                    .style("border", "1px solid var(--swui-border)")
                    .style("border-radius", "6px")
                    .style("overflow", "hidden")
                }
            )
        ),
        .init(
            number: 4,
            title: "Nested ForEach for grouped lists",
            prose: "Nest `ForEach` inside another to build grouped or sectioned lists. Each level gets its own stable key space, so the reconciler tracks items at every depth independently.",
            code: """
            ForEach(groups) { group in
              H3 { Text(group.title) }
              ForEach(group.items) { item in
                Li { Text(item.name) }
              }
            }
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Fruits") }
                            .style("display", "block")
                            .style("font-size", "11px")
                            .style("font-weight", "700")
                            .style("text-transform", "uppercase")
                            .style("letter-spacing", "0.06em")
                            .style("color", "var(--swui-fg-3)")
                            .style("padding", "6px 10px 2px")
                        Span { Text("Apple") }
                            .style("display", "block")
                            .style("padding", "3px 16px")
                            .style("font-size", "13px")
                            .style("color", "var(--swui-fg)")
                        Span { Text("Berries") }
                            .style("display", "block")
                            .style("font-size", "11px")
                            .style("font-weight", "700")
                            .style("text-transform", "uppercase")
                            .style("letter-spacing", "0.06em")
                            .style("color", "var(--swui-fg-3)")
                            .style("padding", "8px 10px 2px")
                        Span { Text("Blueberry") }
                            .style("display", "block")
                            .style("padding", "3px 16px")
                            .style("font-size", "13px")
                            .style("color", "var(--swui-fg)")
                    }
                    .style("border", "1px solid var(--swui-border)")
                    .style("border-radius", "6px")
                    .style("overflow", "hidden")
                }
            )
        ),
    ] }
}
