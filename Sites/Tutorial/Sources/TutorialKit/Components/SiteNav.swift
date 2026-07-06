import SwiftWUI

public enum SiteLinks {
    public static let repo = "https://github.com/kazimgadzhiev/SwiftWUI"
    public static let docs = repo + "/tree/main/docs"
    public static let examples = repo + "/tree/main/Examples"
}

/// Top navigation (Figma 3:2): light bar, brand left, links right.
public struct SiteNav: Tag {
    public init() {}
    public var body: some Tag {
        Nav(class: "tut-nav") {
            Div(class: "tut-content tut-nav-inner") {
                Link("/") {
                    Span(class: "tut-brand") { "SwiftWUI" }
                }
                Div(class: "tut-nav-links") {
                    A(href: SiteLinks.docs) { "Docs" }
                    Link("/") { Span { "Tutorials" } }
                    A(href: SiteLinks.examples) { "Examples" }
                    A(href: SiteLinks.repo) { "GitHub" }
                }
            }
        }
    }
}
