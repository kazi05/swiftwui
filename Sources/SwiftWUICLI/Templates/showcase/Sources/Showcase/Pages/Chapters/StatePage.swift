// StatePage.swift — Chapter 2: State & Bindings

import SwiftWUI

public struct StatePage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 2 — Essentials",
                title: "State & Bindings",
                lead: "Reactive UIs update automatically when data changes. SwiftWUI uses @State to own mutable values inside a component, and @Binding to pass write access down to children without copying the data.",
                meta: [
                    ("Estimated time", "8 min"),
                    ("Difficulty", "Beginner"),
                    ("Module", "SwiftWUIState"),
                ]
            )
            ScrollyTeller(steps: stateSteps)
            ChapterFooter(prev: ("Hello, SwiftWUI", "/learn/hello"), next: ("Modifiers", "/learn/modifiers"))
            HighlightOnMount()
        }
    }

    private var stateSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Declare state with @State",
            prose: "Annotate a var with `@State` and SwiftWUI automatically stores it outside the struct so value-type copies all share the same backing storage. Any mutation triggers a re-render.",
            code: """
            struct Counter: Tag {
              @State var count = 0

              var body: some Tag {
                P { Text("Count: \\(count)") }
              }
            }
            """,
            preview: AnyTag(
                Div {
                    Span { Text("count = 0") }
                        .style("font-family", "var(--font-mono)")
                        .style("font-size", "14px")
                        .style("padding", "6px 12px")
                        .style("background", "var(--swui-surface-2)")
                        .style("border-radius", "6px")
                        .style("color", "var(--swui-fg)")
                }
            )
        ),
        .init(
            number: 2,
            title: "Mutate state in onclick",
            prose: "Wire a `Button` `onclick` closure that increments the state variable. SwiftWUI diffs the new virtual tree against the previous one and patches only the changed DOM text node.",
            code: """
            Button(onclick: { count += 1 }) {
              Text("Increment")
            }
            P { Text("Count: \\(count)") }
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Count: 7") }
                            .style("font-size", "20px")
                            .style("font-family", "var(--font-mono)")
                            .style("color", "var(--swui-fg)")
                        Div {
                            Span { Text("+ Increment") }
                                .style("background", "var(--swui-accent)")
                                .style("color", "#fff")
                                .style("padding", "6px 14px")
                                .style("border-radius", "6px")
                                .style("font-size", "13px")
                                .style("cursor", "pointer")
                        }
                        .style("margin-top", "10px")
                    }
                }
            )
        ),
        .init(
            number: 3,
            title: "Pass a Binding to a child",
            prose: "Prefix `$` on a `@State` property to obtain a `Binding`. Pass it to a child component. The child writes through the binding; the parent's state updates and the whole tree re-renders.",
            code: """
            struct Parent: Tag {
              @State var name = ""
              var body: some Tag {
                NameInput(text: $name)
                P { Text("Hello, \\(name)") }
              }
            }

            struct NameInput: Tag {
              let text: Binding<String>
              var body: some Tag {
                TextField("Name", text: text)
              }
            }
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Child writes via $name") }
                            .style("font-size", "12px")
                            .style("color", "var(--swui-fg-3)")
                        Div {
                            Span { Text("Hello, SwiftWUI") }
                                .style("font-size", "16px")
                                .style("color", "var(--swui-fg)")
                                .style("font-family", "var(--font-display)")
                        }
                        .style("margin-top", "8px")
                    }
                }
            )
        ),
        .init(
            number: 4,
            title: "Track dependencies with observe",
            prose: "The global `observe` helper records which `@State` values were read and re-runs the callback only when those values change — useful for derived computations outside a component body.",
            code: """
            let stop = observe {
              let doubled = counter.count * 2
              label.innerText = "x2 = \\(doubled)"
            }
            // call stop() to unsubscribe
            """,
            preview: AnyTag(
                Div {
                    Span { Text("observe { … } tracks only accessed state") }
                        .style("font-size", "12px")
                        .style("color", "var(--swui-fg-3)")
                        .style("font-family", "var(--font-mono)")
                    Div {
                        Span { Text("x2 = 14") }
                            .style("font-size", "18px")
                            .style("color", "var(--swui-accent)")
                            .style("font-family", "var(--font-mono)")
                    }
                    .style("margin-top", "8px")
                }
            )
        ),
    ] }
}
