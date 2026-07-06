import SwiftWUI

/// Footer (Figma 9:53).
public struct SiteFooter: Tag {
    public init() {}
    public var body: some Tag {
        Footer(class: "tut-footer") {
            Div(class: "tut-content tut-footer-inner") {
                Span { "SwiftWUI — Swift on the web, SwiftUI in spirit." }
                Div(class: "tut-footer-links") {
                    A(href: SiteLinks.docs) { "Docs" }
                    A(href: SiteLinks.repo) { "GitHub" }
                    A(href: SiteLinks.repo + "/blob/main/LICENSE") { "MIT License" }
                }
            }
        }
    }
}
