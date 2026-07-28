import Testing
import SwiftWUI
@testable import TutorialKit

@Suite @MainActor struct ChapterBarTests {
    @Test func menuListsAllEntriesGroupedByTrack() {
        let html = HTMLRenderer.render(ChapterMenu(currentSlug: "hello-swiftwui"))
        for ch in Curriculum.chapters { #expect(html.contains(ch.title)) }
        // Group labels are kicker rows now — a lowercased source comment, so
        // the track name is rendered verbatim and the caps live in CSS.
        for track in Track.allCases {
            #expect(html.contains("<span class=\"tut-kicker-slash\">//</span> \(track.rawValue)"),
                    "missing group \(track.rawValue)")
        }
        #expect(html.contains("tut-menu-item-active"))
        #expect(html.contains("aria-current=\"page\""))   // the current entry, for AT
    }

    @Test func chapterDropdownTogglesOverlay() {
        let ch = Curriculum.chapter(slug: "hello-swiftwui")!
        let (rt, backend, sched) = makeRuntime(ChapterBar(chapter: ch))
        rt.mount()
        // prerendered state: closed
        #expect(findFirst(backend.container, class: "tut-menu-open") == nil)
        let toggle = findFirst(backend.container, class: "tut-dropdown")!
        #expect(toggle.attrs["aria-expanded"] == "false")
        rt.dispatch(toggle.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-menu-open") != nil)
        #expect(toggle.attrs["aria-expanded"] == "true")
        rt.dispatch(toggle.events["click"]!)
        sched.pump()
        // The sheet leaves on an exit transition: it stays in the DOM until
        // its animation settles, which only the mock's clock can do.
        settleAnimations(backend, sched)
        #expect(findFirst(backend.container, class: "tut-menu-open") == nil)
        #expect(toggle.attrs["aria-expanded"] == "false")
    }

    @Test func sectionDropdownHiddenWithoutSections() {
        let wrapUp = Curriculum.chapter(slug: "wrap-up-ship")!   // stub: no sections
        let html = HTMLRenderer.render(ChapterBar(chapter: wrapUp))
        #expect(!html.contains("tut-pill"))   // no pill at all, not merely no label
    }

    @Test func menuClosesAcrossParamOnlyNavigation() {
        // ChapterPage routes all share the /tutorials/:slug pattern, so
        // @State (menuOpen) would otherwise survive chapter → chapter nav.
        let (rt, backend, sched) = makeRuntime(TutorialApp().body)
        rt.mount()
        rt.navigate(to: "/tutorials/hello-swiftwui")
        sched.pump()
        let bar = findFirst(backend.container, class: "tut-chapterbar")!
        let toggle = findFirst(bar, class: "tut-dropdown")!
        rt.dispatch(toggle.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-menu-open") != nil)
        rt.navigate(to: "/tutorials/style-in-swift")
        sched.pump()
        settleAnimations(backend, sched)
        #expect(findFirst(backend.container, class: "tut-menu-open") == nil)
    }

    @Test func sectionDropdownListsAnchorsAndReverseMutualExclusion() {
        let ch = Curriculum.chapter(slug: "hello-swiftwui")!
        let (rt, backend, sched) = makeRuntime(ChapterBar(chapter: ch))
        rt.mount()
        let sections = findFirst(backend.container, class: "tut-pill")!
        let chapters = findFirst(backend.container, class: "tut-dropdown")!
        #expect(sections.attrs["aria-expanded"] == "false")

        // The sheet is rendered only while open, so the anchors arrive on click.
        rt.dispatch(sections.events["click"]!)
        sched.pump()
        #expect(sections.attrs["aria-expanded"] == "true")
        let hrefs = findAll(backend.container, tag: "a").compactMap { $0.attrs["href"] }
        for anchor in ["#toolchain", "#core-api", "#state"] {
            #expect(hrefs.contains(anchor), "missing \(anchor)")
        }

        rt.dispatch(chapters.events["click"]!)   // open chapter dropdown
        sched.pump()
        settleAnimations(backend, sched)
        #expect(findAll(backend.container, class: "tut-menu-open").count == 1)
        #expect(sections.attrs["aria-expanded"] == "false")
        #expect(chapters.attrs["aria-expanded"] == "true")
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
        // the rail: a fill running down to the active step, badges carrying
        // exactly one skin class each
        #expect(html.contains("<div class=\"tut-rail\">"))
        #expect(html.contains("tut-rail-fill"))
        #expect(html.contains("tut-step-badge tut-step-badge-active"))
        #expect(html.contains("tut-step-badge tut-step-badge-rest"))
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

    /// Options are `<button>`s too now, so the Check/Next control can no longer
    /// be addressed as "the first button" — it is the one carrying the submit class.
    private func submit(_ backend: MockBackend) -> MockNode? {
        findFirst(backend.container, class: "tut-quiz-submit")
    }

    @Test func prerenderedStateIsQuestionOneUnchecked() {
        let html = HTMLRenderer.render(QuizCard(quiz: quiz))
        #expect(html.contains("question 1 of 3"))
        #expect(html.contains("Check answer"))
        #expect(!html.contains("tut-option-selected"))
        #expect(!html.contains("tut-explain"))
        // Every option is a real button announcing its own state: keyboard
        // reachable without JS, which no amount of CSS can retrofit.
        #expect(html.contains(
            "<button aria-pressed=\"false\" class=\"tut-option tut-option-rest\" type=\"button\">"))
        #expect(!html.contains("aria-pressed=\"true\""))
        #expect(html == HTMLRenderer.render(QuizCard(quiz: quiz)))   // deterministic
    }

    @Test func selectCheckAdvanceFlow() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()

        // select the correct option (index 1)
        let options = findAll(backend.container, class: "tut-option")
        #expect(options.allSatisfy { $0.tag == "button" })
        rt.dispatch(options[1].events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-option-selected") != nil)
        #expect(options[1].attrs["aria-pressed"] == "true")
        #expect(options[0].attrs["aria-pressed"] == "false")

        // check → correct highlight + explanation + Next
        rt.dispatch(submit(backend)!.events["click"]!)
        sched.pump()
        let correct = findFirst(backend.container, class: "tut-option-correct")
        #expect(correct != nil)
        #expect(findFirst(backend.container, class: "tut-explain-ok") != nil)
        // The verdict is never carried by the tint alone: glyph + word.
        #expect(textContent(correct!).contains("✓"))
        #expect(textContent(correct!).contains("correct"))

        // next question resets selection
        rt.dispatch(submit(backend)!.events["click"]!)
        sched.pump()
        #expect(textContent(backend.container).contains("question 2 of 3"))
        #expect(findFirst(backend.container, class: "tut-option-selected") == nil)
    }

    @Test func wrongAnswerHighlightsBothAndLastQuestionHasNoNext() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()
        let options = findAll(backend.container, class: "tut-option")
        rt.dispatch(options[0].events["click"]!)   // wrong (correct is 1)
        sched.pump()
        rt.dispatch(submit(backend)!.events["click"]!)
        sched.pump()
        let wrong = findFirst(backend.container, class: "tut-option-wrong")
        #expect(wrong != nil)
        #expect(findFirst(backend.container, class: "tut-option-correct") != nil)
        #expect(findFirst(backend.container, class: "tut-explain-no") != nil)
        #expect(textContent(wrong!).contains("✕"))
        #expect(textContent(wrong!).contains("not this one"))
    }

    @Test func checkWithoutSelectionIsInert() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()
        rt.dispatch(submit(backend)!.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-explain") == nil)
    }

    @Test func lastQuestionHidesNextButton() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()
        // answer Q1 (correct = index 1) and advance
        rt.dispatch(findAll(backend.container, class: "tut-option")[1].events["click"]!); sched.pump()
        rt.dispatch(submit(backend)!.events["click"]!); sched.pump()   // Check
        rt.dispatch(submit(backend)!.events["click"]!); sched.pump()   // Next → Q2
        // answer Q2 (correct = index 0) and advance
        rt.dispatch(findAll(backend.container, class: "tut-option")[0].events["click"]!); sched.pump()
        rt.dispatch(submit(backend)!.events["click"]!); sched.pump()   // Check
        rt.dispatch(submit(backend)!.events["click"]!); sched.pump()   // Next → Q3
        #expect(textContent(backend.container).contains("question 3 of 3"))
        // answer Q3 (correct = index 1) and check — NO Next button may remain
        rt.dispatch(findAll(backend.container, class: "tut-option")[1].events["click"]!); sched.pump()
        rt.dispatch(submit(backend)!.events["click"]!); sched.pump()   // Check
        #expect(submit(backend) == nil)
        #expect(!textContent(backend.container).contains("Next question"))
        #expect(findFirst(backend.container, class: "tut-explain-ok") != nil)
    }

    @Test func postCheckClicksDoNotChangeSelection() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()
        rt.dispatch(findAll(backend.container, class: "tut-option")[1].events["click"]!); sched.pump()
        rt.dispatch(submit(backend)!.events["click"]!); sched.pump()   // Check
        let before = findAll(backend.container, class: "tut-option-correct").count
        #expect(before == 1)
        // click a different option after checking — must be inert
        rt.dispatch(findAll(backend.container, class: "tut-option")[0].events["click"]!); sched.pump()
        #expect(findAll(backend.container, class: "tut-option-correct").count == before)
        #expect(findFirst(backend.container, class: "tut-option-wrong") == nil)
    }
}
