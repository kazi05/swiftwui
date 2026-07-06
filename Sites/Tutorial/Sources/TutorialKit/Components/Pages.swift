import SwiftWUI

/// Landing page (spec §3 overview pattern): hero + chapter cards by track.
public struct OverviewPage: Tag, Page {
    public init() {}
    public var title: String { "SwiftWUI Tutorials" }
    public var meta: [MetaTag] {
        [.viewport("width=device-width, initial-scale=1"),
         .description("Learn SwiftWUI: build the web in pure Swift.")]
    }

    public var body: some Tag {
        SiteNav()
        ChapterBar(chapter: Curriculum.overview)
        Header(class: "tut-hero") {
            Div(class: "tut-content tut-overview-hero") {
                Span(class: "tut-kicker tut-kicker-dark") { Text(Curriculum.overview.kicker) }
                    .color(.token(.accentSoft))
                H1(Curriculum.overview.title, class: "tut-hero-title-simple")
                P(class: "tut-hero-tagline") { Text(Curriculum.overview.tagline) }
            }
        }
        Main(class: "tut-content") {
            ForEach(Track.allCases, id: \.rawValue) { track in
                Div(class: "tut-track") {
                    Span(class: "tut-kicker tut-track-label") { Text(track.rawValue.uppercased()) }
                    Div(class: "tut-cards") {
                        ForEach(Curriculum.chapters.filter { $0.track == track && $0.kind != .overview },
                                id: \.slug) { ch in
                            Link(ch.path) {
                                Span(class: "tut-card-link") {
                                    Span(class: "tut-card-kicker") { Text(ch.kind == .wrapUp ? "WRAP-UP" : "CHAPTER") }
                                    Span(class: "tut-card-title") { Text(ch.title) }
                                    Span(class: "tut-card-tagline") { Text(ch.tagline) }
                                    Span(class: "tut-card-minutes") { Text("\(ch.minutes) MIN") }
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

/// Chapter page (Figma 1:2 / 11:26 pattern).
public struct ChapterPage: Tag, Page {
    let chapter: Chapter
    public init(chapter: Chapter) { self.chapter = chapter }
    public var title: String { "\(chapter.title) — SwiftWUI Tutorials" }
    public var meta: [MetaTag] {
        [.viewport("width=device-width, initial-scale=1"),
         .description(chapter.tagline)]
    }

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

/// Wrap-up page (spec §3): recap bullets + quiz + CTA. No sections.
public struct WrapUpPage: Tag, Page {
    let chapter: Chapter
    public init(chapter: Chapter) { self.chapter = chapter }
    public var title: String { "\(chapter.title) — SwiftWUI Tutorials" }
    public var meta: [MetaTag] {
        [.viewport("width=device-width, initial-scale=1"),
         .description(chapter.tagline)]
    }

    public var body: some Tag {
        SiteNav()
        ChapterBar(chapter: chapter)
        HeroView(chapter: chapter)
        Main(class: "tut-content") {
            Ul(class: "tut-recap") {
                ForEach(Array((chapter.recap ?? []).enumerated()), id: \.offset) { item in
                    Li(class: "tut-recap-item") { Text(item.element) }
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
    var body: some Tag {
        SiteNav()
        Main(class: "tut-content") {
            H1("404", class: "tut-hero-title")
            P { "No such tutorial. " }
            Link("/") { Span { "Back to the overview" } }
        }
        SiteFooter()
    }
}
