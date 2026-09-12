import Testing
@testable import SwiftWUI

@MainActor
private final class ScrollLifecycleLog {
    nonisolated deinit { }
    var proxies: [ScrollProxy] = []
}

private struct ScrollLifecycleReader: Tag {
    let log: ScrollLifecycleLog

    var body: some Tag {
        ScrollReader(container: .window) { proxy in
            let _ = log.proxies.append(proxy)
            Div(id: "anchor") { Text("anchor") }
        }
    }
}

private struct ScrollRemovalFixture: Tag {
    let log: ScrollLifecycleLog
    @State private var shown = true

    var body: some Tag {
        Div {
            if shown { ScrollLifecycleReader(log: log) }
            Button("toggle") { shown.toggle() }
        }
    }
}

private struct ScrollContainerSwitchFixture: Tag {
    let log: ScrollLifecycleLog
    @State private var alternate = false

    var body: some Tag {
        ScrollReader(container: alternate ? .element(id: "second-port") : .window) { proxy in
            let _ = log.proxies.append(proxy)
            Div(id: "first-port") { Text("first") }
            Div(id: "second-port") { Text("second") }
            Button("switch") {
                proxy.scrollToEnd()
                alternate.toggle()
            }
        }
    }
}

private struct ScrollHostReplacementFixture: Tag {
    let log: ScrollLifecycleLog
    @State private var alternate = false

    var body: some Tag {
        ScrollReader(container: .element(id: "port")) { proxy in
            let _ = log.proxies.append(proxy)
            if alternate {
                Section(id: "port") { Text("replacement") }
            } else {
                Div(id: "port") { Text("original") }
            }
            Button("replace") {
                proxy.scrollToEnd()
                alternate.toggle()
            }
        }
    }
}

private struct ScrollExitGhostFixture: Tag {
    let log: ScrollLifecycleLog
    @State private var alternate = false

    var body: some Tag {
        ScrollReader(container: .element(id: "shared-port")) { proxy in
            let _ = log.proxies.append(proxy)
            if alternate {
                Section(id: "shared-port") { Text("live") }
                    .transition(.opacity.animation(.linear(duration: 1)))
            } else {
                Div(id: "shared-port") { Text("ghost") }
                    .transition(.opacity.animation(.linear(duration: 1)))
            }
            Button("replace-with-exit") {
                proxy.scrollToEnd()
                alternate.toggle()
            }
        }
    }
}

private struct ScrollEffectFixture: Tag {
    let log: ScrollLifecycleLog
    @State private var value = 0

    var body: some Tag {
        ScrollReader(container: .window) { proxy in
            let _ = log.proxies.append(proxy)
            Div { Text("value:\(value)") }
                .onAppear {
                    value = 1
                    proxy.scrollToEnd()
                }
        }
    }
}

private struct ScrollSiblingEffect: Tag {
    let name: String
    let command: (() -> Void)?
    @State private var value = 0

    var body: some Tag {
        Div { Text("\(name):\(value)") }
            .onAppear {
                value = 1
                command?()
            }
    }
}

private struct ScrollSynchronousBatchFixture: Tag {
    let log: ScrollLifecycleLog

    var body: some Tag {
        ScrollReader(container: .window) { proxy in
            let _ = log.proxies.append(proxy)
            ScrollSiblingEffect(name: "left", command: { proxy.scrollToEnd() })
            ScrollSiblingEffect(name: "right", command: nil)
        }
    }
}

private struct ScrollViewTransitionFixture: Tag {
    let log: ScrollLifecycleLog
    @State private var value = 0

    var body: some Tag {
        ScrollReader(container: .window) { proxy in
            let _ = log.proxies.append(proxy)
            Div {
                Text("value:\(value)")
                Button("change") { value += 1 }
            }
        }
    }
}

private struct ScrollRestoreBeforeStateFixture: Tag {
    let log: ScrollLifecycleLog
    @State private var value = 0

    var body: some Tag {
        ScrollReader(container: .window) { proxy in
            let _ = log.proxies.append(proxy)
            Div {
                Div(id: "target") { Text("value:\(value)") }
                Button("restore-first") {
                    proxy.restore(.init(elementID: "target", offsetFromVisibleTop: 8))
                    value = 1
                }
            }
        }
    }
}

@Suite @MainActor
struct ScrollLifecycleTests {
    @Test func idleCommandsAreDeferredLastWinsAndUseExecutionTimeMotionPreference() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollLifecycleLog()
        var calls: [String] = []
        backend.scrollRestore = { _, _, _ in calls.append("restore") }
        backend.scrollEnd = { _, behavior in calls.append("end:\(behavior)") }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollLifecycleReader(log: log),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()
        let proxy = log.proxies[0]

        proxy.restore(.init(elementID: "anchor", offsetFromVisibleTop: 3))
        proxy.scrollToEnd(behavior: .smooth)
        runtime._signals.writer.setReduceMotion(true)

        #expect(calls.isEmpty)
        scheduler.pump()
        #expect(calls == ["end:instant"])
    }

    @Test func backendFollowUpCommandWithSynchronousSchedulerDrainsOnceWithoutRecursiveSpin() {
        let backend = MockBackend()
        let log = ScrollLifecycleLog()
        var scheduledCallbacks = 0
        var overflowed = false
        var endCalls = 0
        let runtime = Runtime(
            backend: backend, container: backend.container,
            root: ScrollLifecycleReader(log: log),
            scheduleMicrotask: { job in
                scheduledCallbacks += 1
                if scheduledCallbacks < 8 {
                    job()
                } else {
                    overflowed = true
                }
            }
        )
        runtime.mount()
        let proxy = log.proxies[0]
        backend.scrollEnd = { _, _ in
            endCalls += 1
            if endCalls == 1 { proxy.scrollToEnd() }
        }

        proxy.scrollToEnd()

        #expect(!overflowed)
        #expect(endCalls == 2)
        #expect(scheduledCallbacks == 3)
    }

    @Test func missingAnchorIsConsumedAfterOneEligibleDrain() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollLifecycleLog()
        var restores = 0
        backend.scrollRestore = { _, _, _ in restores += 1 }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollLifecycleReader(log: log),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        log.proxies[0].restore(.init(elementID: "missing", offsetFromVisibleTop: 0))
        scheduler.pump()
        runtime.flush()

        #expect(restores == 0)
    }

    @Test func removalInvalidatesOldProxyAndReinsertionCreatesNewGeneration() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollLifecycleLog()
        var ends = 0
        backend.scrollEnd = { _, _ in ends += 1 }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollRemovalFixture(log: log),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()
        let stale = log.proxies[0]
        let button = findFirst(backend.container, tag: "button")!

        runtime.dispatch(button.events["click"]!)
        scheduler.pump()
        stale.scrollToEnd()
        scheduler.pump()
        #expect(ends == 0)

        runtime.dispatch(button.events["click"]!)
        scheduler.pump()
        let fresh = log.proxies.last!
        #expect(fresh !== stale)
        fresh.scrollToEnd()
        scheduler.pump()
        #expect(ends == 1)
    }

    @Test func queuedCommandUsesFinalContainerConfigurationAndReplacementHost() {
        for replacement in [false, true] {
            let backend = MockBackend()
            let scheduler = TestScheduler()
            let log = ScrollLifecycleLog()
            var target: MockNode?
            backend.scrollEnd = { value, _ in
                guard case .element(let host) = value else { return }
                target = host
            }
            let root: AnyTag = replacement
                ? AnyTag(ScrollHostReplacementFixture(log: log))
                : AnyTag(ScrollContainerSwitchFixture(log: log))
            let runtime = Runtime(backend: backend, container: backend.container,
                                  root: root, scheduleMicrotask: scheduler.schedule)
            runtime.mount()
            runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
            scheduler.pump()

            if replacement {
                #expect(target?.tag == "section")
                #expect(target?.attrs["id"] == "port")
            } else {
                #expect(target?.attrs["id"] == "second-port")
            }
            #expect(log.proxies.allSatisfy { $0 === log.proxies[0] })
        }
    }

    @Test func exitGhostSharingIDCannotShadowTheLiveReplacementHost() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollLifecycleLog()
        var target: MockNode?
        backend.scrollEnd = { value, _ in
            guard case .element(let host) = value else { return }
            target = host
        }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollExitGhostFixture(log: log),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        scheduler.pump()

        let duplicatedHosts = backend.container.children.filter { $0.attrs["id"] == "shared-port" }
        #expect(duplicatedHosts.count == 2)
        #expect(duplicatedHosts.contains { $0.tag == "div" && $0.attrs["inert"] == "" })
        #expect(target?.tag == "section")
        #expect(target?.attrs["inert"] == nil)
        #expect(runtime._exitingCount == 1)
    }

    @Test func runtimeCancellationDiscardsQueuedCommandsAndInvalidatesProxy() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollLifecycleLog()
        var ends = 0
        backend.scrollEnd = { _, _ in ends += 1 }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollLifecycleReader(log: log),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()
        let proxy = log.proxies[0]

        proxy.scrollToEnd()
        runtime._effects._cancelAll()
        scheduler.pump()
        proxy.scrollToEnd()
        scheduler.pump()

        #expect(ends == 0)
        #expect(proxy.metrics() == nil)
    }

    @Test func retainedProxyBecomesInertAfterRuntimeDeallocation() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollLifecycleLog()
        var ends = 0
        backend.scrollMetrics = { _ in
            .init(x: 0, y: 0, viewportWidth: 1, viewportHeight: 1,
                  contentWidth: 2, contentHeight: 2)
        }
        backend.scrollEnd = { _, _ in ends += 1 }
        var runtime: Runtime<MockBackend>? = Runtime(
            backend: backend, container: backend.container,
            root: ScrollLifecycleReader(log: log), scheduleMicrotask: scheduler.schedule
        )
        weak let weakRuntime = runtime
        runtime?.mount()
        let proxy = log.proxies[0]
        #expect(proxy.metrics() != nil)

        runtime = nil
        proxy.scrollToEnd()
        scheduler.pump()

        #expect(weakRuntime == nil)
        #expect(proxy.metrics() == nil)
        #expect(ends == 0)
    }

    @Test func effectStateWriteCommitsBeforeItsScrollCommand() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollLifecycleLog()
        var observedHTML: String?
        backend.scrollEnd = { _, _ in observedHTML = backend.serializeHTML() }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollEffectFixture(log: log),
                              scheduleMicrotask: scheduler.schedule)

        runtime.mount()
        #expect(observedHTML == nil)
        scheduler.pump()

        #expect(observedHTML?.contains("value:1") == true)
    }

    @Test func restoreQueuedBeforeStateStillObservesTheCommittedState() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollLifecycleLog()
        var observedHTML: String?
        backend.scrollRestore = { _, _, _ in observedHTML = backend.serializeHTML() }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollRestoreBeforeStateFixture(log: log),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        #expect(observedHTML == nil)
        scheduler.pump()

        #expect(observedHTML?.contains("value:1") == true)
    }

    @Test func synchronousSchedulerCannotDrainBetweenSiblingEffectPasses() {
        let backend = MockBackend()
        let log = ScrollLifecycleLog()
        var observedHTML: String?
        backend.scrollEnd = { _, _ in observedHTML = backend.serializeHTML() }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollSynchronousBatchFixture(log: log),
                              scheduleMicrotask: { $0() })

        runtime.mount()

        #expect(observedHTML?.contains("left:1") == true)
        #expect(observedHTML?.contains("right:1") == true)
    }

    @Test func viewTransitionHoldsUntilItsOwnedCommitAndDrainsExactlyOnceInsideUpdate() {
        let backend = MockBackend()
        backend.deferViewTransition = true
        let scheduler = TestScheduler()
        let log = ScrollLifecycleLog()
        var calls: [(html: String, transitionInFlight: Bool)] = []
        var runtime: Runtime<MockBackend>!
        backend.scrollEnd = { _, _ in
            calls.append((backend.serializeHTML(), runtime._viewTransitionInFlight))
        }
        runtime = Runtime(backend: backend, container: backend.container,
                          root: ScrollViewTransitionFixture(log: log),
                          scheduleMicrotask: scheduler.schedule)
        runtime.mount()
        let button = findFirst(backend.container, tag: "button")!

        withViewTransition(.fade) {
            runtime.dispatch(button.events["click"]!)
            log.proxies[0].scrollToEnd()
        }
        scheduler.pump()
        #expect(calls.isEmpty)
        #expect(runtime._viewTransitionInFlight)
        let duplicatedUpdate = backend._heldViewTransitionUpdate

        #expect(backend.runPendingViewTransition())
        duplicatedUpdate?()
        scheduler.pump()

        #expect(calls.count == 1)
        #expect(calls[0].html.contains("value:1"))
        #expect(calls[0].transitionInFlight)
        #expect(!runtime._viewTransitionInFlight)
    }
}
