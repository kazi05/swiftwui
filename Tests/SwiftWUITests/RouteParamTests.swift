import Testing
import Observation
@testable import SwiftWUI

@Observable private final class Recorder {
    var seen: [String] = []
    var loadedFor: String?
}

private struct ParamPage: Tag {
    let recorder: Recorder
    @RouteParam("from") var from: String?
    @RouteParam("count") var count: Int?
    var body: some Tag {
        P { Text(from ?? "none") }
            .onRouteChange(initial: true) { info in
                recorder.seen.append(info.params["from"] ?? "-")
            }
            .staticTask(id: from ?? "") { recorder.loadedFor = from }
    }
}

private struct ParamApp: Tag {
    let recorder: Recorder
    var body: some Tag {
        Router {
            Route("/r/:from") { _ in ParamPage(recorder: recorder) }
        }
    }
}

@Suite @MainActor struct RouteParamTests {
    @Test func typedParamReadsCaptures() {
        let backend = MockBackend()
        let rec = Recorder()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ParamApp(recorder: rec), initialPath: "/r/mcx",
                              scheduleMicrotask: { $0() })
        runtime.mount()
        #expect(backend.serializeHTML().contains("mcx"))   // MockBackend.serializeHTML():223
    }

    @Test func onRouteChangeFiresOnMountAndOnNavigation() {
        let backend = MockBackend()
        let rec = Recorder()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ParamApp(recorder: rec), initialPath: "/r/mcx",
                              scheduleMicrotask: { $0() })
        runtime.mount()
        #expect(rec.seen == ["mcx"])
        runtime.navigate(to: "/r/led")
        #expect(rec.seen == ["mcx", "led"])
    }

    // Load-bearing ordering: the model must have its params BEFORE the build
    // loader runs, otherwise SSG loads with an empty parameter set.
    @Test func routeChangeRunsBeforeBuildTasks() async throws {
        let backend = MockBackend()
        let rec = Recorder()
        var queue: [() -> Void] = []
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ParamApp(recorder: rec), initialPath: "/r/mcx",
                              scheduleMicrotask: { queue.append($0) })
        runtime._effects._buildMode = true
        runtime.mount()
        while !queue.isEmpty { queue.removeFirst()() }
        #expect(rec.seen == ["mcx"])              // already ran
        #expect(rec.loadedFor == nil)             // build task has not run yet
        _ = await runtime._effects._drainBuildTasks(store: runtime._store)
        #expect(rec.loadedFor == "mcx")
    }
}
