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

    @Test func menuClosesAcrossParamOnlyNavigation() {
        // ChapterPage routes all share the /tutorials/:slug pattern, so
        // @State (menuOpen) would otherwise survive chapter → chapter nav.
        let (rt, backend, sched) = makeRuntime(TutorialApp().body)
        rt.mount()
        rt.navigate(to: "/tutorials/hello-swiftwui")
        sched.pump()
        let bar = findFirst(backend.container, class: "tut-chapterbar")!
        let toggle = findAll(bar, tag: "button")[0]
        rt.dispatch(toggle.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-menu-open") != nil)
        rt.navigate(to: "/tutorials/style-in-swift")
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-menu-open") == nil)
    }

    @Test func sectionDropdownListsAnchorsAndReverseMutualExclusion() {
        let ch = Curriculum.chapter(slug: "hello-swiftwui")!
        let html = HTMLRenderer.render(ChapterBar(chapter: ch))
        #expect(html.contains("Sections ▾"))
        for anchor in ["#toolchain", "#core-api", "#state"] { #expect(html.contains(anchor)) }

        let (rt, backend, sched) = makeRuntime(ChapterBar(chapter: ch))
        rt.mount()
        let buttons = findAll(backend.container, tag: "button")
        rt.dispatch(buttons[1].events["click"]!)   // open sections dropdown
        sched.pump()
        rt.dispatch(buttons[0].events["click"]!)   // open chapter dropdown
        sched.pump()
        #expect(findAll(backend.container, class: "tut-menu-open").count == 1)
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
                    origin: .fragment(path: "Examples/Counter/Sources/CounterApp.swift")))),
                Step("Mutate it"),
                Step("Writes coalesce"),
            ],
            panel: .browser(url: "localhost:8080", screenshot: "screens/counter-3.png"))
    }

    @Test func panelSelection() {
        #expect(fixture.activePanel(step: 0) == .code(CodePanel(
            file: "Counter.swift", code: "@State var count = 0",
            origin: .fragment(path: "Examples/Counter/Sources/CounterApp.swift"))))
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

@Suite @MainActor struct QuizCardTests {
    private var quiz: Quiz {
        Quiz(questions: [
            Question(prompt: "Which property wrapper drives re-rendering in SwiftWUI?",
                     options: ["@Environment", "@State", "@Binding"], correctIndex: 1,
                     explanation: "Assigning a new value to @State invalidates the owning component."),
            Question(prompt: "Q2", options: ["a", "b"], correctIndex: 0, explanation: "E2"),
            Question(prompt: "Q3", options: ["a", "b"], correctIndex: 1, explanation: "E3"),
        ])
    }

    @Test func prerenderedStateIsQuestionOneUnchecked() {
        let html = HTMLRenderer.render(QuizCard(quiz: quiz))
        #expect(html.contains("Question 1 of 3"))
        #expect(html.contains("Check answer"))
        #expect(!html.contains("tut-option-selected"))
        #expect(!html.contains("tut-explain"))
        #expect(html == HTMLRenderer.render(QuizCard(quiz: quiz)))   // deterministic
    }

    @Test func selectCheckAdvanceFlow() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()

        // select the correct option (index 1)
        let options = findAll(backend.container, class: "tut-option")
        rt.dispatch(options[1].events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-option-selected") != nil)

        // check → correct highlight + explanation + Next
        let check = findAll(backend.container, tag: "button")[0]
        rt.dispatch(check.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-option-correct") != nil)
        #expect(findFirst(backend.container, class: "tut-explain-ok") != nil)

        // next question resets selection
        let next = findAll(backend.container, tag: "button")[0]
        rt.dispatch(next.events["click"]!)
        sched.pump()
        #expect(textContent(backend.container).contains("Question 2 of 3"))
        #expect(findFirst(backend.container, class: "tut-option-selected") == nil)
    }

    @Test func wrongAnswerHighlightsBothAndLastQuestionHasNoNext() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()
        let options = findAll(backend.container, class: "tut-option")
        rt.dispatch(options[0].events["click"]!)   // wrong (correct is 1)
        sched.pump()
        rt.dispatch(findAll(backend.container, tag: "button")[0].events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-option-wrong") != nil)
        #expect(findFirst(backend.container, class: "tut-option-correct") != nil)
        #expect(findFirst(backend.container, class: "tut-explain-no") != nil)
    }

    @Test func checkWithoutSelectionIsInert() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()
        rt.dispatch(findAll(backend.container, tag: "button")[0].events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-explain") == nil)
    }

    @Test func lastQuestionHidesNextButton() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()
        // answer Q1 (correct = index 1) and advance
        rt.dispatch(findAll(backend.container, class: "tut-option")[1].events["click"]!); sched.pump()
        rt.dispatch(findAll(backend.container, tag: "button")[0].events["click"]!); sched.pump()   // Check
        rt.dispatch(findAll(backend.container, tag: "button")[0].events["click"]!); sched.pump()   // Next → Q2
        // answer Q2 (correct = index 0) and advance
        rt.dispatch(findAll(backend.container, class: "tut-option")[0].events["click"]!); sched.pump()
        rt.dispatch(findAll(backend.container, tag: "button")[0].events["click"]!); sched.pump()   // Check
        rt.dispatch(findAll(backend.container, tag: "button")[0].events["click"]!); sched.pump()   // Next → Q3
        #expect(textContent(backend.container).contains("Question 3 of 3"))
        // answer Q3 (correct = index 1) and check — NO Next button may remain
        rt.dispatch(findAll(backend.container, class: "tut-option")[1].events["click"]!); sched.pump()
        rt.dispatch(findAll(backend.container, tag: "button")[0].events["click"]!); sched.pump()   // Check
        #expect(findAll(backend.container, tag: "button").isEmpty)
        #expect(findFirst(backend.container, class: "tut-explain-ok") != nil)
    }

    @Test func postCheckClicksDoNotChangeSelection() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()
        rt.dispatch(findAll(backend.container, class: "tut-option")[1].events["click"]!); sched.pump()
        rt.dispatch(findAll(backend.container, tag: "button")[0].events["click"]!); sched.pump()   // Check
        let before = findAll(backend.container, class: "tut-option-correct").count
        // click a different option after checking — must be inert
        rt.dispatch(findAll(backend.container, class: "tut-option")[0].events["click"]!); sched.pump()
        #expect(findAll(backend.container, class: "tut-option-correct").count == before)
        #expect(findFirst(backend.container, class: "tut-option-wrong") == nil)
    }
}
