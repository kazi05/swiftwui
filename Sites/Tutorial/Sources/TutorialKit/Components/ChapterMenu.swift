import SwiftWUI

/// Contents of the chapter menu sheet: every curriculum entry grouped by
/// track, each group headed by a kicker row, the current chapter marked with
/// an accent dot and `aria-current`.
public struct ChapterMenu: Tag {
    let currentSlug: String
    public init(currentSlug: String) { self.currentSlug = currentSlug }

    public var body: some Tag {
        ForEach(Track.allCases, id: \.rawValue) { track in
            Div(class: "tut-menu-group") {
                Div(class: "tut-menu-label") {
                    Div(class: "tut-kicker-row") {
                        Span(class: "tut-kicker") {
                            Span(class: "tut-kicker-slash") { "//" }
                            Text(" " + track.rawValue)
                        }
                        Div(class: "tut-kicker-rule")
                    }
                }
                ForEach(Curriculum.chapters.filter { $0.track == track }, id: \.slug) { ch in
                    // ponytail: the class rides the inner Span because `Link`
                    // takes no class/attributes — so the focus ring never
                    // reaches the <a> that actually takes focus.
                    Link(ch.path) {
                        if ch.slug == currentSlug {
                            Span(class: "tut-menu-item tut-menu-item-active") {
                                Span(class: "tut-menu-dot")
                                Text(ch.title)
                            }
                            .attribute("aria-current", "page")
                        } else {
                            Span(class: "tut-menu-item tut-menu-item-rest") { Text(ch.title) }
                        }
                    }
                }
            }
        }
    }
}
