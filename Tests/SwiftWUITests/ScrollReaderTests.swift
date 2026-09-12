import Observation
import Testing
@testable import SwiftWUI

@MainActor
private final class ScrollReaderLog {
    nonisolated deinit { }
    var proxies: [ScrollProxy] = []
}

private struct ScrollPrependFixture: Tag {
    let log: ScrollReaderLog
    @State private var rows = [2, 3]

    var body: some Tag {
        ScrollReader(container: .element(id: "timeline")) { proxy in
            let _ = log.proxies.append(proxy)
            Div(id: "timeline") {
                ForEach(rows, id: \.self) { row in
                    Div(id: "message:\(row)") { Text("row \(row)") }
                }
                Button("prepend") {
                    let anchor = proxy.captureAnchor(
                        in: rows.map { "message:\($0)" }
                    )
                    rows.insert(1, at: 0)
                    if let anchor { proxy.restore(anchor) }
                }
            }
        }
    }
}

private struct ScrollChildIDFixture: Tag {
    @State private var alternate = false

    var body: some Tag {
        Div {
            Div(id: alternate ? "new:id" : "old:id") { Text("anchor") }
            Button("rename") { alternate.toggle() }
        }
    }
}

private struct ScrollChildHost: Tag {
    let log: ScrollReaderLog

    var body: some Tag {
        ScrollReader(container: .window) { proxy in
            let _ = log.proxies.append(proxy)
            ScrollChildIDFixture()
        }
    }
}

@MainActor
private final class NestedScrollLog {
    nonisolated deinit { }
    var outer: ScrollProxy?
    var inner: ScrollProxy?
}

private struct NestedScrollFixture: Tag {
    let log: NestedScrollLog

    var body: some Tag {
        ScrollReader(container: .window) { outer in
            let _ = { log.outer = outer }()
            Div(id: "outer-row") { Text("outer") }
            ScrollReader(container: .window) { inner in
                let _ = { log.inner = inner }()
                Div(id: "inner-row") { Text("inner") }
            }
        }
    }
}

@MainActor @Observable
private final class ScrollObservedModel {
    nonisolated deinit { }
    var elementID = "observed-old"
}

private struct ObservedScrollFixture: Tag {
    let model: ScrollObservedModel
    let log: ScrollReaderLog

    var body: some Tag {
        ScrollReader(container: .window) { proxy in
            let _ = log.proxies.append(proxy)
            Div(id: model.elementID) { Text(model.elementID) }
        }
    }
}

@MainActor @Observable
private final class ScrollTransactionModel {
    nonisolated deinit { }
    var opacity = 0.5
}

private struct ScrollTransactionFixture: Tag {
    let model: ScrollTransactionModel

    var body: some Tag {
        ScrollReader(container: .window) { _ in
            Div(class: "scroll-animated").style("opacity", cssNumber(model.opacity))
        }
    }
}

private struct StyledScrollFixture: Tag, Styled {
    @RulesBuilder var styles: [Rule] {
        Rule(class: "reader-owned") { $0.padding(.px(3)) }
    }

    var body: some Tag {
        ScrollReader(container: .window) { _ in
            Div(class: "reader-owned") { Text("styled") }
        }
    }
}

@Suite @MainActor
struct ScrollReaderTests {
    @Test func prependRestoresAgainstUpdatedMountedHostsAfterCommit() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollReaderLog()
        var restored: (container: MockNode, anchor: MockNode, offset: Double)?
        var orderObservedDuringRestore: [String] = []
        backend.scrollCapture = { target, candidates in
            guard case .element(let container) = target,
                  container.attrs["id"] == "timeline",
                  candidates.map({ $0.attrs["id"] ?? "" }) == ["message:2", "message:3"]
            else { return nil }
            return .init(index: 0, offsetFromVisibleTop: -12.5)
        }
        backend.scrollRestore = { target, anchor, offset in
            guard case .element(let container) = target else { return }
            orderObservedDuringRestore = findAll(backend.container, tag: "div")
                .compactMap { $0.attrs["id"] }
            restored = (container, anchor, offset)
        }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollPrependFixture(log: log),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)

        #expect(restored == nil)
        #expect(findAll(backend.container, tag: "div").compactMap { $0.attrs["id"] }
            == ["timeline", "message:2", "message:3"])

        scheduler.pump()

        #expect(findAll(backend.container, tag: "div").compactMap { $0.attrs["id"] }
            == ["timeline", "message:1", "message:2", "message:3"])
        #expect(restored?.container.attrs["id"] == "timeline")
        #expect(restored?.anchor.attrs["id"] == "message:2")
        #expect(restored?.offset == -12.5)
        #expect(orderObservedDuringRestore == ["timeline", "message:1", "message:2", "message:3"])
        #expect(log.proxies.count >= 2)
        #expect(log.proxies.allSatisfy { $0 === log.proxies[0] })
    }

    @Test func childOnlyRerenderRefreshesLogicalAnchorLookup() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollReaderLog()
        var capturedIDs: [[String]] = []
        backend.scrollCapture = { _, candidates in
            capturedIDs.append(candidates.compactMap { $0.attrs["id"] })
            return .init(index: 0, offsetFromVisibleTop: 4)
        }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollChildHost(log: log),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        #expect(log.proxies[0].captureAnchor(in: ["old:id"])?.elementID == "old:id")
        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        scheduler.pump()
        #expect(log.proxies[0].captureAnchor(in: ["new:id"])?.elementID == "new:id")
        #expect(log.proxies[0].captureAnchor(in: ["old:id"]) == nil)
        #expect(capturedIDs == [["old:id"], ["new:id"]])
    }

    @Test func nestedReaderAndDuplicateIDsStayInsideTheirLogicalScopes() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = NestedScrollLog()
        var candidateCalls: [[String]] = []
        backend.scrollCapture = { _, candidates in
            candidateCalls.append(candidates.compactMap { $0.attrs["id"] })
            return candidates.isEmpty ? nil : .init(index: 0, offsetFromVisibleTop: 0)
        }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Div {
                                  NestedScrollFixture(log: log)
                                  ScrollReader(container: .window) { proxy in
                                      Div(id: "duplicate")
                                      Div(id: "duplicate")
                                      Div(id: "unique")
                                      Button("capture") {
                                          _ = proxy.captureAnchor(in: ["duplicate", "duplicate", "unique"])
                                      }
                                  }
                              }, scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        #expect(log.outer?.captureAnchor(in: ["inner-row", "outer-row"])?.elementID == "outer-row")
        #expect(log.inner?.captureAnchor(in: ["outer-row", "inner-row"])?.elementID == "inner-row")
        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)

        #expect(candidateCalls == [["outer-row"], ["inner-row"], ["unique"]])
    }

    @Test func elementContainerRejectsSiblingAnchorsAndNeverFallsBackToWindow() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollReaderLog()
        var captures = 0
        backend.scrollCapture = { _, _ in captures += 1; return .init(index: 0, offsetFromVisibleTop: 0) }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollReader(container: .element(id: "scrollport")) { proxy in
                                  let _ = log.proxies.append(proxy)
                                  Div(id: "scrollport") { Div(id: "inside") }
                                  Div(id: "sibling")
                              }, scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        #expect(log.proxies[0].captureAnchor(in: ["sibling"]) == nil)
        #expect(captures == 0)
    }

    @Test func metricsUseTheResolvedTargetAndRejectMalformedSnapshots() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollReaderLog()
        var valid = false
        backend.scrollMetrics = { target in
            guard case .window = target else { return nil }
            if valid {
                return .init(x: -1.5, y: 12.25, viewportWidth: 320, viewportHeight: 480,
                             contentWidth: 640, contentHeight: 900)
            }
            return .init(x: 0, y: 0, viewportWidth: -1, viewportHeight: 480,
                         contentWidth: 640, contentHeight: 900)
        }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ScrollReader(container: .window) { proxy in
                                  let _ = log.proxies.append(proxy)
                                  Div(id: "row[1]:odd")
                              }, scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        #expect(log.proxies[0].metrics() == nil)
        valid = true
        #expect(log.proxies[0].metrics() == .init(
            x: -1.5, y: 12.25, viewportWidth: 320, viewportHeight: 480,
            contentWidth: 640, contentHeight: 900
        ))
    }

    @Test func observableReadsInsideContentClosureRerenderTheReader() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = ScrollReaderLog()
        let model = ScrollObservedModel()
        backend.scrollCapture = { _, candidates in
            .init(index: 0, offsetFromVisibleTop: Double(candidates.count))
        }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ObservedScrollFixture(model: model, log: log),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        model.elementID = "observed-new"
        scheduler.pump()

        #expect(log.proxies[0].captureAnchor(in: ["observed-new"])?.elementID == "observed-new")
        #expect(backend.serializeHTML().contains("observed-new"))
        #expect(log.proxies.allSatisfy { $0 === log.proxies[0] })
    }

    @Test func readerAppliesCapturedTransactionInScopedAndFullPasses() {
        let scopedBackend = MockBackend(), fullBackend = MockBackend()
        let scopedScheduler = TestScheduler(), fullScheduler = TestScheduler()
        let scopedModel = ScrollTransactionModel(), fullModel = ScrollTransactionModel()
        let scoped = Runtime(backend: scopedBackend, container: scopedBackend.container,
                             root: ScrollTransactionFixture(model: scopedModel),
                             scheduleMicrotask: scopedScheduler.schedule)
        let full = Runtime(backend: fullBackend, container: fullBackend.container,
                           root: ScrollTransactionFixture(model: fullModel),
                           scheduleMicrotask: fullScheduler.schedule)
        full._forceFullPasses = true
        scoped.mount()
        full.mount()

        withAnimation(.linear(duration: 1)) {
            scopedModel.opacity = 1
            fullModel.opacity = 1
        }
        scopedScheduler.pump()
        fullScheduler.pump()

        #expect(scopedBackend.animations.count == 1)
        #expect(fullBackend.animations.count == 1)
        #expect(scopedBackend.animations.map(\.request) == fullBackend.animations.map(\.request))
    }

    @Test func readerPreservesStyledAndVisibilityScopes() {
        let marker = scopeMarker(forTypeName: String(reflecting: StyledScrollFixture.self))
        let html = HTMLRenderer.render(StyledScrollFixture())
        #expect(html.contains("reader-owned \(marker)"))

        let backend = MockBackend()
        let scheduler = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Div {
                                  ScrollReader(container: .window) { _ in
                                      Span().onVisibilityChange(root: .ancestor(id: "scope")) { _ in }
                                  }
                              }.visibilityRoot(id: "scope"),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()
        guard case .ancestor(let host) = backend.visibilityObservations[0].root else {
            Issue.record("Expected inherited configured-visibility root")
            return
        }
        #expect(host === findFirst(backend.container, tag: "div"))
    }
}
