// ErrorsPage.swift — Chapter 10: Error Handling

import SwiftWUI

public struct ErrorsPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 10 — Production",
                title: "Error Handling",
                lead: "ErrorBoundary wraps a throwing content closure and shows a typed fallback tag when it throws. Combine it with a recovery handler to give users a clear path back from broken states.",
                meta: [
                    ("Estimated time", "8 min"),
                    ("Difficulty", "Intermediate"),
                    ("Module", "SwiftWUICore"),
                ]
            )
            ScrollyTeller(steps: errorSteps)
            ChapterFooter(prev: ("Accessibility", "/learn/a11y"), next: ("SSR & Hydration", "/learn/ssr"))
            HighlightOnMount()
        }
    }

    private var errorSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Wrap risky content in ErrorBoundary",
            prose: "`ErrorBoundary` takes a throwing `content` closure and a `fallback` closure that receives the caught `Error`. When `content()` throws, the fallback tag is rendered instead of leaving the UI blank.",
            code: """
            ErrorBoundary(fallback: { error in
              P { Text("Failed: \\(error.localizedDescription)") }
                .style("color", "#ff6b6b")
            }) {
              try buildDashboard(for: userID) // can throw
            }
            """,
            highlightLines: [1, 5],
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Fallback rendered") }
                            .fontSize(.px(11))
                            .foregroundColor(.token("swui-fg-3"))
                            .textTransform(.uppercase)
                            .letterSpacing(.em(0.06))
                        Div {
                            Span { Text("Failed: user not found") }
                                .fontSize(.px(14))
                                .foregroundColor(.css("#ff6b6b"))
                                .fontWeight(.w500)
                        }
                        .style("margin-top", "6px")
                    }
                    .padding(.px(10), .px(14))
                    .backgroundColor(.token("swui-surface-2"))
                    .border(.px(1), .solid, .css("#ff6b6b40"))
                    .borderRadius(.px(6))
                }
            )
        ),
        .init(
            number: 2,
            title: "Observe errors with onError callback",
            prose: "Pass an `onError` closure to `ErrorBoundary` to log or report caught errors. It runs before the fallback renders, so you can send the error to a monitoring service without changing the displayed UI.",
            code: """
            ErrorBoundary(
              fallback: { _ in ErrorCard() },
              onError: { err in Logger.report(err) }
            ) {
              try loadContent()
            }
            """,
            highlightLines: [3],
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("onError called first") }
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(12))
                            .foregroundColor(.token("swui-fg-3"))
                        Div {
                            Span { Text("Logger.report(error) → ✓") }
                                .fontFamily("var(--font-mono)")
                                .fontSize(.px(13))
                                .foregroundColor(.css("#30d158"))
                        }
                        .style("margin-top", "6px")
                        Div {
                            Span { Text("Fallback renders") }
                                .fontFamily("var(--font-mono)")
                                .fontSize(.px(13))
                                .foregroundColor(.token("swui-accent"))
                        }
                        .style("margin-top", "4px")
                    }
                    .padding(.px(10), .px(14))
                    .backgroundColor(.token("swui-surface-2"))
                    .borderRadius(.px(6))
                }
            )
        ),
        .init(
            number: 3,
            title: "Recover with a retry button",
            prose: "Store a `@State var retryCount` and increment it from the fallback button. Because `ErrorBoundary`'s parent re-renders with new state, the `content()` closure runs again — clearing the error if the condition resolved.",
            code: """
            @State var retryCount = 0

            ErrorBoundary(fallback: { error in
              Div {
                P { Text("Something went wrong.") }
                Button(onclick: { retryCount += 1 }) {
                  Text("Try again")
                }
              }
            }) {
              try loadContent(attempt: retryCount)
            }
            """,
            highlightLines: [1, 6],
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Something went wrong.") }
                            .fontSize(.px(14))
                            .foregroundColor(.token("swui-fg"))
                        Span { Text("Try again") }
                            .display(.inlineBlock)
                            .style("margin-top", "10px")
                            .backgroundColor(.token("swui-accent"))
                            .foregroundColor(.css("#fff"))
                            .padding(.px(6), .px(14))
                            .borderRadius(.px(6))
                            .fontSize(.px(13))
                            .cursor(.pointer)
                    }
                    .padding(.px(12), .px(16))
                    .backgroundColor(.token("swui-surface-2"))
                    .borderRadius(.px(6))
                }
            )
        ),
        .init(
            number: 4,
            title: "Nest boundaries for partial isolation",
            prose: "Nest multiple `ErrorBoundary` wrappers so one broken widget doesn't crash the whole page. The outermost boundary is your last resort; inner boundaries handle section-level failures with targeted messages.",
            code: """
            Main {
              ErrorBoundary(fallback: { _ in SidebarError() }) {
                try Sidebar(user: user)
              }
              ErrorBoundary(fallback: { _ in FeedError() }) {
                try NewsFeed(user: user)
              }
            }
            """,
            highlightLines: [2, 5],
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Sidebar: error isolated") }
                            .display(.block)
                            .padding(.px(5), .px(10))
                            .backgroundColor(.token("swui-surface-2"))
                            .borderLeft(width: .px(3), style: .solid, color: .css("#ff6b6b"))
                            .fontSize(.px(12))
                            .foregroundColor(.css("#ff6b6b"))
                        Span { Text("NewsFeed: renders normally") }
                            .display(.block)
                            .padding(.px(5), .px(10))
                            .borderLeft(width: .px(3), style: .solid, color: .css("#30d158"))
                            .fontSize(.px(12))
                            .foregroundColor(.css("#30d158"))
                    }
                    .border(.px(1), .solid, .token("swui-border"))
                    .borderRadius(.px(6))
                    .overflow(.hidden)
                }
            )
        ),
    ] }
}
