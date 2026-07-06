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
