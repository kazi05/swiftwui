import Testing
@testable import SwiftWUI

@Suite @MainActor struct ViewportEffectTests {
    @Test func initialSnapshotIsDeferredAndCancellationIsTerminal() {
        let backend = MockBackend()
        backend.documentVisibilitySnapshot = true
        let sched = TestScheduler()
        var values: [Bool] = []
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Div().onDocumentVisibilityChange { values.append($0) },
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(values.isEmpty)
        sched.pump()
        #expect(values == [true])
        backend.documentVisibilitySink?(false)
        rt._effects._cancelAll()
        sched.pump()
        #expect(values == [true])
    }

    @Test func rejectedAdoptionNeverInstallsSources() {
        let backend = MockBackend()
        backend.documentVisibilitySnapshot = true
        let sched = TestScheduler()
        var calls = 0
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Div().onDocumentVisibilityChange { _ in calls += 1 },
                         scheduleMicrotask: sched.schedule)
        rt._deferViewportEffectsUntilAdoption()
        rt.mount(); sched.pump()
        #expect(backend.documentVisibilitySink == nil)
        rt._effects._cancelAll(); sched.pump()
        #expect(calls == 0 && backend.documentVisibilitySink == nil)
    }

    @Test func acceptedAdoptionAllowsSnapshotOnlyAfterAcceptance() {
        let base = MockBackend()
        let existing = base.createElement("div")
        base.insert(existing, into: base.container, before: nil)
        base.documentVisibilitySnapshot = true
        let adopting = AdoptingBackend(base: base, container: base.container)
        let sched = TestScheduler()
        var values: [Bool] = []
        let rt = Runtime(backend: adopting, container: base.container,
                         root: Div().onDocumentVisibilityChange { values.append($0) },
                         scheduleMicrotask: sched.schedule)
        rt._deferViewportEffectsUntilAdoption()
        rt.mount(); sched.pump()
        #expect(values.isEmpty)
        #expect(adopting.finishAdoption())
        rt._acceptViewportEffectsAdoption(); sched.pump()
        #expect(values == [true])
        #expect(base.container.children.first === existing)
    }

    @Test func buildModeAndDefaultNativeSourceAreSilent() {
        for build in [false, true] {
            let backend = MockBackend()
            if build { backend.documentVisibilitySnapshot = true }
            let sched = TestScheduler()
            var calls = 0
            let rt = Runtime(backend: backend, container: backend.container,
                             root: Div().onDocumentVisibilityChange { _ in calls += 1 }
                                .onVisualViewportChange { _ in calls += 1 },
                             scheduleMicrotask: sched.schedule)
            rt._effects._buildMode = build
            rt.mount(); sched.pump()
            #expect(calls == 0)
            if build {
                #expect(backend.documentVisibilitySink == nil)
                #expect(backend.visualViewportSink == nil)
            }
        }
    }

    @Test func bootProbeNamesBothNewEffects() {
        let findings = BootProbe.check(AnyTag(Div()
            .onDocumentVisibilityChange { _ in }
            .onVisualViewportChange { _ in }))
        let messages = findings.map(\.message).joined(separator: "\n")
        #expect(messages.contains(".onDocumentVisibilityChange"))
        #expect(messages.contains(".onVisualViewportChange"))
    }
}

private struct ViewportStateFixture: Tag {
    @State private var value: VisualViewportMetrics? = nil
    @State private var shown = true
    var body: some Tag {
        Div {
            Button("hide") { shown = false }
            if shown {
                Div().onVisualViewportChange { value = $0 }
            }
            Text(value.map { String($0.height) } ?? "unmeasured")
        }
    }
}

extension ViewportEffectTests {
    @Test func stateChangesOnlyAfterCommitAndUnmountStopsDelivery() {
        let backend = MockBackend()
        backend.visualViewportSnapshot = .init(width: 390, height: 500,
            offsetTop: 20, offsetLeft: 0, scale: 1, layoutViewportHeight: 844)
        let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: ViewportStateFixture(), scheduleMicrotask: sched.schedule)
        rt._deferViewportEffectsUntilAdoption()
        rt.mount(); sched.pump()
        #expect(backend.container.children[0].children.last?.text == "unmeasured")
        rt._acceptViewportEffectsAdoption(); sched.pump()
        #expect(backend.container.children[0].children.last?.text == "500.0")
        let button = backend.container.children[0].children[0]
        rt.dispatch(button.events["click"]!); sched.pump()
        let mutations = backend.counts
        backend.visualViewportSink?(.init(width: 390, height: 400,
            offsetTop: 30, offsetLeft: 0, scale: 2, layoutViewportHeight: 844))
        sched.pump()
        #expect(backend.counts == mutations)
        #expect(backend.container.children[0].children.last?.text == "500.0")
    }
}
