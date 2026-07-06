import SwiftWUI

/// Next-chapter CTA (Figma 9:43). `chapter` is the CURRENT page; the target
/// comes from Curriculum.next(after:). Last page wraps to the overview.
public struct NextChapterCTA: Tag {
    let chapter: Chapter
    public init(chapter: Chapter) { self.chapter = chapter }

    public var body: some Tag {
        if let next = Curriculum.next(after: chapter) {
            Div(class: "tut-cta") {
                Div(class: "tut-content") {
                    Div(class: "tut-cta-card") {
                        Div(class: "tut-cta-text") {
                            Span(class: "tut-kicker tut-kicker-dark") {
                                next.kind == .overview ? "EXPLORE MORE" : "NEXT CHAPTER"
                            }
                            .color(.token(.accentSoft))
                            H2(next.kind == .overview ? "Explore more tutorials" : next.title,
                               class: "tut-cta-title")
                            P(class: "tut-cta-tagline") { Text(next.tagline) }
                        }
                        Link(next.path) {
                            Span(class: "tut-btn-primary") { "Continue →" }
                        }
                    }
                }
            }
        }
    }
}
