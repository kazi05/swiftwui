import JavaScriptKit
import SwiftWUI

private enum ScrollFixtureRetained {
    static var proxy: ScrollProxy?
}

struct ScrollFixture: Tag {
    @State private var readerMounted = true
    @State private var usesWindow = false
    @State private var unavailableContainer = false
    @State private var nativeAnchoring = true
    @State private var rows = Array(0..<200)
    @State private var mediaHeight = 80
    @State private var changedRowHeight = 32
    @State private var metrics: ScrollMetrics?
    @State private var anchor: ScrollAnchor?
    @State private var metricsRevision = 0
    @State private var anchorRevision = 0

    private var container: ScrollContainer {
        if unavailableContainer { return .element(id: "missing-scroll-container") }
        return usesWindow ? .window : .element(id: "scroll-timeline")
    }

    private var mode: String {
        unavailableContainer ? "unavailable" : (usesWindow ? "window" : "card")
    }

    private var orderedRowIDs: [String] {
        rows.map { "row-\($0)" }
    }

    private var timelineStyle: String {
        let anchoring = nativeAnchoring ? "auto" : "none"
        if usesWindow {
            return "width:928px;height:auto;box-sizing:border-box;border-style:solid;" +
                "border-color:#222;border-width:7px 11px 13px 17px;overflow:visible;" +
                "overflow-anchor:\(anchoring);scroll-behavior:smooth;padding:0;margin:0;background:white"
        }
        return "width:420px;height:260px;box-sizing:border-box;border-style:solid;" +
            "border-color:#222;border-width:7px 11px 13px 17px;overflow:scroll;" +
            "overflow-anchor:\(anchoring);scroll-behavior:smooth;padding:0;margin:0;background:white;" +
            "position:fixed;left:8px;top:8px;z-index:1"
    }

    private func rowHeight(_ value: Int) -> Int {
        if value == 90 { return changedRowHeight }
        if value == 110 { return 420 }
        if value == 120 { return mediaHeight }
        return 32
    }

    private func recordAnchor(_ value: ScrollAnchor?) {
        anchor = value
        anchorRevision += 1
    }

    private func capture(_ proxy: ScrollProxy) -> ScrollAnchor? {
        let value = proxy.captureAnchor(in: orderedRowIDs)
        recordAnchor(value)
        return value
    }

    private func prepend(_ proxy: ScrollProxy) {
        let saved = capture(proxy)
        let start = (rows.first ?? 0) - 50
        rows = Array(start..<(start + 50)) + rows
        if let saved { proxy.restore(saved) }
    }

    private func switchContainer(_ proxy: ScrollProxy) {
        let saved = capture(proxy)
        unavailableContainer = false
        usesWindow.toggle()
        if let saved { proxy.restore(saved) }
    }

    private func resizeBeforeRestore(_ proxy: ScrollProxy, media: Bool) {
        let saved = capture(proxy)
        if media { mediaHeight += 137 } else { changedRowHeight += 63 }
        if let saved { proxy.restore(saved) }
    }

    var body: some Tag {
        Div(id: "scroll-reader-controls") {
            Button("Toggle scroll reader") { readerMounted.toggle() }
            Button("Use retained proxy") { ScrollFixtureRetained.proxy?.scrollToEnd() }
        }
        .attribute("style", "position:fixed;right:0;top:0;z-index:10002;background:white")

        if readerMounted {
            ScrollReader(container: container) { proxy in
                Div(id: "scroll-toolbar") {
                    Button("Capture metrics") {
                        metrics = proxy.metrics()
                        metricsRevision += 1
                    }
                    Button("Capture anchor") { _ = capture(proxy) }
                    Button("Capture special anchors") {
                        recordAnchor(proxy.captureAnchor(in: [
                            "missing-anchor", "duplicate-anchor", "duplicate-anchor", "odd ] # : / 💬"
                        ]))
                    }
                    Button("Prepend 50") { prepend(proxy) }
                    Button("Append") { rows.append((rows.last ?? -1) + 1) }
                    Button("Own send to end") {
                        rows.append((rows.last ?? -1) + 1)
                        proxy.scrollToEnd()
                    }
                    Button("Scroll to end") { proxy.scrollToEnd() }
                    Button("Smooth scroll to end") { proxy.scrollToEnd(behavior: .smooth) }
                    Button("Grow media and restore") { resizeBeforeRestore(proxy, media: true) }
                    Button("Grow row and restore") { resizeBeforeRestore(proxy, media: false) }
                    Button("Toggle scroll container") { switchContainer(proxy) }
                    Button("Toggle native anchoring") { nativeAnchoring.toggle() }
                    Button("Toggle unavailable container") { unavailableContainer.toggle() }
                    Button("Restore missing anchor") {
                        proxy.restore(ScrollAnchor(elementID: "missing-anchor", offsetFromVisibleTop: 0))
                    }
                    Button("Restore duplicate anchor") {
                        proxy.restore(ScrollAnchor(elementID: "duplicate-anchor", offsetFromVisibleTop: 0))
                    }
                    Button("Retain proxy") { ScrollFixtureRetained.proxy = proxy }
                    Button("Schedule stale end") {
                        let callback = JSOneshotClosure { _ in
                            proxy.scrollToEnd()
                            return .undefined
                        }
                        _ = JSObject.global.setTimeout!(callback, 500)
                    }
                }
                .attribute("style", "position:fixed;right:0;top:32px;width:350px;z-index:10001;background:white")

                Div(id: "scroll-mode") { Text(mode) }
                    .attribute("style", "position:fixed;right:0;top:180px;z-index:10003;background:white")
                Div(id: "scroll-metrics") { Text(metrics == nil ? "unavailable" : "available") }
                    .attribute("data-revision", "\(metricsRevision)")
                    .attribute("data-available", metrics == nil ? "false" : "true")
                    .attribute("data-x", metrics.map { "\($0.x)" })
                    .attribute("data-y", metrics.map { "\($0.y)" })
                    .attribute("data-viewport-width", metrics.map { "\($0.viewportWidth)" })
                    .attribute("data-viewport-height", metrics.map { "\($0.viewportHeight)" })
                    .attribute("data-content-width", metrics.map { "\($0.contentWidth)" })
                    .attribute("data-content-height", metrics.map { "\($0.contentHeight)" })
                    .attribute("style", "position:fixed;right:0;top:200px;z-index:10003;background:white")
                Div(id: "scroll-anchor") { Text(anchor?.elementID ?? "unavailable") }
                    .attribute("data-revision", "\(anchorRevision)")
                    .attribute("data-available", anchor == nil ? "false" : "true")
                    .attribute("data-element-id", anchor?.elementID)
                    .attribute("data-offset", anchor.map { "\($0.offsetFromVisibleTop)" })
                    .attribute("style", "position:fixed;right:0;top:220px;z-index:10003;background:white")

                Div(id: "scroll-timeline") {
                    ForEach(rows, id: \.self) { value in
                        Div(id: "row-\(value)") { Text("Message \(value)") }
                            .attribute("data-scroll-row", "\(value)")
                            .attribute("style", "width:900px;height:\(rowHeight(value))px;box-sizing:border-box;" +
                                "border-bottom:1px solid #bbb;padding:0;margin:0")
                    }
                    Div(id: "duplicate-anchor") { Text("duplicate one") }
                        .attribute("style", "width:900px;height:32px")
                    Div(id: "duplicate-anchor") { Text("duplicate two") }
                        .attribute("style", "width:900px;height:32px")
                    Div(id: "odd ] # : / 💬") { Text("odd literal anchor") }
                        .attribute("data-scroll-special", "odd")
                        .attribute("style", "width:900px;height:40px")
                }
                .attribute("style", timelineStyle)

                Div(id: "scroll-outer-spacer")
                    .attribute("style", "width:1px;height:900px")
            }
        }
    }
}
