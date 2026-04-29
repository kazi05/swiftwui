// RoutingPage.swift — Chapter 6: Routing & Guards

import SwiftWUI

public struct RoutingPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 6 — Building UI",
                title: "Routing & Guards",
                lead: "SwiftWUI's router matches URL patterns, extracts named parameters, and evaluates guard closures before rendering a page. One RouteGuardResult enum drives both allow and redirect outcomes.",
                meta: [
                    ("Estimated time", "10 min"),
                    ("Difficulty", "Intermediate"),
                    ("Module", "SwiftWUIRouter"),
                ]
            )
            ScrollyTeller(steps: routingSteps)
            ChapterFooter(prev: ("Forms & Inputs", "/learn/forms"), next: ("Async & Resources", "/learn/async"))
            HighlightOnMount()
        }
    }

    private var routingSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Declare routes in Application",
            prose: "Pass an array of `Route` values to `Application`. The router matches the current URL path in order and renders the first matching route's tag. Non-matching routes are simply skipped.",
            code: """
            let app = Application {
              Route("/")       { HomePage() }
              Route("/about")  { AboutPage() }
              Route("/users")  { UsersPage() }
            }
            app.mount()
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("GET /about  → AboutPage rendered") }
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "12px")
                            .style("color", "var(--swui-accent)")
                    }
                    .style("padding", "10px 14px")
                    .style("background", "var(--swui-surface-2)")
                    .style("border-radius", "6px")
                }
            )
        ),
        .init(
            number: 2,
            title: "Extract named URL parameters",
            prose: "Prefix a path segment with `:` to make it a named parameter. The router extracts it into a `[String: String]` dictionary passed to your tag closure so you can fetch or display entity-specific content.",
            code: """
            Route("/users/:id") { params in
              let uid = params["id"] ?? "unknown"
              return UserDetailPage(userID: uid)
            }
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("URL: /users/42") }
                            .style("font-size", "12px")
                            .style("color", "var(--swui-fg-3)")
                            .style("font-family", "var(--font-mono)")
                        Span { Text("params[\"id\"] = \"42\"") }
                            .style("display", "block")
                            .style("font-size", "14px")
                            .style("color", "var(--swui-accent)")
                            .style("font-family", "var(--font-mono)")
                            .style("margin-top", "6px")
                    }
                    .style("padding", "10px 14px")
                    .style("background", "var(--swui-surface-2)")
                    .style("border-radius", "6px")
                }
            )
        ),
        .init(
            number: 3,
            title: "Gate access with RouteGuard",
            prose: "Pass a `guard:` closure to `Route`. It is called before the route matches and must return a `RouteGuardResult`. Return `.allow` to proceed or `.redirect(\"/login\")` to send the user elsewhere.",
            code: """
            Route("/admin",
              guard: { auth.isAdmin ? .allow : .redirect("/login") }
            ) {
              AdminDashboard()
            }
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("isAdmin = false") }
                            .style("font-size", "12px")
                            .style("color", "var(--swui-fg-3)")
                            .style("font-family", "var(--font-mono)")
                        Span { Text(".redirect(\"/login\")") }
                            .style("display", "block")
                            .style("font-size", "14px")
                            .style("color", "#ff6b6b")
                            .style("font-family", "var(--font-mono)")
                            .style("margin-top", "6px")
                    }
                    .style("padding", "10px 14px")
                    .style("background", "var(--swui-surface-2)")
                    .style("border-radius", "6px")
                }
            )
        ),
        .init(
            number: 4,
            title: "Understand RouteGuardResult",
            prose: "The `RouteGuardResult` enum has two cases: `.allow` lets the route render normally, and `.redirect(_:)` with an associated path string tells the runtime to navigate to a different route instead.",
            code: """
            public enum RouteGuardResult: Sendable {
              case allow
              case redirect(String)
            }

            // Usage:
            guard: { isLoggedIn ? .allow : .redirect("/login") }
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text(".allow") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("color", "#30d158")
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "14px")
                        Span { Text(".redirect(\"/login\")") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("color", "#ff6b6b")
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "14px")
                    }
                    .style("border", "1px solid var(--swui-border)")
                    .style("border-radius", "6px")
                    .style("overflow", "hidden")
                }
            )
        ),
        .init(
            number: 5,
            title: "Navigate programmatically",
            prose: "Call `Router.shared.navigate(to:)` from any event handler to push a new path onto the history stack. The router resolves the new path, evaluates guards, and renders the matching route tag.",
            code: """
            Button(onclick: {
              Router.shared.navigate(to: "/dashboard")
            }) {
              Text("Go to Dashboard")
            }
            """,
            preview: AnyTag(
                Div {
                    Span { Text("Go to Dashboard") }
                        .style("display", "inline-block")
                        .style("background", "var(--swui-accent)")
                        .style("color", "#fff")
                        .style("padding", "7px 16px")
                        .style("border-radius", "6px")
                        .style("font-size", "13px")
                        .style("cursor", "pointer")
                    Div {
                        Span { Text("→ navigate(\"/dashboard\")") }
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "12px")
                            .style("color", "var(--swui-fg-3)")
                    }
                    .style("margin-top", "8px")
                }
            )
        ),
    ] }
}
