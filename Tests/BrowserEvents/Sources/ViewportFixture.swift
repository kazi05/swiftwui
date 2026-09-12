import JavaScriptKit
import SwiftWUI
import SwiftWUIDOM

struct ViewportFixture: Tag {
    @State private var mounted: Bool
    @State private var shifted = false

    init(startMounted: Bool = true) {
        _mounted = State(wrappedValue: startMounted)
    }

    private func record(_ name: String, _ value: JSValue) {
        _ = JSObject.global.__viewportProbe.object![name].object!.push!(value)
    }

    var body: some Tag {
        Div(id: "viewport-fixture") {
            Button("Toggle viewport hooks") { mounted.toggle() }
                .attribute("id", "viewport-toggle")
            Button("Dispose temporary viewport backend") {
                let temporary = DOMBackend(dispatch: { _, _ in })
                let probe = JSObject.global.__viewportProbe.object!
                probe.cleanupDeliveries = .number(0)
                _ = temporary.beginDocumentVisibilityObservation { _ in
                    probe.cleanupDeliveries = .number((probe.cleanupDeliveries.number ?? 0) + 1)
                }
                _ = temporary.beginVisualViewportObservation { _ in
                    probe.cleanupDeliveries = .number((probe.cleanupDeliveries.number ?? 0) + 1)
                }
                temporary.endEnvironmentObservation()
                temporary.endEnvironmentObservation()
            }
            .attribute("id", "viewport-dispose")
            Button("Start animation") {
                withAnimation(.linear(duration: 30)) { shifted.toggle() }
            }
            .attribute("id", "viewport-animate")
            Div(id: "viewport-animated").opacity(shifted ? 0.25 : 1)
            Button("Mount viewport hooks") { mounted = true }
                .attribute("id", "viewport-mount")
            if mounted {
                Div(id: "viewport-subscriber")
                    .onDocumentVisibilityChange { record("document", .boolean($0)) }
                    .onVisualViewportChange { metrics in
                        let object = JSObject.global.Object.function!.new()
                        object.width = .number(metrics.width)
                        object.height = .number(metrics.height)
                        object.offsetTop = .number(metrics.offsetTop)
                        object.offsetLeft = .number(metrics.offsetLeft)
                        object.scale = .number(metrics.scale)
                        object.layoutViewportHeight = .number(metrics.layoutViewportHeight)
                        record("metrics", .object(object))
                    }
            }
        }
        .attribute("style", "position:fixed;left:0;bottom:0;z-index:9999;background:white")
    }
}
