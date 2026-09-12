#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

@MainActor
final class ScrollHydrationLog {
    nonisolated deinit { }

    var proxies: [ScrollProxy] = []
    var bodyMetrics: [ScrollMetrics?] = []
    var bodyAnchors: [ScrollAnchor?] = []
    var lifecycleMetrics: [ScrollMetrics?] = []
    var lifecycleAnchors: [ScrollAnchor?] = []
    var lifecycleRuns = 0
}

private struct ScrollAdoptionFixture: Tag {
    let log: ScrollHydrationLog
    let issueLifecycleCommand: Bool

    var body: some Tag {
        ScrollReader(container: .element(id: "timeline")) { proxy in
            let _ = log.proxies.append(proxy)
            let _ = log.bodyMetrics.append(proxy.metrics())
            let _ = log.bodyAnchors.append(proxy.captureAnchor(in: ["row"]))
            let _ = proxy.scrollToEnd()
            Div(id: "timeline") {
                Div(id: "row") { Text("row") }
            }.onAppear {
                guard issueLifecycleCommand else { return }
                log.lifecycleRuns += 1
                log.lifecycleMetrics.append(proxy.metrics())
                log.lifecycleAnchors.append(proxy.captureAnchor(in: ["row"]))
                proxy.scrollToEnd()
            }
        }
    }
}

private struct ScrollRenderAttemptFixture: Tag {
    let log: ScrollHydrationLog
    @State private var revision = 0

    var body: some Tag {
        ScrollReader(container: .window) { proxy in
            let _ = log.proxies.append(proxy)
            let _ = log.bodyMetrics.append(proxy.metrics())
            let _ = log.bodyAnchors.append(proxy.captureAnchor(in: ["row"]))
            let _ = proxy.scrollToEnd()
            Div(id: "row") {
                Button("render \(revision)") { revision += 1 }
            }
        }
    }
}

struct ScrollSnapshotFixture: Tag {
    @State var metrics: ScrollMetrics? = nil
    @State var anchor: ScrollAnchor? = nil
    let log: ScrollHydrationLog
    let issueLifecycleCommand: Bool

    var body: some Tag {
        ScrollReader(container: .window) { proxy in
            let _ = log.proxies.append(proxy)
            let _ = log.bodyMetrics.append(proxy.metrics())
            let _ = log.bodyAnchors.append(proxy.captureAnchor(in: ["timeline"]))
            let _ = proxy.scrollToEnd()
            Div(id: "timeline") { Span { Text("preserved") } }
                .onAppear {
                    if issueLifecycleCommand { proxy.scrollToEnd() }
                }
        }
    }
}

@Suite @MainActor
struct ScrollHydrationTests {
    private let expectedMetrics = ScrollMetrics(
        x: -2.5, y: 41.25,
        viewportWidth: 320, viewportHeight: 480,
        contentWidth: 640, contentHeight: 1600
    )
    private let expectedAnchor = ScrollAnchor(
        elementID: "message:1[part]", offsetFromVisibleTop: -13.75
    )

    @Test func provisionalCommandDoesNotRescheduleAnUndrainableSynchronousFlush() {
        let backend = MockBackend()
        var endCalls = 0
        backend.scrollEnd = { _, _ in endCalls += 1 }
        let log = ScrollHydrationLog()
        var scheduledCallbacks = 0
        let runtime = Runtime(
            backend: backend, container: backend.container,
            root: ScrollAdoptionFixture(log: log, issueLifecycleCommand: true),
            scheduleMicrotask: { job in
                scheduledCallbacks += 1
                if scheduledCallbacks < 4 { job() }
            }
        )
        runtime._deferScrollUntilAdoption()

        runtime.mount()

        #expect(scheduledCallbacks == 1)
        #expect(endCalls == 0)
    }

    @Test func provisionalReadsStayNilAndLifecycleCommandWaitsForAcceptance() throws {
        let server = MockBackend()
        let serverLog = ScrollHydrationLog()
        let serverRuntime = Runtime(
            backend: server, container: server.container,
            root: ScrollAdoptionFixture(log: serverLog, issueLifecycleCommand: true),
            scheduleMicrotask: { _ in }
        )
        serverRuntime._effects._buildMode = true
        serverRuntime.mount()

        let browser = MockBackend()
        parseHTMLSubset(server.serializeHTML(), into: browser)
        var metricsCalls = 0
        var captureCalls = 0
        var endCalls = 0
        browser.scrollMetrics = { target in
            metricsCalls += 1
            guard case .element(let host) = target else {
                Issue.record("Expected the adopted element scrollport")
                return nil
            }
            #expect(host.attrs["id"] == "timeline")
            return expectedMetrics
        }
        browser.scrollCapture = { target, candidates in
            captureCalls += 1
            guard case .element(let host) = target else {
                Issue.record("Expected the adopted element scrollport")
                return nil
            }
            #expect(host.attrs["id"] == "timeline")
            #expect(candidates.map { $0.attrs["id"] } == ["row"])
            return .init(index: 0, offsetFromVisibleTop: -8)
        }
        browser.scrollEnd = { target, behavior in
            guard case .element(let host) = target else {
                Issue.record("Expected the adopted element scrollport")
                return
            }
            #expect(host.attrs["id"] == "timeline")
            #expect(behavior == .instant)
            endCalls += 1
        }

        let log = ScrollHydrationLog()
        let scheduler = TestScheduler()
        let adopting = AdoptingBackend(base: browser, container: browser.container)
        let runtime = Runtime(
            backend: adopting, container: browser.container,
            root: ScrollAdoptionFixture(log: log, issueLifecycleCommand: true),
            scheduleMicrotask: scheduler.schedule
        )
        runtime._deferScrollUntilAdoption()
        runtime.mount()

        #expect(log.bodyMetrics == [nil])
        #expect(log.bodyAnchors == [nil])
        #expect(log.lifecycleRuns == 1)
        #expect(log.lifecycleMetrics == [nil])
        #expect(log.lifecycleAnchors == [nil])
        #expect(metricsCalls == 0 && captureCalls == 0 && endCalls == 0)

        #expect(adopting.finishAdoption())
        runtime._acceptScrollAdoption()
        let proxy = try #require(log.proxies.first)
        #expect(proxy.metrics() == expectedMetrics)
        #expect(proxy.captureAnchor(in: ["row"]) == .init(elementID: "row", offsetFromVisibleTop: -8))
        #expect(metricsCalls == 1 && captureCalls == 1 && endCalls == 0)

        scheduler.pump()
        #expect(endCalls == 1)
        #expect(browser.counts["createElement"] == nil)
        #expect(browser.counts["createTextNode"] == nil)
    }

    @Test func rejectedAdoptionCancelsHeldCommandAndOldProxyCannotReachColdFallback() throws {
        let server = MockBackend()
        let serverRuntime = Runtime(
            backend: server, container: server.container,
            root: ScrollAdoptionFixture(log: ScrollHydrationLog(), issueLifecycleCommand: false),
            scheduleMicrotask: { _ in }
        )
        serverRuntime._effects._buildMode = true
        serverRuntime.mount()

        let browser = MockBackend()
        parseHTMLSubset(server.serializeHTML(), into: browser)
        findFirst(browser.container, tag: "div")?.tag = "section"
        var metricsCalls = 0
        var captureCalls = 0
        var endCalls = 0
        browser.scrollMetrics = { _ in
            metricsCalls += 1
            return expectedMetrics
        }
        browser.scrollCapture = { _, _ in
            captureCalls += 1
            return .init(index: 0, offsetFromVisibleTop: -4)
        }
        browser.scrollEnd = { _, _ in endCalls += 1 }

        let scheduler = TestScheduler()
        let rejectedLog = ScrollHydrationLog()
        let adopting = AdoptingBackend(base: browser, container: browser.container)
        adopting._assertOnMismatch = false
        var rejected: Runtime<AdoptingBackend<MockBackend>>? = Runtime(
            backend: adopting, container: browser.container,
            root: ScrollAdoptionFixture(log: rejectedLog, issueLifecycleCommand: true),
            scheduleMicrotask: scheduler.schedule
        )
        weak let weakRejected = rejected
        rejected?._deferScrollUntilAdoption()
        rejected?.mount()
        let oldProxy = try #require(rejectedLog.proxies.first)

        #expect(!adopting.finishAdoption())
        #expect(metricsCalls == 0 && captureCalls == 0 && endCalls == 0)
        rejected?._effects._cancelAll()
        #expect(oldProxy.metrics() == nil)
        #expect(oldProxy.captureAnchor(in: ["row"]) == nil)
        oldProxy.scrollToEnd()
        scheduler.pump()
        #expect(metricsCalls == 0 && captureCalls == 0 && endCalls == 0)

        rejected = nil
        #expect(weakRejected == nil)

        for child in browser.container.children {
            browser.remove(child, from: browser.container)
        }
        let coldLog = ScrollHydrationLog()
        let cold = Runtime(
            backend: browser, container: browser.container,
            root: ScrollAdoptionFixture(log: coldLog, issueLifecycleCommand: false),
            scheduleMicrotask: scheduler.schedule
        )
        cold.mount()
        let newProxy = try #require(coldLog.proxies.first)
        #expect(newProxy !== oldProxy)
        #expect(newProxy.metrics() == expectedMetrics)
        #expect(newProxy.captureAnchor(in: ["row"]) == .init(elementID: "row", offsetFromVisibleTop: -4))
        newProxy.scrollToEnd()
        scheduler.pump()
        #expect(metricsCalls == 1 && captureCalls == 1 && endCalls == 1)

        oldProxy.scrollToEnd()
        #expect(oldProxy.metrics() == nil)
        #expect(oldProxy.captureAnchor(in: ["row"]) == nil)
        scheduler.pump()
        #expect(metricsCalls == 1 && captureCalls == 1 && endCalls == 1)
    }

    @Test func bodyOperationsStayInertDuringInitialAndActiveRenders() throws {
        let backend = MockBackend()
        var metricsCalls = 0
        var captureCalls = 0
        var endCalls = 0
        backend.scrollMetrics = { _ in metricsCalls += 1; return expectedMetrics }
        backend.scrollCapture = { _, _ in
            captureCalls += 1
            return .init(index: 0, offsetFromVisibleTop: 0)
        }
        backend.scrollEnd = { _, _ in endCalls += 1 }
        let log = ScrollHydrationLog()
        let scheduler = TestScheduler()
        let runtime = Runtime(
            backend: backend, container: backend.container,
            root: ScrollRenderAttemptFixture(log: log),
            scheduleMicrotask: scheduler.schedule
        )

        runtime.mount()
        #expect(metricsCalls == 0 && captureCalls == 0 && endCalls == 0)
        clickFirst(backend, runtime, tag: "button", sched: scheduler)
        #expect(log.bodyMetrics == [nil, nil])
        #expect(log.bodyAnchors == [nil, nil])
        #expect(metricsCalls == 0 && captureCalls == 0 && endCalls == 0)

        let proxy = try #require(log.proxies.first)
        #expect(proxy.metrics() == expectedMetrics)
        #expect(proxy.captureAnchor(in: ["row"]) == .init(elementID: "row", offsetFromVisibleTop: 0))
        proxy.scrollToEnd()
        scheduler.pump()
        #expect(metricsCalls == 1 && captureCalls == 1 && endCalls == 1)
    }

    @Test func ssrIsTransparentAndOptionalSnapshotsSurviveHydrationWithoutProxyState() throws {
        let cases: [(ScrollMetrics?, ScrollAnchor?)] = [
            (nil, nil),
            (expectedMetrics, expectedAnchor),
        ]

        for (metrics, anchor) in cases {
            let server = MockBackend()
            var serverGeometryCalls = 0
            var serverCommandCalls = 0
            server.scrollMetrics = { _ in serverGeometryCalls += 1; return self.expectedMetrics }
            server.scrollCapture = { _, _ in
                serverGeometryCalls += 1
                return .init(index: 0, offsetFromVisibleTop: 0)
            }
            server.scrollEnd = { _, _ in serverCommandCalls += 1 }
            let serverLog = ScrollHydrationLog()
            let runtime = Runtime(
                backend: server, container: server.container,
                root: ScrollSnapshotFixture(
                    metrics: metrics, anchor: anchor, log: serverLog,
                    issueLifecycleCommand: true
                ),
                scheduleMicrotask: { $0() }
            )
            runtime._effects._buildMode = true
            runtime.mount()

            let expectedHTML = "<div id=\"timeline\"><span>preserved</span></div>"
            #expect(server.serializeHTML() == expectedHTML)
            #expect(serverGeometryCalls == 0 && serverCommandCalls == 0)
            #expect(serverLog.bodyMetrics == [nil])
            #expect(serverLog.bodyAnchors == [nil])
            #expect(HTMLRenderer.render(ScrollSnapshotFixture(
                metrics: metrics, anchor: anchor, log: ScrollHydrationLog(),
                issueLifecycleCommand: true
            )) == expectedHTML)

            let rows = runtime._store._encodeSnapshotRows(SnapshotJSON.encodeSlot)
            #expect(rows.count == 1)
            let row = try #require(rows.values.first)
            #expect(row.count == 2)
            #expect(try JSONDecoder().decode([ScrollMetrics?].self, from: Data(row[0].utf8)) == [metrics])
            #expect(try JSONDecoder().decode([ScrollAnchor?].self, from: Data(row[1].utf8)) == [anchor])
            let snapshot = SnapshotJSON.assemble(version: 1, path: "/", rows: rows, tasks: [])
            #expect(!snapshot.contains("ScrollProxy"))
            #expect(!snapshot.contains("ScrollReader"))

            let browser = MockBackend()
            parseHTMLSubset(server.serializeHTML(), into: browser)
            var clientGeometryCalls = 0
            var clientCommandCalls = 0
            browser.scrollMetrics = { _ in clientGeometryCalls += 1; return self.expectedMetrics }
            browser.scrollCapture = { _, _ in
                clientGeometryCalls += 1
                return .init(index: 0, offsetFromVisibleTop: 0)
            }
            browser.scrollEnd = { _, _ in clientCommandCalls += 1 }
            let scheduler = TestScheduler()
            let adopting = AdoptingBackend(base: browser, container: browser.container)
            let client = Runtime(
                backend: adopting, container: browser.container,
                root: ScrollSnapshotFixture(
                    log: ScrollHydrationLog(), issueLifecycleCommand: false
                ),
                scheduleMicrotask: scheduler.schedule
            )
            client._store._pendingRows = rows
            client._store._decodeSlot = { json, type in
                func decode<T: Decodable>(_ type: T.Type) -> (any Decodable)? {
                    (try? JSONDecoder().decode([T].self, from: Data(json.utf8)))?.first
                }
                return _openExistential(type, do: decode)
            }
            client._deferScrollUntilAdoption()
            client.mount()
            #expect(adopting.finishAdoption())
            client._acceptScrollAdoption()
            scheduler.pump()

            #expect(clientGeometryCalls == 0 && clientCommandCalls == 0)
            #expect(client._store._pendingRows.isEmpty)
            let restoredRows = client._store._encodeSnapshotRows(SnapshotJSON.encodeSlot)
            #expect(Set(restoredRows.keys) == Set(rows.keys))
            let restored = try #require(restoredRows.values.first)
            #expect(restored.count == 2)
            #expect(try JSONDecoder().decode([ScrollMetrics?].self, from: Data(restored[0].utf8)) == [metrics])
            #expect(try JSONDecoder().decode([ScrollAnchor?].self, from: Data(restored[1].utf8)) == [anchor])
        }
    }
}
