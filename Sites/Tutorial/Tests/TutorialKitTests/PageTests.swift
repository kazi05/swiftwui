import Testing
import SwiftWUI
@testable import TutorialKit

@Suite @MainActor struct PageTests {
    @Test func ssgPathListMatchesCurriculum() {
        // spec §9.5: 12 dynamic paths + static root == 13 pages
        #expect(Curriculum.ssgPaths.count + 1 == Curriculum.chapters.count)
        #expect(Set(Curriculum.ssgPaths).count == 12)
    }

    @Test func routerServesAllCurriculumPages() {
        let (rt, backend, sched) = makeRuntime(TutorialApp().body)
        rt.mount()
        #expect(textContent(backend.container).contains("Welcome to SwiftWUI Tutorials"))
        for ch in Curriculum.chapters where ch.kind != .overview {
            rt.navigate(to: ch.path)
            sched.pump()
            #expect(textContent(backend.container).contains(ch.title), "missing \(ch.slug)")
        }
    }

    @Test func unknownAndOverviewSlugsHit404() {
        let (rt, backend, sched) = makeRuntime(TutorialApp().body)
        rt.mount()
        rt.navigate(to: "/tutorials/no-such-chapter")
        sched.pump()
        #expect(textContent(backend.container).contains("404"))
        rt.navigate(to: "/tutorials/welcome")   // the overview's slug must NOT resolve here
        sched.pump()
        #expect(textContent(backend.container).contains("404"))
    }

    @Test func headTitleFollowsRoute() {
        let (rt, _, sched) = makeRuntime(TutorialApp().body)
        rt.mount()
        rt.navigate(to: "/tutorials/style-in-swift")
        sched.pump()
        #expect(rt._pageHead?.title == "Style in Swift — SwiftWUI Tutorials")
    }

    @Test func chapterPageGoldenStructure() {
        // tiny fixture chapter — full-page structural golden (spec §9.4).
        // slug MUST be a real curriculum slug: NextChapterCTA and ChapterMenu
        // resolve against Curriculum — an unknown slug drops the CTA.
        let ch = Chapter(slug: "hello-swiftwui", track: .explore, kicker: "TEST",
                        title: "Fixture", tagline: "T.", minutes: 1, kind: .chapter,
                        sections: [TutorialKit.Section(anchor: "one", kicker: "01 · A", title: "S1",
                                           steps: [Step("First"), Step("Second")],
                                           panel: .terminal(title: "t", lines: [TermLine(.command, "x")]))],
                        quiz: Quiz(questions: [
                            Question(prompt: "P", options: ["a", "b"], correctIndex: 0, explanation: "E"),
                            Question(prompt: "P2", options: ["a", "b"], correctIndex: 0, explanation: "E"),
                            Question(prompt: "P3", options: ["a", "b"], correctIndex: 0, explanation: "E"),
                        ]))
        let html = HTMLRenderer.render(ChapterPage(chapter: ch))
        for marker in ["tut-nav", "tut-chapterbar", "tut-hero", "tut-section",
                       "tut-step-active", "tut-quiz", "tut-cta-card", "tut-footer",
                       "id=\"one-step-0\"", "CHECK YOUR UNDERSTANDING"] {
            #expect(html.contains(marker), "missing \(marker)")
        }
    }
}
