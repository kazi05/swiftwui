import Foundation
import Testing
@testable import SwiftWUI

private struct Card: TagModifier {
    func body(content: Content) -> some Tag {
        Div(class: "card") { content }
    }
}

private extension Tag {
    func card() -> some Tag { modifier(Card()) }
}

private struct Toggler: TagModifier {
    @State private var on = false
    func body(content: Content) -> some Tag {
        Div(class: on ? "t-on" : "t-off") {
            Button("toggle", onClick: { on = true })
            content
        }
    }
}

private struct CounterFixture: Tag {
    @State var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("+", onClick: { count += 1 })
        }
    }
}

// Styled host whose body wraps scoped content in a stateful modifier — the
// modifier body preserves the caller's Styled scope, so a modifier-local
// subtree pass must re-seed it (regression fixture for the scope-drop bug).
private struct ScopedHost: Tag, Styled {
    @RulesBuilder var styles: [Rule] {
        Rule(class: "inner") { $0.padding(.px(4)) }
    }
    var body: some Tag {
        Span(class: "inner") { Text("x") }.modifier(Toggler())
    }
}

// Uses `content` twice — the documented identity-duplication limitation.
private struct DuplicatingModifier: TagModifier {
    func body(content: Content) -> some Tag {
        Div(class: "dup") {
            content
            content
        }
    }
}

private final class SessionCapture { var seen: WebSession? }
private struct SessionReadingModifier: TagModifier {
    @Environment(\.webSession) var session
    let cap: SessionCapture
    func body(content: Content) -> some Tag {
        cap.seen = session
        return Div { content }
    }
}
private final class StubTransport: FetchTransport {
    func perform(_ request: WebRequest) async throws -> (Foundation.Data, WebResponse) {
        (Foundation.Data(), WebResponse(status: 200, headers: [:]))
    }
}

@Suite @MainActor struct TagModifierTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func modifierWrapsContent() {
        let (_, backend, _) = makeRuntime(Text("hi").modifier(Card()))
        #expect(backend.serializeHTML() == "<div class=\"card\">hi</div>")
    }

    @Test func extensionSugarEquivalent() {
        let (_, direct, _) = makeRuntime(Text("hi").modifier(Card()))
        let (_, sugar, _) = makeRuntime(Text("hi").card())
        #expect(direct.serializeHTML() == sugar.serializeHTML())
    }

    @Test func stateInModifierSurvivesRerender() {
        let (runtime, backend, sched) = makeRuntime(Text("x").modifier(Toggler()))
        #expect(backend.serializeHTML().contains("t-off"))
        clickFirst(backend, runtime, tag: "button", sched: sched)
        #expect(backend.serializeHTML().contains("t-on"))
        #expect(!backend.serializeHTML().contains("t-off"))
        // second, unrelated re-render: dispatching again is idempotent (on stays true)
        clickFirst(backend, runtime, tag: "button", sched: sched)
        #expect(backend.serializeHTML().contains("t-on"))
    }

    @Test func contentStateSurvivesModifierInvalidation() {
        let (runtime, backend, sched) = makeRuntime(CounterFixture().modifier(Toggler()))
        clickFirst(backend, runtime, tag: "button", index: 1, sched: sched)   // content's "+"
        #expect(backend.serializeHTML().contains("Count: 1"))
        clickFirst(backend, runtime, tag: "button", index: 0, sched: sched)   // modifier's "toggle"
        #expect(backend.serializeHTML().contains("t-on"))
        #expect(backend.serializeHTML().contains("Count: 1"))                // content state untouched
    }

    @Test func environmentReachesModifier() {
        let cap = SessionCapture()
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Text("x").modifier(SessionReadingModifier(cap: cap)),
                              scheduleMicrotask: { $0() })
        runtime._webSession = WebSession(transport: StubTransport())
        runtime.mount()
        #expect(cap.seen !== WebSession.unsupported)
    }

    @Test func chainingTwoModifiersNests() {
        let (_, backend, _) = makeRuntime(Text("x").modifier(Card()).modifier(Card()))
        #expect(backend.serializeHTML() == "<div class=\"card\"><div class=\"card\">x</div></div>")
    }

    @Test func styledScopeSurvivesModifierLocalSubtreePass() {
        let marker = scopeMarker(forTypeName: String(reflecting: ScopedHost.self))
        let (runtime, backend, sched) = makeRuntime(ScopedHost())
        // full pass: marker on the modifier's wrapper div AND the wrapped span
        #expect(backend.serializeHTML().contains("t-off \(marker)"))
        #expect(backend.serializeHTML().contains("inner \(marker)"))
        // toggle the modifier's @State → a modifier-local subtree pass (not full)
        clickFirst(backend, runtime, tag: "button", sched: sched)
        let html = backend.serializeHTML()
        #expect(html.contains("t-on"))
        #expect(html.contains("t-on \(marker)"))    // wrapper element still scoped
        #expect(html.contains("inner \(marker)"))   // wrapped content still scoped
    }

    @Test func modifierUsingContentTwiceDuplicatesWithIndependentState() {
        let (runtime, backend, sched) = makeRuntime(CounterFixture().modifier(DuplicatingModifier()))
        // content used twice → two independent copies, no crash
        #expect(backend.serializeHTML().ranges(of: "Count: 0").count == 2)
        clickFirst(backend, runtime, tag: "button", index: 0, sched: sched)
        let html = backend.serializeHTML()
        // exactly one copy advanced — the two placeholders keep independent
        // structural identity (documented duplication limitation)
        #expect(html.ranges(of: "Count: 1").count == 1)
        #expect(html.ranges(of: "Count: 0").count == 1)
    }
}
