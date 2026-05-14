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
                            .display(.block)
                            .padding(.px(6), .px(10))
                            .borderBottom(.px(1), .solid, .token("swui-border"))
                            .fontSize(.px(14))
                            .foregroundColor(.token("swui-fg"))
                        Span { Text("Banana") }
                            .display(.block)
                            .padding(.px(6), .px(10))
                            .fontSize(.px(14))
                            .foregroundColor(.token("swui-fg"))
                    }
                    .border(.px(1), .solid, .token("swui-border"))
                    .borderRadius(.px(6))
                    .overflow(.hidden)
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
                            .display(.block)
                            .padding(.px(5), .px(10))
                            .backgroundColor(.token("swui-surface-2"))
                            .fontSize(.px(12))
                            .fontFamily("var(--font-mono)")
                            .foregroundColor(.token("swui-fg-2"))
                        Span { Text("Apple   id=a  [moved, not recreated]") }
                            .display(.block)
                            .padding(.px(5), .px(10))
                            .fontSize(.px(12))
                            .fontFamily("var(--font-mono)")
                            .foregroundColor(.token("swui-fg-2"))
                        Span { Text("Cherry  id=c  [unchanged]") }
                            .display(.block)
                            .padding(.px(5), .px(10))
                            .backgroundColor(.token("swui-surface-2"))
                            .fontSize(.px(12))
                            .fontFamily("var(--font-mono)")
                            .foregroundColor(.token("swui-fg-2"))
                    }
                    .borderRadius(.px(6))
                    .overflow(.hidden)
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
                            .display(.block)
                            .padding(.px(5), .px(10))
                            .fontWeight(.w600)
                            .fontSize(.px(14))
                            .foregroundColor(.token("swui-fg"))
                        Span { Text("Rust  (inactive)") }
                            .display(.block)
                            .padding(.px(5), .px(10))
                            .style("opacity", "0.4")
                            .fontSize(.px(14))
                            .foregroundColor(.token("swui-fg"))
                        Span { Text("Go  (active)") }
                            .display(.block)
                            .padding(.px(5), .px(10))
                            .fontWeight(.w600)
                            .fontSize(.px(14))
                            .foregroundColor(.token("swui-fg"))
                    }
                    .border(.px(1), .solid, .token("swui-border"))
                    .borderRadius(.px(6))
                    .overflow(.hidden)
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
                            .display(.block)
                            .fontSize(.px(11))
                            .fontWeight(.w700)
                            .textTransform(.uppercase)
                            .letterSpacing(.em(0.06))
                            .foregroundColor(.token("swui-fg-3"))
                            .style("padding", "6px 10px 2px")
                        Span { Text("Apple") }
                            .display(.block)
                            .padding(.px(3), .px(16))
                            .fontSize(.px(13))
                            .foregroundColor(.token("swui-fg"))
                        Span { Text("Berries") }
                            .display(.block)
                            .fontSize(.px(11))
                            .fontWeight(.w700)
                            .textTransform(.uppercase)
                            .letterSpacing(.em(0.06))
                            .foregroundColor(.token("swui-fg-3"))
                            .style("padding", "8px 10px 2px")
                        Span { Text("Blueberry") }
                            .display(.block)
                            .padding(.px(3), .px(16))
                            .fontSize(.px(13))
                            .foregroundColor(.token("swui-fg"))
                    }
                    .border(.px(1), .solid, .token("swui-border"))
                    .borderRadius(.px(6))
                    .overflow(.hidden)
                }
            )
        ),
    ] }
}
