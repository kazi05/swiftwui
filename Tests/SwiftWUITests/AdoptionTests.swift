import Testing
@testable import SwiftWUI

private struct HydroFixture: Tag {
    @State var count = 0
    var body: some Tag {
        Div(class: "box") {
            H1("Count: \(count)")
            Button("+") { count += 1 }
        }
    }
}

/// The MockNode tree a T8-conforming prerender of HydroFixture(count: 0) parses to.
@MainActor private func prerenderedTree(into backend: MockBackend) {
    let div = MockNode(); div.tag = "div"; div.attrs = ["class": "box"]
    let h1 = MockNode(); h1.tag = "h1"
    let h1t = MockNode(); h1t.text = "Count: 0"
    let btn = MockNode(); btn.tag = "button"; btn.attrs = ["type": "button"]
    let btnt = MockNode(); btnt.text = "+"
    h1.children = [h1t]; h1t.parent = h1
    btn.children = [btnt]; btnt.parent = btn
    div.children = [h1, btn]; h1.parent = div; btn.parent = div
    backend.container.children = [div]; div.parent = backend.container
}

@Suite @MainActor struct AdoptionTests {
    @Test func adoptionClaimsEveryNodeWithZeroCreates() {
        let base = MockBackend()
        prerenderedTree(into: base)
        let adopting = AdoptingBackend(base: base, container: base.container)
        let sched = TestScheduler()
        let runtime = Runtime(backend: adopting, container: base.container,
                              root: HydroFixture(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        #expect(adopting.finishAdoption())
        #expect(base.counts["createElement"] == nil)      // nothing created
        #expect(base.counts["createTextNode"] == nil)
        #expect((base.counts["setEventListener"] ?? 0) >= 1)   // listeners attached
        // The adopted tree is LIVE: click through it.
        clickFirst(base, runtime, tag: "button", sched: sched)
        #expect(base.serializeHTML().contains("Count: 1"))
    }

    @Test func tagMismatchFailsAndFallbackRebuildIsCorrect() {
        let base = MockBackend()
        prerenderedTree(into: base)
        findFirst(base.container, tag: "h1")!.tag = "h2"      // tamper
        let adopting = AdoptingBackend(base: base, container: base.container)
        adopting._assertOnMismatch = false
        let sched = TestScheduler()
        var runtime = Runtime(backend: adopting, container: base.container,
                              root: HydroFixture(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        #expect(!adopting.finishAdoption())
        // Cold-rebuild path (what DOMRuntime does on failure, spec D6):
        for c in base.container.children { base.remove(c, from: base.container) }
        let freshAdopting = AdoptingBackend(base: base, container: base.container)
        // Empty container → empty stream → cold mount (I1), not a mismatch:
        // finishAdoption() is trivially true and creates are real.
        #expect(freshAdopting.finishAdoption())
        runtime = Runtime(backend: freshAdopting,
                          container: base.container, root: HydroFixture(),
                          scheduleMicrotask: sched.schedule)
        runtime.mount()
        #expect(base.serializeHTML() ==
            "<div class=\"box\"><h1>Count: 0</h1><button type=\"button\">+</button></div>")
    }

    @Test func leftoverNodesFailAdoption() {
        let base = MockBackend()
        prerenderedTree(into: base)
        let extra = MockNode(); extra.tag = "p"
        base.container.children.append(extra); extra.parent = base.container
        let adopting = AdoptingBackend(base: base, container: base.container)
        adopting._assertOnMismatch = false
        let sched = TestScheduler()
        let runtime = Runtime(backend: adopting, container: base.container,
                              root: HydroFixture(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        #expect(!adopting.finishAdoption())
    }

    @Test func textareaSubtreeIsSkipped() {
        // Prerender serializes textarea value as child text; VDOM has no such
        // child — the walk must swallow it (spec §8).
        struct TAFixture: Tag {
            @State var text = "seed"
            var body: some Tag { Div { Textarea(text: $text) } }
        }
        let base = MockBackend()
        let div = MockNode(); div.tag = "div"
        let ta = MockNode(); ta.tag = "textarea"
        let tat = MockNode(); tat.text = "seed"
        ta.children = [tat]; tat.parent = ta
        div.children = [ta]; ta.parent = div
        base.container.children = [div]; div.parent = base.container
        let adopting = AdoptingBackend(base: base, container: base.container)
        let sched = TestScheduler()
        let runtime = Runtime(backend: adopting, container: base.container,
                              root: TAFixture(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        #expect(adopting.finishAdoption())
        _ = runtime
    }
}
