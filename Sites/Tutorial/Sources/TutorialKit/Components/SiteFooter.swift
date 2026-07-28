import SwiftWUI

/// Footer (identity §12): the nav's destinations plus the licence, nothing else.
public struct SiteFooter: Tag {
    public init() {}
    public var body: some Tag {
        Footer(class: "tut-footer") {
            Div(class: "tut-content tut-footer-inner") {
                Span(class: "tut-footer-brand") {
                    "SwiftWUI — Swift on the web, SwiftUI in spirit."
                }
                Div(class: "tut-footer-links") {
                    SiteLink("/", class: "tut-footer-link") { "Tutorials" }
                    A(href: SiteLinks.docs, class: "tut-footer-link") { "Docs" }
                    A(href: SiteLinks.examples, class: "tut-footer-link") { "Examples" }
                    A(href: SiteLinks.repo, class: "tut-footer-link") { "GitHub" }
                    A(href: SiteLinks.license, class: "tut-footer-link") { "MIT License" }
                }
            }
        }
    }
}
