import SwiftWUI

/// Chapter hero. Big variant (Figma 3:15): text + actions left, panel right.
/// Simple variant (Figma 11:51): kicker + title + tagline, no grid.
public struct HeroView<PanelContent: Tag>: Tag {
    let chapter: Chapter
    let panelContent: PanelContent

    public init(chapter: Chapter, @TagBuilder panel: () -> PanelContent) {
        self.chapter = chapter
        self.panelContent = panel()
    }

    public var body: some Tag {
        Header(class: "tut-hero") {
            Div(class: "tut-content") {
                if chapter.heroPanel != nil {
                    Div(class: "tut-hero-grid") {
                        Div(class: "tut-hero-text") {
                            Span(class: "tut-kicker tut-kicker-dark") {
                                "\(chapter.kicker) · \(chapter.minutes) MIN"
                            }
                            .color(.token(.accentSoft))
                            H1(chapter.title, class: "tut-hero-title")
                            P(class: "tut-hero-tagline") { Text(chapter.tagline) }
                            if let heroBody = chapter.body {
                                P(class: "tut-hero-body") { Text(heroBody) }
                            }
                            Div(class: "tut-hero-actions") {
                                if let first = chapter.sections.first {
                                    A(href: "#\(first.anchor)", class: "tut-btn-primary") { "Start the tutorial" }
                                }
                                A(href: SiteLinks.repo, class: "tut-btn-ghost") { "View on GitHub" }
                            }
                        }
                        panelContent
                    }
                } else {
                    Div(class: "tut-hero-simple") {
                        Span(class: "tut-kicker tut-kicker-dark") { Text(chapter.kicker) }
                            .color(.token(.accentSoft))
                        H1(chapter.title, class: "tut-hero-title-simple")
                        P(class: "tut-hero-tagline") { Text(chapter.tagline) }
                    }
                }
            }
        }
    }
}

extension HeroView where PanelContent == EmptyTag {
    public init(chapter: Chapter) { self.init(chapter: chapter) { EmptyTag() } }
}
