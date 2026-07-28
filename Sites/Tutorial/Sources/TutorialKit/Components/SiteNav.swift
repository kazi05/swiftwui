import SwiftWUI

public enum SiteLinks {
    public static let repo = "https://github.com/kazi05/swiftwui"
    public static let docs = repo + "/tree/main/docs"
    public static let examples = repo + "/tree/main/Examples"
    public static let license = repo + "/blob/main/LICENSE"
}

/// SPA anchor that also carries a class and `aria-current`. `Link` takes
/// neither, and both the focus ring and the current-page marker have to sit on
/// the `<a>` itself — so this reproduces `Link`'s internal branch
/// (`data-swui-link` + an unmodified-click guard) over a plain `A`.
struct SiteLink<Content: Tag>: Tag {
    @Environment(\.navigate) private var navigate
    @Environment(\.routeInfo) private var routeInfo

    let path: String
    let classes: String
    let marksCurrent: Bool
    let content: Content

    init(_ path: String, class classes: String, marksCurrent: Bool = true,
         @TagBuilder content: () -> Content) {
        self.path = path
        self.classes = classes
        self.marksCurrent = marksCurrent
        self.content = content()
    }

    var body: some Tag {
        let dest = path
        let nav = navigate
        return A(href: dest, class: classes) { content }
            .attribute("data-swui-link", "")
            .attribute("aria-current", marksCurrent ? current : nil)
            .onTap { e in
                guard !e.isModified else { return }   // cmd-click etc: let the browser have it
                nav(dest)
            }
    }

    private var current: String? {
        let here = routeInfo.path
        if here == path { return "page" }
        // A chapter page is still inside the section the "/" link names.
        return path == "/" && here.hasPrefix("/tutorials/") ? "true" : nil
    }
}

/// Site nav (identity §1): no hamburger, no JS, no overlay. Below md the inner
/// row wraps — brand + toggle on row 1, the scrollable link row on row 2; at md
/// it is a single 64px row.
public struct SiteNav: Tag {
    public init() {}
    public var body: some Tag {
        Nav(class: "tut-nav") {
            Div(class: "tut-content tut-nav-inner") {
                SiteLink("/", class: "tut-brand", marksCurrent: false) {
                    "SwiftWUI"
                    Span(class: "tut-brand-path") { "/tutorials" }
                }
                Div(class: "tut-nav-links") {
                    SiteLink("/", class: "tut-nav-link") { "Tutorials" }
                    A(href: SiteLinks.docs, class: "tut-nav-link") { "Docs" }
                    A(href: SiteLinks.examples, class: "tut-nav-link") { "Examples" }
                    A(href: SiteLinks.repo, class: "tut-nav-link") { "GitHub" }
                }
                ThemeToggle()
            }
        }
    }
}
