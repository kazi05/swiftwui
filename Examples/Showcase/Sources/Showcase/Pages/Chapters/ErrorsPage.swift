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
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Fallback rendered") }
                            .style("font-size", "11px")
                            .style("color", "var(--swui-fg-3)")
                            .style("text-transform", "uppercase")
                            .style("letter-spacing", "0.06em")
                        Div {
                            Span { Text("Failed: user not found") }
                                .style("font-size", "14px")
                                .style("color", "#ff6b6b")
                                .style("font-weight", "500")
                        }
                        .style("margin-top", "6px")
                    }
                    .style("padding", "10px 14px")
                    .style("background", "var(--swui-surface-2)")
                    .style("border", "1px solid #ff6b6b40")
                    .style("border-radius", "6px")
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
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("onError called first") }
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "12px")
                            .style("color", "var(--swui-fg-3)")
                        Div {
                            Span { Text("Logger.report(error) → ✓") }
                                .style("font-family", "var(--font-mono)")
                                .style("font-size", "13px")
                                .style("color", "#30d158")
                        }
                        .style("margin-top", "6px")
                        Div {
                            Span { Text("Fallback renders") }
                                .style("font-family", "var(--font-mono)")
                                .style("font-size", "13px")
                                .style("color", "var(--swui-accent)")
                        }
                        .style("margin-top", "4px")
                    }
                    .style("padding", "10px 14px")
                    .style("background", "var(--swui-surface-2)")
                    .style("border-radius", "6px")
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
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Something went wrong.") }
                            .style("font-size", "14px")
                            .style("color", "var(--swui-fg)")
                        Span { Text("Try again") }
                            .style("display", "inline-block")
                            .style("margin-top", "10px")
                            .style("background", "var(--swui-accent)")
                            .style("color", "#fff")
                            .style("padding", "6px 14px")
                            .style("border-radius", "6px")
                            .style("font-size", "13px")
                            .style("cursor", "pointer")
                    }
                    .style("padding", "12px 16px")
                    .style("background", "var(--swui-surface-2)")
                    .style("border-radius", "6px")
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
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Sidebar: error isolated") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("background", "var(--swui-surface-2)")
                            .style("border-left", "3px solid #ff6b6b")
                            .style("font-size", "12px")
                            .style("color", "#ff6b6b")
                        Span { Text("NewsFeed: renders normally") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("border-left", "3px solid #30d158")
                            .style("font-size", "12px")
                            .style("color", "#30d158")
                    }
                    .style("border", "1px solid var(--swui-border)")
                    .style("border-radius", "6px")
                    .style("overflow", "hidden")
                }
            )
        ),
    ] }
}
