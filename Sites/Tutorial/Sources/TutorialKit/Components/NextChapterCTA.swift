import SwiftWUI

/// Next-chapter CTA — the largest surface in the site, so the largest radius.
/// `chapter` is the CURRENT page; the target comes from Curriculum.next(after:).
/// The last page wraps to the overview.
public struct NextChapterCTA: Tag {
    let chapter: Chapter
    public init(chapter: Chapter) { self.chapter = chapter }

    /// Curriculum position, two digits — the ghost numeral and the chapter bar
    /// count the same way. No `String(format:)`: it drags Foundation into wasm.
    private static func number(of chapter: Chapter) -> String? {
        guard let i = Curriculum.chapters.firstIndex(where: { $0.slug == chapter.slug }) else { return nil }
        return i + 1 < 10 ? "0\(i + 1)" : "\(i + 1)"
    }

    public var body: some Tag {
        if let next = Curriculum.next(after: chapter) {
            let wrapsToOverview = next.kind == .overview
            Div(class: "tut-cta") {
                Div(class: "tut-content") {
                    Div(class: "tut-cta-card") {
                        Div(class: "tut-cta-text") {
                            KickerRow(wrapsToOverview ? "explore more" : "next chapter")
                            H2(wrapsToOverview ? "Explore more tutorials" : next.title,
                               class: "tut-cta-title")
                            P(class: "tut-cta-tagline") { Text(next.tagline) }
                            Div(class: "tut-hero-actions") {
                                // ponytail: `Link` takes no `class`, so the button skin
                                // rides an inner span; the ring is re-declared here to
                                // land on the <a>, which is what actually takes focus.
                                // Delete both modifiers when Link gains a class.
                                Link(next.path) {
                                    Span(class: "tut-btn tut-btn-primary") {
                                        "Continue"
                                        Span(class: "tut-btn-arrow") { "→" }
                                    }
                                }
                                .display(.inlineFlex)
                                .borderRadius(.token(.r2))
                                .focusVisible { f in
                                    f.outlineWidth(.px(2)); f.outlineStyle(.solid)
                                    f.outlineColor(.token(.focus)); f.outlineOffset(.px(3))
                                }
                            }
                        }
                        if !wrapsToOverview, let num = Self.number(of: next) {
                            Span(class: "tut-cta-ghost-num") { Text(num) }
                        }
                    }
                }
            }
        }
    }
}
