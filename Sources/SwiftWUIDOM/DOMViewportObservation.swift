#if arch(wasm32)
import JavaScriptKit
import SwiftWUI

@MainActor
final class DOMViewportObservation {
    nonisolated deinit { }

    private var sink: ((VisualViewportMetrics) -> Void)?
    private var viewport: JSObject?
    private var closure: JSClosure?

    func begin(_ sink: @escaping (VisualViewportMetrics) -> Void) -> VisualViewportMetrics {
        self.sink = sink
        if closure == nil {
            viewport = JSObject.global.window.visualViewport.object
            let listener = JSClosure { [weak self] _ in
                guard let self else { return .undefined }
                self.sink?(self.snapshot())
                return .undefined
            }
            closure = listener
            if let viewport {
                _ = viewport.addEventListener?("resize", listener)
                _ = viewport.addEventListener?("scroll", listener)
            }
            _ = JSObject.global.window.addEventListener("resize", listener)
        }
        return snapshot()
    }

    private func snapshot() -> VisualViewportMetrics {
        let window = JSObject.global.window
        let width = window.innerWidth.number ?? 0
        let height = window.innerHeight.number ?? 0
        return .init(
            width: viewport?.width.number ?? width,
            height: viewport?.height.number ?? height,
            offsetTop: viewport?.offsetTop.number ?? 0,
            offsetLeft: viewport?.offsetLeft.number ?? 0,
            scale: viewport?.scale.number ?? 1,
            layoutViewportHeight: height
        )
    }

    func stop() {
        sink = nil
        guard let closure else { return }
        if let viewport {
            _ = viewport.removeEventListener?("resize", closure)
            _ = viewport.removeEventListener?("scroll", closure)
        }
        _ = JSObject.global.window.removeEventListener("resize", closure)
        self.closure = nil
        viewport = nil
    }
}
#endif
