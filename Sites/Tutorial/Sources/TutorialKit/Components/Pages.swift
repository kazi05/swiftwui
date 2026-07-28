import SwiftWUI

/// The two above-the-fold faces, preloaded on every page. Commit Mono is
/// deliberately absent: it is `display: swap` onto ui-monospace, metrically
/// close enough that the code panel does not reflow perceptibly.
private let fontPreloads: [LinkTag] = [
    .preload("/assets/fonts/InstrumentSans-Variable.woff2", as: .font, type: "font/woff2"),
    .preload("/assets/fonts/Literata-Variable.woff2", as: .font, type: "font/woff2"),
]

private let viewportMeta = MetaTag.viewport("width=device-width, initial-scale=1")

/// `// 04` — a card's number is its position in curriculum order; the overview
/// is not a chapter and is not counted.
private func chapterNumber(_ chapter: Chapter) -> String {
    let ordered = Curriculum.chapters.filter { $0.kind != .overview }
    return stepNumber(ordered.firstIndex { $0.slug == chapter.slug } ?? 0)
}

/// Landing page: simple hero + the curriculum grid, grouped by track.
public struct OverviewPage: Tag, Page {
    public init() {}
    public var title: String { "SwiftWUI Tutorials" }
    public var meta: [MetaTag] {
        [viewportMeta, .description("Learn SwiftWUI: build the web in pure Swift.")]
    }
    public var links: [LinkTag] { fontPreloads }

    public var body: some Tag {
        SiteNav()
        ChapterBar(chapter: Curriculum.overview)
        HeroView(chapter: Curriculum.overview)
        Main(class: "tut-content") {
            ForEach(Track.allCases, id: \.rawValue) { track in
                Div(class: "tut-track") {
                    Div(class: "tut-track-label") { KickerRow(track.rawValue) }
                    Div(class: "tut-cards") {
                        ForEach(Curriculum.chapters.filter { $0.track == track && $0.kind != .overview },
                                id: \.slug) { ch in
                            Link(ch.path) {
                                Span(class: "tut-card-link") {
                                    Span(class: "tut-card-kicker") {
                                        Span(class: "tut-kicker-slash") { "//" }
                                        Text(" \(chapterNumber(ch))")
                                    }
                                    // The card becomes the page: this id pairs
                                    // with the chapter hero's H1.
                                    Span(class: "tut-card-title") { Text(ch.title) }
                                        .matchedTransition(id: "ch-\(ch.slug)", duration: .ms(400),
                                                           timingFunction: TutorialMotion.ease,
                                                           contentFit: .cover)
                                    Span(class: "tut-card-tagline") { Text(ch.tagline) }
                                    // A <div> inside a <span> is invalid; the
                                    // spacer flex-grows just as well as a span.
                                    Span(class: "tut-card-spacer")
                                    Span(class: "tut-card-foot") {
                                        Span(class: "tut-card-minutes") { Text("\(ch.minutes) min") }
                                        Span(class: "tut-card-arrow") { "→" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        SiteFooter()
    }
}

/// Chapter page: hero, then one section per curriculum section, then quiz + CTA.
public struct ChapterPage: Tag, Page {
    let chapter: Chapter
    public init(chapter: Chapter) { self.chapter = chapter }
    public var title: String { "\(chapter.title) — SwiftWUI Tutorials" }
    public var meta: [MetaTag] { [viewportMeta, .description(chapter.tagline)] }
    public var links: [LinkTag] { fontPreloads }

    public var body: some Tag {
        SiteNav()
        ChapterBar(chapter: chapter)
        if let heroPanel = chapter.heroPanel {
            HeroView(chapter: chapter) { PanelView(panel: heroPanel) }
        } else {
            HeroView(chapter: chapter)
        }
        Main {
            ForEach(Array(chapter.sections.enumerated()), id: \.element.anchor) { item in
                SectionView(section: item.element, index: item.offset)
            }
        }
        if let quiz = chapter.quiz {
            QuizCard(quiz: quiz)
        }
        NextChapterCTA(chapter: chapter)
        SiteFooter()
    }
}

/// Wrap-up page: recap list + quiz + CTA. No sections, so no rail.
public struct WrapUpPage: Tag, Page {
    let chapter: Chapter
    public init(chapter: Chapter) { self.chapter = chapter }
    public var title: String { "\(chapter.title) — SwiftWUI Tutorials" }
    public var meta: [MetaTag] { [viewportMeta, .description(chapter.tagline)] }
    public var links: [LinkTag] { fontPreloads }

    public var body: some Tag {
        SiteNav()
        ChapterBar(chapter: chapter)
        HeroView(chapter: chapter)
        Main(class: "tut-content") {
            Div(class: "tut-section") {
                Div(class: "tut-section-header") { KickerRow("what you built") }
                Ul(class: "tut-recap") {
                    ForEach(Array((chapter.recap ?? []).enumerated()), id: \.offset) { item in
                        Li(class: "tut-recap-item") { Text(item.element) }
                    }
                }
            }
        }
        if let quiz = chapter.quiz {
            QuizCard(quiz: quiz)
        }
        NextChapterCTA(chapter: chapter)
        SiteFooter()
    }
}

/// 404 for unknown (and the overview's own) slugs under /tutorials/.
struct NotFoundPage: Tag, Page {
    var title: String { "Not found — SwiftWUI Tutorials" }
    var meta: [MetaTag] {
        [viewportMeta, .named("robots", content: "noindex"),
         .description("That chapter is not in the SwiftWUI curriculum.")]
    }
    var links: [LinkTag] { fontPreloads }

    var body: some Tag {
        SiteNav()
        Main(class: "tut-content") {
            Div(class: "tut-404") {
                Div {
                    // Bare kicker, not a kicker row: a hairline running to the
                    // container edge would fight the centred stage.
                    Span(class: "tut-kicker") {
                        Span(class: "tut-kicker-slash") { "//" }
                        Text(" 404")
                    }
                    H1("no such chapter.", class: "tut-404-title")
                    P(class: "tut-404-body") {
                        "That page is not in the curriculum. It may have moved, or the link may carry a typo."
                    }
                    // ponytail: one inline declaration — `.tut-hero-actions` is
                    // a flex row and flex ignores the stage's text-align.
                    Div(class: "tut-hero-actions") {
                        Link("/") {
                            Span(class: "tut-btn tut-btn-ghost") {
                                "Back to the overview"
                                Span(class: "tut-btn-arrow") { "→" }
                            }
                        }
                    }
                    .justifyContent(.center)
                }
            }
        }
        SiteFooter()
    }
}
