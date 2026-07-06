import SwiftWUI

/// Dark bar under the nav (Figma 7:26): series label, chapter dropdown
/// (opens the ChapterMenu overlay), section dropdown (in-page anchors).
/// Both dropdowns are live @State; prerendered state = both closed (spec §11).
public struct ChapterBar: Tag {
    let chapter: Chapter
    @State private var menuOpen = false
    @State private var sectionsOpen = false

    public init(chapter: Chapter) { self.chapter = chapter }

    public var body: some Tag {
        Div(class: "tut-chapterbar") {
            Div(class: "tut-content tut-chapterbar-inner") {
                Span(class: "tut-series") {
                    "SwiftWUI "
                    Span(class: "tut-series-accent") { "Tutorials" }
                }
                Span(class: "tut-divider")
                Div(class: "tut-dropdown-wrap") {
                    Button(class: "tut-dropdown", onClick: { menuOpen.toggle(); sectionsOpen = false }) {
                        Text(chapter.kind == .overview ? "All chapters" : chapter.title)
                        Text(" ▾")
                    }
                    Div(class: menuOpen ? "tut-menu tut-menu-open" : "tut-menu") {
                        ChapterMenu(currentSlug: chapter.slug)
                    }
                    .display(menuOpen ? .block : .none)
                }
                Div(class: "tut-spacer") {}
                if !chapter.sections.isEmpty {
                    Div(class: "tut-dropdown-wrap") {
                        Button(class: "tut-pill", onClick: { sectionsOpen.toggle(); menuOpen = false }) {
                            Text("Sections ▾")
                        }
                        Div(class: sectionsOpen ? "tut-menu tut-menu-open" : "tut-menu") {
                            ForEach(chapter.sections, id: \.anchor) { s in
                                A(href: "#\(s.anchor)", class: "tut-menu-item") { Text(s.title) }
                                    .on(.click) { _ in sectionsOpen = false }
                            }
                        }
                        .display(sectionsOpen ? .block : .none)
                    }
                }
            }
        }
        // routes share the /tutorials/:slug pattern, so @State survives
        // chapter-to-chapter navigation — force both dropdowns closed.
        .onChange(of: chapter.slug) { _, _ in menuOpen = false; sectionsOpen = false }
    }
}
