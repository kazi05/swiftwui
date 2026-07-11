import Testing
@testable import SwiftWUI

@MainActor
private final class Sched {
    var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func drain() { while !queue.isEmpty { queue.removeFirst()() } }
}

private enum Flavor: String, StorageConvertible { case vanilla, mint }

private struct Counter: Tag {
    @AppStorage("count") var count = 0
    var body: some Tag {
        Div {
            Text("count:\(count)")
            Button("inc") { count += 1 }
        }
    }
}

private struct TwinA: Tag {
    @AppStorage("shared") var v = "a"
    var body: some Tag { Text("A:\(v)") }
}
private struct TwinB: Tag {
    @AppStorage("shared") var v = "b"
    var body: some Tag { Div { Text("B:\(v)"); Button("setB") { v = "written" } } }
}
private struct Twins: Tag { var body: some Tag { Div { TwinA(); TwinB() } } }

@Suite @MainActor struct StorageTests {

    private func mounted<R: Tag>(_ root: R, seed: [String: String] = [:])
        -> (Runtime<MockBackend>, MockBackend, Sched) {
        let backend = MockBackend()
        backend.localStorage = seed
        let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount(); sched.drain()
        return (runtime, backend, sched)
    }

    private func clickFirstButton(_ runtime: Runtime<MockBackend>, _ backend: MockBackend,
                                  _ sched: Sched) {
        // Find the first registered click listener and dispatch it (existing
        // pattern: walk MockNode tree for events["click"]).
        func firstClick(_ n: MockNode) -> ListenerID? {
            if let id = n.events["click"] { return id }
            for c in n.children { if let id = firstClick(c) { return id } }
            return nil
        }
        let lid = firstClick(backend.container)!
        runtime.dispatch(lid)
        sched.drain()
    }

    @Test func persistedValueLoadsBeforeFirstRender() {
        let (_, backend, _) = mounted(Counter(), seed: ["count": "5"])
        #expect(backend.serializeHTML().contains("count:5"))
    }

    @Test func writePersistsAndRerenders() {
        let (runtime, backend, sched) = mounted(Counter())
        #expect(backend.serializeHTML().contains("count:0"))
        clickFirstButton(runtime, backend, sched)
        #expect(backend.serializeHTML().contains("count:1"))
        #expect(backend.localStorage["count"] == "1")
    }

    @Test func sameKeySharesOneBoxAcrossComponents() {
        let (runtime, backend, sched) = mounted(Twins())
        // Both render their own defaults until a value exists.
        clickFirstButton(runtime, backend, sched)          // TwinB writes "written"
        let html = backend.serializeHTML()
        #expect(html.contains("A:written"))                // TwinA re-rendered from the SHARED box
        #expect(html.contains("B:written"))
    }

    @Test func externalChangeRerendersReaders() {
        // NOTE (deviation from brief): brief discarded the runtime binding here
        // (`let (_, backend, sched) = ...`). Runtime.mount() wires
        // beginStorageObservation with a `[weak self]` closure — with no strong
        // ref left, the runtime is deallocated before
        // simulateExternalStorageChange fires, so storageObserver's callee is
        // nil and the box never updates (same class of bug as Task 1's
        // keep-alive precedent). Bind + keep the runtime alive to the end.
        let (runtime, backend, sched) = mounted(Counter(), seed: ["count": "1"])
        backend.simulateExternalStorageChange(kind: .local, key: "count", value: "42")
        sched.drain()
        #expect(backend.serializeHTML().contains("count:42"))
        _ = runtime   // keep alive — beginStorageObservation closure captures [weak self]
    }

    @Test func decodeFailureFallsBackToDefault() {
        let (_, backend, _) = mounted(Counter(), seed: ["count": "not-a-number"])
        #expect(backend.serializeHTML().contains("count:0"))   // no crash, wrapper default
    }

    @Test func rawRepresentableOptIn() {
        struct FlavorView: Tag {
            @AppStorage("flavor") var flavor = Flavor.vanilla
            var body: some Tag { Text("f:\(flavor.rawValue)") }
        }
        let (_, backend, _) = mounted(FlavorView(), seed: ["flavor": "mint"])
        #expect(backend.serializeHTML().contains("f:mint"))
    }

    @Test func optionalNilRemovesKey() {
        struct OptView: Tag {
            @AppStorage("opt") var v: String? = nil
            var body: some Tag { Div { Text(v ?? "none"); Button("clear") { v = nil } } }
        }
        let (runtime, backend, sched) = mounted(OptView(), seed: ["opt": "x"])
        #expect(backend.serializeHTML().contains("x"))
        clickFirstButton(runtime, backend, sched)
        #expect(backend.localStorage["opt"] == nil)
        #expect(backend.serializeHTML().contains("none"))
    }

    @Test func sceneStorageUsesSessionNamespace() {
        struct SceneView: Tag {
            @SceneStorage("tab") var tab = "home"
            var body: some Tag { Div { Text("tab:\(tab)"); Button("go") { tab = "settings" } } }
        }
        let (runtime, backend, sched) = mounted(SceneView())
        clickFirstButton(runtime, backend, sched)
        #expect(backend.sessionStorage["tab"] == "settings")
        #expect(backend.localStorage["tab"] == nil)
    }

    @Test func bindingProjection() {
        struct BindView: Tag {
            @AppStorage("text") var text = ""
            var body: some Tag { Input(type: .text, value: $text) }
        }
        let (runtime, backend, sched) = mounted(BindView())
        func firstInputListener(_ n: MockNode) -> ListenerID? {
            if let id = n.events["input"] { return id }
            for c in n.children { if let id = firstInputListener(c) { return id } }
            return nil
        }
        let lid = firstInputListener(backend.container)!
        runtime.dispatch(lid, payload: InputEvent(value: "hello"))
        sched.drain()
        #expect(backend.localStorage["text"] == "hello")
    }
}
