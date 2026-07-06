import Testing
import SwiftWUI
@testable import TutorialKit

@Suite @MainActor struct ChromeComponentTests {
    @Test func navRendersBrandAndLinks() {
        let html = HTMLRenderer.render(SiteNav())
        #expect(html.contains("SwiftWUI"))
        for label in ["Docs", "Tutorials", "Examples", "GitHub"] { #expect(html.contains(label)) }
        #expect(html.contains(SiteLinks.repo))
        #expect(html.contains("data-swui-link"))   // Tutorials is an intercepted SPA link
    }

    @Test func footerRendersTagline() {
        let html = HTMLRenderer.render(SiteFooter())
        #expect(html.contains("SwiftUI in spirit"))
        #expect(html.contains("MIT License"))
    }

    @Test func bigHeroRendersActionsAndGrid() {
        let ch = Curriculum.chapter(slug: "hello-swiftwui")!
        // Big-hero shape needs heroPanel != nil; fixture stands in until Task 10 authors ch4.
        let fixture = Chapter(slug: ch.slug, track: ch.track, kicker: ch.kicker,
                              title: ch.title, tagline: ch.tagline, body: ch.body,
                              minutes: ch.minutes, kind: .chapter,
                              heroPanel: .terminal(title: "x", lines: []),
                              sections: [TutorialKit.Section(anchor: "toolchain", kicker: "01",
                                                 title: "t", steps: [Step("s")],
                                                 panel: .terminal(title: "x", lines: []))])
        let html = HTMLRenderer.render(HeroView(chapter: fixture) { Div(class: "panel-probe") { Text("P") } })
        #expect(html.contains("tut-hero-grid"))
        #expect(html.contains("GETTING STARTED · 25 MIN"))
        #expect(html.contains("Start the tutorial"))
        #expect(html.contains("#toolchain"))
        #expect(html.contains("panel-probe"))
    }

    @Test func simpleHeroHasNoGridOrActions() {
        let ch = Curriculum.chapter(slug: "style-in-swift")!
        let html = HTMLRenderer.render(HeroView(chapter: ch))
        #expect(html.contains("tut-hero-simple"))
        #expect(!html.contains("tut-hero-grid"))
        #expect(!html.contains("Start the tutorial"))
    }

    @Test func ctaTargetsNextChapterAndLastWrapsToOverview() {
        let styles = Curriculum.chapter(slug: "hello-swiftwui")!
        let html = HTMLRenderer.render(NextChapterCTA(chapter: styles))
        #expect(html.contains("NEXT CHAPTER"))
        #expect(html.contains("/tutorials/wrap-up-explore"))

        let last = Curriculum.chapters.last!
        let lastHTML = HTMLRenderer.render(NextChapterCTA(chapter: last))
        #expect(lastHTML.contains("Explore more tutorials"))
        #expect(lastHTML.contains("href=\"/\""))

        let overviewHTML = HTMLRenderer.render(NextChapterCTA(chapter: Curriculum.overview))
        #expect(!overviewHTML.contains("tut-cta-card"))   // overview has no CTA
    }
}
