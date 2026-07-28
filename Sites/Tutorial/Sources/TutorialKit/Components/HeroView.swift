import SwiftWUI

/// The site's chrome, typeset as a Swift line comment: `// getting started · 25 min`
/// followed by a hairline that runs to the container edge. Used site-wide —
/// hero, section header, quiz header, chapter menu, overview track label.
///
/// The rule is a real `Div` because `::after` is unreachable in this DSL, and
/// it has to be a real element for the flex measurement anyway.
public struct KickerRow: Tag {
    let text: String
    public init(_ text: String) { self.text = text }

    public var body: some Tag {
        Div(class: "tut-kicker-row") {
            Span(class: "tut-kicker") {
                Span(class: "tut-kicker-slash") { "//" }
                Text(" \(text)")
            }
            Div(class: "tut-kicker-rule")
        }
    }
}

/// Chapter hero, on PAPER — never a dark band. Big variant: text column then
/// panel, which is the mobile reading order too (in the hero the title has to
/// land first, so the panel comes SECOND — the inverse of a section body).
/// Simple variant (wrap-up, overview): kicker + title + tagline, no grid.
public struct HeroView<PanelContent: Tag>: Tag {
    let chapter: Chapter
    let panelContent: PanelContent

    public init(chapter: Chapter, @TagBuilder panel: () -> PanelContent) {
        self.chapter = chapter
        self.panelContent = panel()
    }

    public var body: some Tag {
        let kicker = "\(chapter.kicker) · \(chapter.minutes) min"
        if chapter.heroPanel != nil {
            Header(class: "tut-hero") {
                Div(class: "tut-content") {
                    Div(class: "tut-hero-grid") {
                        Div(class: "tut-hero-text") {
                            KickerRow(kicker)
                            // The overview card's title carries the same id, so the
                            // card morphs into this H1 across the navigation.
                            H1(chapter.title, class: "tut-hero-title")
                                .matchedTransition(id: "ch-\(chapter.slug)", duration: .ms(400),
                                                   timingFunction: TutorialMotion.ease,
                                                   contentFit: .cover)
                            P(class: "tut-hero-tagline") { Text(chapter.tagline) }
                            if let heroBody = chapter.body {
                                P(class: "tut-hero-body") { Text(heroBody) }
                            }
                            Div(class: "tut-hero-actions") {
                                if let first = chapter.sections.first {
                                    A(href: "#\(first.anchor)", class: "tut-btn tut-btn-primary") {
                                        "Start the tutorial"
                                    }
                                }
                                A(href: SiteLinks.repo, class: "tut-btn tut-btn-ghost") { "View on GitHub" }
                            }
                        }
                        Div(class: "tut-hero-panel") { panelContent }
                    }
                }
            }
        } else {
            // `tut-hero-simple` is standalone, never paired with `tut-hero`: both
            // declare padding-block at the same specificity and media, and the
            // registry breaks that tie by hash.
            Header(class: "tut-hero-simple") {
                Div(class: "tut-content") {
                    KickerRow(kicker)
                    H1(chapter.title, class: "tut-hero-title-simple")
                        .matchedTransition(id: "ch-\(chapter.slug)", duration: .ms(400),
                                           timingFunction: TutorialMotion.ease,
                                           contentFit: .cover)
                    P(class: "tut-hero-tagline") { Text(chapter.tagline) }
                }
            }
        }
    }
}

extension HeroView where PanelContent == EmptyTag {
    public init(chapter: Chapter) { self.init(chapter: chapter) { EmptyTag() } }
}
