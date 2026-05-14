// AsyncPage.swift — Chapter 7: Async & Resources

import SwiftWUI

public struct AsyncPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 7 — Building UI",
                title: "Async & Resources",
                lead: "Async/await in SwiftWUI runs inside structured task scopes attached to tags. Use the .task modifier to kick off work when a component appears, and drive loading and error UI entirely through @State.",
                meta: [
                    ("Estimated time", "9 min"),
                    ("Difficulty", "Intermediate"),
                    ("Module", "SwiftWUICore"),
                ]
            )
            ScrollyTeller(steps: asyncSteps)
            ChapterFooter(prev: ("Routing & Guards", "/learn/routing"), next: ("Theming", "/learn/theming"))
            HighlightOnMount()
        }
    }

    private var asyncSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Start a task with .task modifier",
            prose: "`.task { … }` attaches a structured `Task` to the tag's lifetime. The closure is `@Sendable` and runs on the cooperative thread pool. The task is cancelled automatically when the tag leaves the tree.",
            code: """
            struct ItemList: Tag {
              @State var items: [Item] = []

              var body: some Tag {
                Div { /* render items */ }
                  .task { @Sendable in
                    items = await ItemAPI.fetchAll()
                  }
              }
            }
            """,
            highlightLines: [6, 7],
            preview: .live(AnyTag(
                Div {
                    Span { Text(".task fires on mount") }
                        .fontSize(.px(12))
                        .foregroundColor(.token("swui-fg-3"))
                    Div {
                        Span { Text("Fetching…") }
                            .fontSize(.px(14))
                            .foregroundColor(.token("swui-accent"))
                            .fontFamily("var(--font-mono)")
                    }
                    .style("margin-top", "8px")
                    .padding(.px(8), .px(12))
                    .backgroundColor(.token("swui-surface-2"))
                    .borderRadius(.px(6))
                }
            ))
        ),
        .init(
            number: 2,
            title: "Show a loading spinner via @State",
            prose: "Declare `@State var loading = true`. Set it to `false` inside `.task` after the fetch completes. SwiftWUI re-renders once; the spinner branch disappears and the content branch appears.",
            code: """
            @State var items: [Item] = []
            @State var loading = true

            var body: some Tag {
              if loading {
                Div { Text("Loading…") }
              } else {
                ForEach(items) { item in Li { Text(item.name) } }
              }
            }
            """,
            highlightLines: [2, 5],
            preview: .live(AnyTag(
                Div {
                    Div {
                        Span { Text("loading = true") }
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(12))
                            .foregroundColor(.token("swui-fg-3"))
                        Div {
                            Div { EmptyTag() }
                                .style("width", "20px")
                                .style("height", "20px")
                                .border(.px(3), .solid, .token("swui-border"))
                                .style("border-top-color", "var(--swui-accent)")
                                .borderRadius(.percent(50))
                            Span { Text("Loading…") }
                                .fontSize(.px(14))
                                .foregroundColor(.token("swui-fg-2"))
                                .style("margin-left", "10px")
                        }
                        .display(.flex)
                        .alignItems(.center)
                        .style("margin-top", "8px")
                    }
                }
            ))
        ),
        .init(
            number: 3,
            title: "Capture errors in @State",
            prose: "Wrap the async work in `do/catch`. Store errors as `@State var error: Error?`. Render a friendly message when `error != nil`, with a retry button that resets the error and retriggers the task.",
            code: """
            @State var error: Error? = nil

            var body: some Tag {
              if let error {
                P { Text("Error: \\(error.localizedDescription)") }
                Button(onclick: { self.error = nil }) {
                  Text("Retry")
                }
              } else { /* content */ }
            }
            """,
            highlightLines: [1, 4],
            preview: .live(AnyTag(
                Div {
                    Div {
                        Span { Text("Network error: timeout") }
                            .fontSize(.px(14))
                            .foregroundColor(.css("#ff6b6b"))
                        Span { Text("Retry") }
                            .display(.inlineBlock)
                            .style("margin-top", "8px")
                            .backgroundColor(.token("swui-accent"))
                            .foregroundColor(.css("#fff"))
                            .padding(.px(5), .px(12))
                            .borderRadius(.px(5))
                            .fontSize(.px(12))
                            .cursor(.pointer)
                    }
                    .padding(.px(10), .px(14))
                    .backgroundColor(.token("swui-surface-2"))
                    .borderRadius(.px(6))
                }
            ))
        ),
        .init(
            number: 4,
            title: "Run parallel tasks with TaskGroup",
            prose: "Inside a `.task` closure you can use Swift's `withTaskGroup` to fan out multiple async operations in parallel and collect their results, all within a single structured concurrency scope.",
            code: """
            .task { @Sendable in
              await withTaskGroup(of: Item?.self) { group in
                for id in ids {
                  group.addTask { try? await API.fetch(id) }
                }
                for await item in group {
                  if let item { items.append(item) }
                }
              }
              loading = false
            }
            """,
            highlightLines: [2, 4],
            preview: .live(AnyTag(
                Div {
                    Span { Text("Parallel fetch — 3 tasks") }
                        .fontSize(.px(12))
                        .foregroundColor(.token("swui-fg-3"))
                    Div {
                        Span { Text("id=1  done") }
                            .display(.block)
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(12))
                            .foregroundColor(.css("#30d158"))
                        Span { Text("id=2  done") }
                            .display(.block)
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(12))
                            .foregroundColor(.css("#30d158"))
                        Span { Text("id=3  pending…") }
                            .display(.block)
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(12))
                            .foregroundColor(.token("swui-fg-3"))
                    }
                    .style("margin-top", "8px")
                    .padding(.px(8), .px(12))
                    .backgroundColor(.token("swui-surface-2"))
                    .borderRadius(.px(6))
                }
            ))
        ),
    ] }
}
