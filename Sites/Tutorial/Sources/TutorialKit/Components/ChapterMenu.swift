import SwiftWUI

/// Chapter-menu overlay (Figma 10:26): all 12 curriculum entries grouped by
/// track, current entry highlighted with an accent dot.
public struct ChapterMenu: Tag {
    let currentSlug: String
    public init(currentSlug: String) { self.currentSlug = currentSlug }

    public var body: some Tag {
        ForEach(Track.allCases, id: \.rawValue) { track in
            Div(class: "tut-menu-group") {
                Span(class: "tut-menu-label") { Text(track.rawValue.uppercased()) }
                ForEach(Curriculum.chapters.filter { $0.track == track }, id: \.slug) { ch in
                    Link(ch.path) {
                        Span(class: ch.slug == currentSlug
                             ? "tut-menu-item tut-menu-item-active"
                             : "tut-menu-item") {
                            if ch.slug == currentSlug {
                                Span(class: "tut-menu-dot")
                            }
                            Text(ch.title)
                        }
                    }
                }
            }
        }
    }
}
