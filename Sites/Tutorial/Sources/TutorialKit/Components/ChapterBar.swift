import SwiftWUI

/// The only sticky chrome (identity §2): series label, chapter progress meter,
/// chapter dropdown, Sections pill. Below md the series label and the pill are
/// display:none, so a 375px screen keeps the meter and the dropdown.
/// Both dropdowns are live @State; prerendered state = both closed.
public struct ChapterBar: Tag {
    let chapter: Chapter
    @State private var menuOpen = false
    @State private var sectionsOpen = false

    public init(chapter: Chapter) { self.chapter = chapter }

    /// Sheet enter/exit (identity, Motion surface A). The sheet is rendered
    /// only while open, so this is the state-diff the WAAPI engine plays.
    private static let sheet = AnyTransition.opacity
        .combined(with: .offset(x: 0, y: -8))
        .animation(.spring(duration: 0.34, bounce: 0.18))

    // Local rather than shared with StepList's `stepNumber`: 1-based here, and
    // no cross-file coupling for two characters of padding.
    private static func twoDigit(_ n: Int) -> String { (n < 10 ? "0" : "") + String(n) }

    public var body: some Tag {
        let total = Curriculum.chapters.count
        let index = Curriculum.chapters.firstIndex { $0.slug == chapter.slug }
        Div(class: "tut-chapterbar") {
            Div(class: "tut-content tut-chapterbar-inner") {
                Span(class: "tut-series") {
                    "SwiftWUI "
                    Span(class: "tut-series-accent") { "Tutorials" }
                }
                // the overview is chapters[0] but is not "chapter 1 of 19"
                if let index, chapter.kind != .overview {
                    Div(class: "tut-progress") {
                        Span(class: "tut-progress-label") {
                            Text("\(Self.twoDigit(index + 1)) / \(total)")
                        }
                        Div(class: "tut-progress-track") {
                            Div(class: "tut-progress-fill")
                                .width(.percent(Double(index + 1) / Double(total) * 100))
                        }
                    }
                    Span(class: "tut-divider")
                }
                Div(class: "tut-dropdown-wrap") {
                    Button(class: menuOpen ? "tut-dropdown tut-dropdown-open"
                                           : "tut-dropdown tut-dropdown-rest",
                           onClick: { menuOpen.toggle(); sectionsOpen = false }) {
                        Text(chapter.kind == .overview ? "All chapters" : chapter.title)
                        Span(class: "tut-chevron") { "▼" }
                            .rotationEffect(menuOpen ? 180 : 0)
                    }
                    .attribute("aria-haspopup", "true")
                    .attribute("aria-expanded", menuOpen ? "true" : "false")
                    if menuOpen {
                        Div(class: "tut-menu tut-menu-open") {
                            ChapterMenu(currentSlug: chapter.slug)
                        }
                        .transition(Self.sheet)
                    }
                }
                Div(class: "tut-spacer") {}
                if !chapter.sections.isEmpty {
                    Div(class: "tut-dropdown-wrap") {
                        Button(class: "tut-pill",
                               onClick: { sectionsOpen.toggle(); menuOpen = false }) {
                            Text("Sections")
                            Span(class: "tut-chevron") { "▼" }
                                .rotationEffect(sectionsOpen ? 180 : 0)
                        }
                        .attribute("aria-haspopup", "true")
                        .attribute("aria-expanded", sectionsOpen ? "true" : "false")
                        if sectionsOpen {
                            Div(class: "tut-menu tut-menu-open") {
                                ForEach(chapter.sections, id: \.anchor) { s in
                                    A(href: "#\(s.anchor)", class: "tut-menu-item tut-menu-item-rest") {
                                        Text(s.title)
                                    }
                                    .on(.click) { _ in sectionsOpen = false }
                                }
                            }
                            .transition(Self.sheet)
                        }
                    }
                }
            }
        }
        // routes share the /tutorials/:slug pattern, so @State survives
        // chapter-to-chapter navigation — force both dropdowns closed.
        .onChange(of: chapter.slug) { _, _ in menuOpen = false; sectionsOpen = false }
    }
}
