import Testing
@testable import SwiftWUI

/// End-to-end pipeline coverage for the typed `OrderedStyle` migration:
/// per-property patches out of the Reconciler, and the wrapper/element
/// duplicate-collapse rule (spec §5) at the serialized-HTML boundary.
@Suite @MainActor struct OrderedStylePipelineTests {
    private struct FlagStyle: Tag {
        @State var flag = true
        var body: some Tag {
            Div { Text("x") }
                .style("opacity", flag ? "1" : "0.5")
                .style("color", "red")             // untouched sibling property
            Button("toggle") { flag.toggle() }
        }
    }

    @Test func styleChangeEmitsPerPropertyPatch() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: FlagStyle(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        let before = backend.counts["setStyleProperty", default: 0]
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        // exactly one property changed (opacity) → exactly one patch call
        #expect(backend.counts["setStyleProperty", default: 0] == before + 1)
        let div = findFirst(backend.container, tag: "div")!
        #expect(div.style["opacity"] == "0.5")
        #expect(div.style["color"] == "red")       // sibling untouched, unchanged
    }

    /// `opacity` is present only while `on` — toggling it off removes the
    /// property (pass N present → pass N+1 absent), toggling back on re-adds it.
    private struct ToggleStyle: Tag {
        @State var on = true
        var body: some Tag {
            Div { Text("x") }
                .style("color", "red")                     // always present
                .style(on ? "opacity" : "color", on ? "1" : "red")  // opacity only when on
            Button("toggle") { on.toggle() }
        }
    }

    @Test func removedPropertyEmitsRemovePatch() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ToggleStyle(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        let div = findFirst(backend.container, tag: "div")!
        #expect(div.style["opacity"] == "1")
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)          // on → false: opacity absent
        sched.pump()
        #expect(backend.counts["removeStyleProperty", default: 0] == 1)
        #expect(div.style["opacity"] == nil)               // gone from the host node
        #expect(!backend.serializeHTML().contains("opacity"))
    }

    @Test func addedPropertyEmitsSetPatch() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ToggleStyle(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!); sched.pump()   // on → false: opacity removed
        let setsBefore = backend.counts["setStyleProperty", default: 0]
        runtime.dispatch(button.events["click"]!); sched.pump()   // on → true: opacity re-added
        // absent → present: exactly one setStyleProperty for the re-added opacity
        #expect(backend.counts["setStyleProperty", default: 0] == setsBefore + 1)
        let div = findFirst(backend.container, tag: "div")!
        #expect(div.style["opacity"] == "1")
        #expect(backend.serializeHTML().contains("opacity: 1"))
    }

    private struct WrapperColor: Tag {
        var body: some Tag { Div { Text("x") }.color(.hex("#00f")) }
    }

    @Test func wrapperDuplicateCollapsesToOuterValue() {
        let html = HTMLRenderer.render(WrapperColor().color(.hex("#f00")))
        #expect(html.contains(#"style="color: #f00""#))
        #expect(!html.contains("#00f"))
    }
}
