import Testing
@testable import SwiftWUI

private final class Log { var entries: [String] = [] }

private struct ChangeFixture: Tag {
    let log: Log
    @State var n = 0
    var body: some Tag {
        Div {
            Button("+") { n += 1 }
        }
        .onChange(of: n) { old, new in log.entries.append("change \(old)->\(new)") }
    }
}
private struct AppearFixture: Tag {
    let log: Log
    @State var showChild = true
    var body: some Tag {
        Div {
            if showChild {
                P { "child" }
                    .onAppear { log.entries.append("appear") }
                    .onDisappear { log.entries.append("disappear") }
            }
            Button("t") { showChild.toggle() }
        }
    }
}

@MainActor @Suite struct EffectTests {
    @Test func onChangeFiresWithOldAndNew() {
        let backend = MockBackend(); let sched = TestScheduler()
        let log = Log()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: ChangeFixture(log: log), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(log.entries.isEmpty)                          // initial: false → silent mount
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(log.entries == ["change 0->1"])
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(log.entries == ["change 0->1", "change 1->2"])
    }

    @Test func onChangeInitialFiresOnMount() {
        struct F: Tag {
            let log: Log
            var body: some Tag {
                P { "x" }.onChange(of: 42, initial: true) { o, n in log.entries.append("\(o)/\(n)") }
            }
        }
        let backend = MockBackend()
        let log = Log()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: F(log: log), scheduleMicrotask: { _ in })
        rt.mount()
        #expect(log.entries == ["42/42"])
    }

    @Test func appearAndDisappearFireOnStructuralChange() {
        let backend = MockBackend(); let sched = TestScheduler()
        let log = Log()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: AppearFixture(log: log), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(log.entries == ["appear"])
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(log.entries == ["appear", "disappear"])
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(log.entries == ["appear", "disappear", "appear"])
    }

    @Test func taskStartsAfterCommitAndCancelsOnRemoval() async {
        final class Flags { var started = false; var cancelled = false }
        struct F: Tag {
            let flags: Flags
            @State var show = true
            var body: some Tag {
                Div {
                    if show {
                        P { "p" }.task {
                            flags.started = true
                            await withTaskCancellationHandler {
                                try? await Task.sleep(nanoseconds: 60_000_000_000)
                            } onCancel: {
                                MainActor.assumeIsolated { flags.cancelled = true }
                            }
                        }
                    }
                    Button("t") { show.toggle() }
                }
            }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let flags = Flags()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: F(flags: flags), scheduleMicrotask: sched.schedule)
        rt.mount()
        var spins = 0
        while !flags.started && spins < 100 { await Task.yield(); spins += 1 }
        #expect(flags.started)
        #expect(!flags.cancelled)
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()                                          // sweep → cancel
        #expect(flags.cancelled)                              // onCancel fires synchronously
    }

    @Test func taskIDRestartsOnIDChange() async {
        final class Count { var starts = 0 }
        struct F: Tag {
            let count: Count
            @State var which = 0
            var body: some Tag {
                Div {
                    P { "p" }.task(id: which) { count.starts += 1 }
                    Button("b") { which += 1 }
                }
            }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let count = Count()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: F(count: count), scheduleMicrotask: sched.schedule)
        rt.mount()
        var spins = 0
        while count.starts < 1 && spins < 100 { await Task.yield(); spins += 1 }
        #expect(count.starts == 1)
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        spins = 0
        while count.starts < 2 && spins < 100 { await Task.yield(); spins += 1 }
        #expect(count.starts == 2)                            // restarted with new id
    }

    @Test func effectsNeverRunDuringResolve() {
        // ordering pin: the callback list is returned by reconcile and run
        // post-commit — the DOM already reflects the new tree when it fires.
        let backend = MockBackend(); let sched = TestScheduler()
        let log = Log()
        struct F: Tag {
            let log: Log; let backend: MockBackend
            @State var n = 0
            var body: some Tag {
                Div {
                    P { "\(n)" }
                    Button("+") { n += 1 }
                }
                .onChange(of: n) { _, new in
                    log.entries.append(findAll(backend.container, tag: "p")[0].children[0].text ?? "?")
                }
            }
        }
        let rt = Runtime(backend: backend, container: backend.container,
                         root: F(log: log, backend: backend), scheduleMicrotask: sched.schedule)
        rt.mount()
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(log.entries == ["1"])                         // DOM committed BEFORE effect ran
    }

    @Test func buildModeCollectsBuildTasksAndSkipsClientTasks() async {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: BuildTaskFixture(), scheduleMicrotask: sched.schedule)
        runtime._effects._buildMode = true
        runtime.mount()
        let drained = runtime._effects._drainBuildTasks()
        #expect(drained.count == 1)
        await drained[0].action()
        runtime._effects._recordBuildCompleted(drained[0].id)
        sched.pump()
        #expect(backend.serializeHTML().contains("from-loader"))
        #expect(!backend.serializeHTML().contains("client-task-ran"))
        #expect(runtime._effects._completedBuildKeys.count == 1)
    }

    @Test func skipSetConsumesBuildTaskOnce() async throws {
        // Boot with the loader's canonical key in the skip set: the .build task
        // must not run; a normal .client task on the same tree still runs.
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: BuildTaskFixture(), scheduleMicrotask: sched.schedule)
        // Key discovery: run a probe first to learn the loader's canonical id.
        let probeBackend = MockBackend()
        let probe = Runtime(backend: probeBackend, container: probeBackend.container,
                            root: BuildTaskFixture(), scheduleMicrotask: { _ in })
        probe._effects._buildMode = true
        probe.mount()
        let key = probe._effects._drainBuildTasks()[0].id._canonicalString!
        runtime._effects._skipBuildTaskKeys = [key]
        runtime.mount()
        try await Task.sleep(nanoseconds: 50_000_000)     // let the .client Task land
        sched.pump()
        let html = backend.serializeHTML()
        #expect(html.contains("client-task-ran"))          // .client ran
        #expect(runtime._effects._skipBuildTaskKeys.isEmpty)   // skip entry consumed
    }
}

private struct BuildTaskFixture: Tag {
    @State var loaded = "initial"
    var body: some Tag {
        Div { Text(loaded) }
            .staticTask { loaded = "from-loader" }
            .task { loaded = "client-task-ran" }        // .client — must NOT run in build mode
    }
}
