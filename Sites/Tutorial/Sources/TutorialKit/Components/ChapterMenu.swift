import SwiftWUI

/// Chapter-menu overlay (Figma 10:26): all curriculum entries grouped by
/// track, current entry highlighted with an accent dot.
public struct ChapterMenu: Tag {
    let currentSlug: String
    public init(currentSlug: String) { self.currentSlug = currentSlug }

    // ponytail: StyleRegistry emits hash-ordered rules — tut-menu-item vs
    // tut-menu-item-active is a same-specificity override lottery on `color`.
    // Inline wins the cascade regardless of emission order.
    private func activeAware<T: HTMLTag>(_ tag: T, active: Bool) -> T {
        guard active else { return tag }
        return tag.style("background", "rgba(255,255,255,0.08)")
            .color(.token(.darkText))
            .fontWeight(.custom(600))
    }

    public var body: some Tag {
        ForEach(Track.allCases, id: \.rawValue) { track in
            Div(class: "tut-menu-group") {
                Span(class: "tut-menu-label") { Text(track.rawValue.uppercased()) }
                ForEach(Curriculum.chapters.filter { $0.track == track }, id: \.slug) { ch in
                    Link(ch.path) {
                        activeAware(Span(class: ch.slug == currentSlug
                             ? "tut-menu-item tut-menu-item-active"
                             : "tut-menu-item") {
                            if ch.slug == currentSlug {
                                Span(class: "tut-menu-dot")
                            }
                            Text(ch.title)
                        }, active: ch.slug == currentSlug)
                    }
                }
            }
        }
    }
}
