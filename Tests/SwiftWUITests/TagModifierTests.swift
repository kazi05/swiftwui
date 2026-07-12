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
}
