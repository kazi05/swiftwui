import Foundation
import Testing
@testable import SwiftWUI

private struct NavigationLifecycleProbe: Tag {
    @Environment(\.routeInfo) private var route

    var body: some Tag {
        Div { Text(route.path) }
    }
}

@MainActor private final class DiagnosticLog {
    nonisolated deinit { }
    var events: [RuntimeDiagnosticEvent] = []
}

@MainActor private final class RuntimeLifetimeLog {
    nonisolated deinit { }
    var entries: [String] = []
}

@MainActor private final class BindingHolder {
    nonisolated deinit { }
    var binding: Binding<Int>?
}

private struct DiagnosticCounter: Tag {
    @State private var value = 0

    var body: some Tag {
        Button("value:\(value)") { value += 1 }
    }
}

private struct ExplicitRegistrationCounter: Tag, ExplicitComponentRegistration {
    @State private var value = 0
    @Environment(\.routeInfo) private var route

    static let componentIdentifier = "example.explicit-counter.v1"

    func registerProperties(_ properties: inout ComponentProperties) {
        properties.state(_value)
        properties.environment(_route)
    }

    var body: some Tag {
        Button("\(route.path):\(value)") { value += 1 }
    }
}

private struct BatchedEffectRow: Tag {
    let name: String
    let log: RuntimeLifetimeLog
    @State private var old = true

    var body: some Tag {
        Div {
            Button("toggle-\(name)") { old = false }
            if old {
                Text("old-\(name)")
                    .onAppear { log.entries.append("\(name)-old-appear") }
                    .onDisappear { log.entries.append("\(name)-old-disappear") }
            } else {
                Text("new-\(name)")
                    .onAppear { log.entries.append("\(name)-new-appear") }
            }
        }
    }
}

private struct BatchedEffectFixture: Tag {
    let log: RuntimeLifetimeLog

    var body: some Tag {
        Div {
            BatchedEffectRow(name: "left", log: log)
            BatchedEffectRow(name: "right", log: log)
        }
    }
}

private struct RetainedBindingChild: Tag {
    let holder: BindingHolder
    @State private var value = 0

    var body: some Tag {
        Button("capture") { holder.binding = $value }
    }
}

private struct RemovedStateFixture: Tag {
    let holder: BindingHolder
    @State private var showsChild = true

    var body: some Tag {
        Div {
            Button("remove") { showsChild = false }
            if showsChild { RetainedBindingChild(holder: holder) }
        }
    }
}

private let modernizationJSONEncode: SnapshotEncode = { value in
    struct AnyEncodable: Encodable {
        let base: any Encodable
        func encode(to encoder: Encoder) throws { try base.encode(to: encoder) }
    }
    guard let data = try? JSONEncoder().encode([AnyEncodable(base: value)]) else { return nil }
    return String(decoding: data, as: UTF8.self)
}

private let modernizationJSONDecode: SnapshotDecode = { json, type in
    func open<T: Decodable>(_ type: T.Type) -> (any Decodable)? {
        (try? JSONDecoder().decode([T].self, from: Data(json.utf8)))?.first
    }
    return _openExistential(type, do: open)
}

private struct NamedSnapshotV1: Tag, ExplicitComponentRegistration {
    @State private var count = 11
    @State private var label = "persisted"

    static let componentIdentifier = "example.named-snapshot.v1"
    func registerProperties(_ properties: inout ComponentProperties) {
        properties.state(_count, stableID: "count")
        properties.state(_label, stableID: "label")
    }
    var body: some Tag { Text("\(label):\(count)") }
}

private struct NamedSnapshotV2: Tag, ExplicitComponentRegistration {
    @State private var label = "fresh"
    @State private var enabled = true
    @State private var count = 0

    static let componentIdentifier = "example.named-snapshot.v1"
    func registerProperties(_ properties: inout ComponentProperties) {
        properties.state(_label, stableID: "label")
        properties.state(_enabled, stableID: "enabled")
        properties.state(_count, stableID: "count")
    }
    var body: some Tag { Text("\(label):\(count):\(enabled)") }
}

@Suite @MainActor struct RuntimeModernizationTests {
    @Test func navigationLifecycleFinishesOnlyAfterTheRouteCommit() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: NavigationLifecycleProbe(),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        runtime.navigate(to: "/next")

        #expect(backend.counts["navigationWillBegin"] == 1)
        #expect(backend.counts["navigationDidCommit"] == nil)
        #expect(!backend.serializeHTML().contains("/next"))

        scheduler.pump()

        #expect(backend.counts["navigationDidCommit"] == 1)
        #expect(backend.serializeHTML().contains("/next"))
    }

    @Test func historyNavigationUsesTheSamePostCommitBoundary() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: NavigationLifecycleProbe(),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        runtime.handlePopState(url: "/previous")

        #expect(backend.navigationBegins == [true])
        #expect(backend.counts["navigationDidCommit"] == nil)

        scheduler.pump()

        #expect(backend.counts["navigationDidCommit"] == 1)
        #expect(backend.serializeHTML().contains("/previous"))
    }

    @Test func minimalCoverDropsEveryDirtyDescendantOfAnotherDirtyIdentity() {
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: EmptyTag(), scheduleMicrotask: { _ in })
        let parent = NodeIdentity.root.appending(.child(4))
        let child = parent.appending(.child(1))
        let grandchild = child.appending(.child(9))
        let sibling = NodeIdentity.root.appending(.child(8))

        let cover = Set(runtime.minimalCover([grandchild, sibling, child, parent]))

        #expect(cover == [parent, sibling])
    }

    @Test func diagnosticsReportRenderReasonAndLifetimeAfterCommit() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = DiagnosticLog()
        let diagnostics = RuntimeDiagnostics(includeTreeStatistics: true,
                                             includeComponentTree: true) {
            log.events.append($0)
        }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: DiagnosticCounter(),
                              scheduleMicrotask: scheduler.schedule,
                              diagnostics: diagnostics)

        runtime.mount()
        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        scheduler.pump()

        let renders = log.events.compactMap { event -> RuntimeRenderDiagnostic? in
            guard case .render(let render) = event else { return nil }
            return render
        }
        #expect(renders.count == 2)
        #expect(renders[0].kind == .mount)
        #expect(renders[1].kind == .update)
        #expect(renders[1].reasons.contains { reason in
            if case .dependency = reason { return true }
            return false
        })
        #expect(renders[1].lifetimes.stateRows == 1)
        #expect(renders[1].tree?.elements == 1)
        #expect(renders[1].tree?.textNodes == 1)
        #expect(renders[1].componentTree?.map(\.typeName).contains("DiagnosticCounter") == true)
        #expect(renders[1].componentTree?.first?.typeName == "Root")
    }

    @Test func explicitRegistrationLinksStateEnvironmentAndStableSnapshotIdentity() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ExplicitRegistrationCounter(), initialPath: "/registered",
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        #expect(backend.serializeHTML().contains("/registered:0"))
        #expect(runtime._store.rowIdentities.compactMap(\._canonicalString) == [
            "texample.explicit-counter.v1"
        ])

        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        scheduler.pump()
        #expect(backend.serializeHTML().contains("/registered:1"))
    }

    @Test func namedStateSlotsSurviveReorderingAndAddedSlotsAcrossSnapshots() throws {
        let serverBackend = MockBackend()
        let server = Runtime(backend: serverBackend, container: serverBackend.container,
                             root: NamedSnapshotV1(), scheduleMicrotask: { _ in })
        server.mount()
        let rows = server._store._encodeSnapshotRows(modernizationJSONEncode)
        let row = try #require(rows.first)

        let clientBackend = MockBackend()
        let client = Runtime(backend: clientBackend, container: clientBackend.container,
                             root: NamedSnapshotV2(), scheduleMicrotask: { _ in })
        client._store._pendingRows = [row.key: row.value]
        client._store._decodeSlot = modernizationJSONDecode
        client.mount()

        #expect(clientBackend.serializeHTML().contains("persisted:11:true"))
    }

    @Test func adoptionFailureIsDeliveredToTheOptInDiagnosticSink() {
        let base = MockBackend()
        let existing = base.createElement("div")
        base.insert(existing, into: base.container, before: nil)
        let log = DiagnosticLog()
        let diagnostics = RuntimeDiagnostics { log.events.append($0) }
        let adopting = AdoptingBackend(base: base, container: base.container,
                                       diagnostics: diagnostics)
        adopting._assertOnMismatch = false

        _ = adopting.createElement("span")
        #expect(!adopting.finishAdoption())

        guard case .adoption(let event)? = log.events.first else {
            Issue.record("expected an adoption diagnostic")
            return
        }
        #expect(event.outcome == .failed)
        #expect(event.availableNodes == 1)
    }

    @Test func unmountMakesPendingWorkAndFormerListenersInert() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: DiagnosticCounter(),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()
        let listener = findFirst(backend.container, tag: "button")!.events["click"]!

        runtime.dispatch(listener)
        runtime.navigate(to: "/discarded")
        runtime.unmount()
        runtime.dispatch(listener)
        scheduler.pump()

        #expect(!runtime._isMounted)
        #expect(runtime._current == nil)
        #expect(runtime._store.rowCount == 0)
        #expect(runtime._listenerCount == 0)
        #expect(backend.container.children.isEmpty)
        #expect(backend.navigationBegins == [false])
        #expect(backend.counts["navigationDidCommit"] == nil)
    }

    @Test func unmountPreservesCallerOwnedContainerContentAndRunsDisappearOnce() {
        let backend = MockBackend()
        let unmanaged = backend.createElement("aside")
        backend.insert(unmanaged, into: backend.container, before: nil)
        let log = RuntimeLifetimeLog()
        let runtime = Runtime(
            backend: backend,
            container: backend.container,
            root: Text("managed").onDisappear { log.entries.append("disappear") },
            scheduleMicrotask: { _ in }
        )
        runtime.mount()

        runtime.unmount()
        runtime.unmount()
        runtime.mount()

        #expect(backend.container.children.count == 1)
        #expect(backend.container.children.first === unmanaged)
        #expect(log.entries == ["disappear"])
    }

    @Test func batchedSiblingCleanupKeepsAllTeardownsAheadOfNewAppearances() throws {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = RuntimeLifetimeLog()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: BatchedEffectFixture(log: log),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()
        log.entries.removeAll()

        let buttons = findAll(backend.container, tag: "button")
        #expect(buttons.count == 2)
        for button in buttons {
            runtime.dispatch(try #require(button.events["click"]))
        }
        scheduler.pump()

        #expect(Set(log.entries.prefix(2)) == ["left-old-disappear", "right-old-disappear"])
        #expect(Set(log.entries.suffix(2)) == ["left-new-appear", "right-new-appear"])
    }

    @Test func bindingRetainedAfterRemovalCannotScheduleStaleRuntimeWork() throws {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let holder = BindingHolder()
        let log = DiagnosticLog()
        let diagnostics = RuntimeDiagnostics { log.events.append($0) }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: RemovedStateFixture(holder: holder),
                              scheduleMicrotask: scheduler.schedule,
                              diagnostics: diagnostics)
        runtime.mount()

        let buttons = findAll(backend.container, tag: "button")
        runtime.dispatch(try #require(buttons.last?.events["click"]))
        runtime.dispatch(try #require(buttons.first?.events["click"]))
        scheduler.pump()
        let rendersAfterRemoval = log.events.count

        holder.binding?.wrappedValue = 9
        scheduler.pump()

        #expect(log.events.count == rendersAfterRemoval)
        #expect(!backend.serializeHTML().contains("capture"))
    }
}
