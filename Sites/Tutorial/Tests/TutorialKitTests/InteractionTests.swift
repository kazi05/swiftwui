import Testing
import SwiftWUI
@testable import TutorialKit

@Suite @MainActor struct ChapterBarTests {
    @Test func menuListsAll12EntriesGroupedByTrack() {
        let html = HTMLRenderer.render(ChapterMenu(currentSlug: "hello-swiftwui"))
        for ch in Curriculum.chapters { #expect(html.contains(ch.title)) }
        for label in ["WELCOME", "EXPLORE SWIFTWUI", "STYLES", "ROUTING", "SHIP"] {
            #expect(html.contains(label))
        }
        #expect(html.contains("tut-menu-item-active"))
    }

    @Test func chapterDropdownTogglesOverlay() {
        let ch = Curriculum.chapter(slug: "hello-swiftwui")!
        let (rt, backend, sched) = makeRuntime(ChapterBar(chapter: ch))
        rt.mount()
        // prerendered state: closed
        #expect(findFirst(backend.container, class: "tut-menu-open") == nil)
        let toggle = findAll(backend.container, tag: "button")[0]
        rt.dispatch(toggle.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-menu-open") != nil)
        rt.dispatch(toggle.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-menu-open") == nil)
    }

    @Test func sectionDropdownHiddenWithoutSections() {
        let wrapUp = Curriculum.chapter(slug: "wrap-up-ship")!   // stub: no sections
        let html = HTMLRenderer.render(ChapterBar(chapter: wrapUp))
        #expect(!html.contains("Sections ▾"))
    }
}

@Suite @MainActor struct SectionViewTests {
    private var fixture: TutorialKit.Section {
        TutorialKit.Section(
            anchor: "state", kicker: "03 · STATE", title: "Add state",
            intro: "Intro line.",
            steps: [
                Step("Declare @State", panel: .code(CodePanel(
                    file: "Counter.swift", code: "@State var count = 0",
                    origin: .fragment(path: "Examples/Counter/Sources/main.swift")))),
                Step("Mutate it"),
                Step("Writes coalesce"),
            ],
            panel: .browser(url: "localhost:8080", screenshot: "screens/counter-3.png"))
    }

    @Test func panelSelection() {
        #expect(fixture.activePanel(step: 0) == .code(CodePanel(
            file: "Counter.swift", code: "@State var count = 0",
            origin: .fragment(path: "Examples/Counter/Sources/main.swift"))))
        #expect(fixture.activePanel(step: 1) == fixture.panel)   // no override → default
        #expect(fixture.activePanel(step: 99) == fixture.panel)  // out of range → default
    }

    @Test func ssgStateContract_stepZeroActiveAndOverridePanelShown() {
        let html = HTMLRenderer.render(SectionView(section: fixture, index: 0))
        #expect(html.contains("tut-step-active"))
        #expect(html.contains("id=\"state-step-0\""))
        #expect(html.contains("id=\"state-step-2\""))
        // step 0 carries an override → prerendered panel is the CODE card, not the browser mock
        #expect(html.contains("tut-card-dark"))
        #expect(!html.contains("tut-browser"))
        // deterministic render (hydration proxy)
        #expect(html == HTMLRenderer.render(SectionView(section: fixture, index: 0)))
    }

    @Test func firstStepIsTheActiveOne() {
        let html = HTMLRenderer.render(SectionView(section: fixture, index: 0))
        let activeRange = html.range(of: "tut-step-active")!
        let step1Range = html.range(of: "id=\"state-step-1\"")!
        #expect(activeRange.lowerBound < step1Range.lowerBound)
    }
}
