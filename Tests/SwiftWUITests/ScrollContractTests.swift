#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
@testable import SwiftWUI

@Suite @MainActor struct ScrollContractTests {
    private let metrics = ScrollMetrics(x: -12.5, y: 24.75, viewportWidth: 300,
                                        viewportHeight: 200, contentWidth: 600, contentHeight: 1000)

    @Test func snapshotsRoundTripWithoutRounding() throws {
        let encoded = try JSONEncoder().encode(metrics)
        #expect(try JSONDecoder().decode(ScrollMetrics.self, from: encoded) == metrics)
        let anchor = ScrollAnchor(elementID: "message:1[part]", offsetFromVisibleTop: -19.25)
        #expect(try JSONDecoder().decode(ScrollAnchor.self, from: JSONEncoder().encode(anchor)) == anchor)
        #expect(metrics.x == -12.5 && metrics.y == 24.75)
        #expect(ScrollEvent(x: 1, y: 2).y == 2)
        #expect(ScrollBehavior.auto.css == "auto")
    }

    @Test func invalidGeometryIsNotAUsableSnapshot() {
        #expect(metrics._isValid)
        for value in [Double.nan, .infinity, -.infinity] {
            #expect(!ScrollMetrics(x: value, y: 0, viewportWidth: 1, viewportHeight: 1,
                                   contentWidth: 1, contentHeight: 1)._isValid)
            #expect(!ScrollMetrics(x: 0, y: 0, viewportWidth: 1, viewportHeight: value,
                                   contentWidth: 1, contentHeight: 1)._isValid)
        }
        #expect(!ScrollMetrics(x: 0, y: 0, viewportWidth: -1, viewportHeight: 1,
                               contentWidth: 1, contentHeight: 1)._isValid)
    }

    @Test func inertProxyHasNoGeometry() {
        let proxy = ScrollProxy.inert()
        #expect(proxy.metrics() == nil)
        #expect(proxy.captureAnchor(in: ["row"]) == nil)
        proxy.restore(.init(elementID: "row", offsetFromVisibleTop: 0))
        proxy.scrollToEnd()
    }

    @Test func invalidAnchorNeverSubmits() {
        var count = 0
        let proxy = ScrollProxy(metrics: { nil }, capture: { _ in nil }, submit: { _ in count += 1 })
        proxy.restore(.init(elementID: "row", offsetFromVisibleTop: .nan))
        proxy.restore(.init(elementID: "row", offsetFromVisibleTop: .infinity))
        proxy.restore(.init(elementID: "", offsetFromVisibleTop: 0))
        #expect(count == 0)
    }

    @Test func readsAreFreshAndCommandsPreserveIntent() {
        var snapshot = metrics
        var commands: [ScrollCommand] = []
        let anchor = ScrollAnchor(elementID: "row", offsetFromVisibleTop: -3)
        let proxy = ScrollProxy(metrics: { snapshot }, capture: { ids in
            ids == ["row"] ? anchor : nil
        }, submit: { commands.append($0) })
        #expect(proxy.metrics() == metrics)
        snapshot = .init(x: 0, y: 75, viewportWidth: 200, viewportHeight: 100,
                         contentWidth: 200, contentHeight: 2000)
        #expect(proxy.metrics()?.y == 75)
        #expect(proxy.captureAnchor(in: ["row"]) == anchor)
        proxy.restore(anchor); proxy.scrollToEnd(); proxy.scrollToEnd(behavior: .smooth)
        #expect(commands.count == 3)
        if case .restore(let actual) = commands[0] { #expect(actual == anchor) }
        else { Issue.record("Expected restore command") }
        if case .end(.instant) = commands[1] {} else { Issue.record("Expected default instant") }
        if case .end(.smooth) = commands[2] {} else { Issue.record("Expected explicit smooth") }
    }

    @Test func adoptingBackendForwardsAllScrollOperations() {
        let base = MockBackend()
        let row = base.createElement("div")
        base.insert(row, into: base.container, before: nil)
        let backend = AdoptingBackend(base: base, container: base.container)
        _ = backend.createElement("div")
        #expect(backend.finishAdoption())
        var calls: [String] = []
        base.scrollMetrics = { target in
            if case .element(let host) = target { #expect(host === row) }
            else { Issue.record("Expected element target") }
            calls.append("metrics"); return metrics
        }
        base.scrollCapture = { target, hosts in
            if case .window = target {} else { Issue.record("Expected window target") }
            #expect(hosts.count == 1 && hosts[0] === row)
            calls.append("capture"); return .init(index: 0, offsetFromVisibleTop: -7)
        }
        base.scrollRestore = { _, host, offset in
            #expect(host === row && offset == -7); calls.append("restore")
        }
        base.scrollEnd = { _, behavior in
            #expect(behavior == .smooth); calls.append("end")
        }
        #expect(backend._scrollMetrics(in: .element(row)) == metrics)
        #expect(backend._captureScrollAnchor(in: .window, candidates: [row])?.offsetFromVisibleTop == -7)
        backend._restoreScrollAnchor(in: .window, element: row, offset: -7)
        backend._scrollToEnd(in: .element(row), behavior: .smooth)
        #expect(calls == ["metrics", "capture", "restore", "end"])
    }

    @Test func legacyBackendDefaultsDoNotFabricateGeometry() {
        let backend = LegacyScrollBackend()
        #expect(backend._scrollMetrics(in: .window) == nil)
        #expect(backend._captureScrollAnchor(in: .element(0), candidates: [1]) == nil)
        backend._restoreScrollAnchor(in: .element(0), element: 1, offset: 10)
        backend._scrollToEnd(in: .element(0), behavior: .instant)
    }
}

@MainActor private final class LegacyScrollBackend: RendererBackend {
    nonisolated deinit { }
    typealias HostNode = Int
    func createElement(_ tag: String) -> Int { 0 }
    func createTextNode(_ text: String) -> Int { 0 }
    func setText(_ node: Int, _ text: String) {}
    func setAttribute(_ node: Int, name: String, value: String) {}
    func removeAttribute(_ node: Int, name: String) {}
    func setProperty(_ node: Int, name: String, value: PropertyValue) {}
    func setEventListener(_ node: Int, event: String, id: ListenerID) {}
    func removeEventListener(_ node: Int, event: String) {}
    func insert(_ child: Int, into parent: Int, before anchor: Int?) {}
    func remove(_ child: Int, from parent: Int) {}
    func setStylesheet(_ text: String) {}
    func pushState(path: String) {}
    func replaceState(path: String) {}
    func historyBack() {}
    func setTitle(_ title: String) {}
    func setMetaTags(_ tags: [MetaTag]) {}
    func setLinks(_ links: [LinkTag]) {}
    func childCount(of node: Int) -> Int { 0 }
    func child(of node: Int, at index: Int) -> Int { 0 }
    func tagName(of node: Int) -> String? { nil }
    func setDocumentLanguage(_ lang: String, dir: String?) {}
    func preferredLanguages() -> [String] { [] }
    func readCookie(_ name: String) -> String? { nil }
    func writeCookie(_ name: String, value: String, maxAgeDays: Int, secure: Bool) {}
}
