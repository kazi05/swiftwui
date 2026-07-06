#if arch(wasm32)
import JavaScriptKit

/// Site-local scrollspy (spec D9 — deliberately NOT a framework feature).
/// JSClosure is retained for the component's lifetime (v1 lesson: a JSClosure
/// must outlive its attachment).
@MainActor
public final class ScrollSpy {
    private var observer: JSObject?
    private var callback: JSClosure?

    public init() {}

    /// Observes `#\(anchor)-step-\(i)` for i in 0..<stepCount.
    /// `onActive` receives the smallest intersecting step index.
    public func attach(anchor: String, stepCount: Int, onActive: @escaping (Int) -> Void) {
        detach()
        let document = JSObject.global.document
        let cb = JSClosure { args in
            guard let entries = args.first?.object else { return .undefined }
            let n = Int(entries.length.number ?? 0)
            var best: Int? = nil
            for i in 0..<n {
                guard let entry = entries[i].object,
                      entry.isIntersecting.boolean == true,
                      let id = entry.target.id.string,
                      let idx = Int(id.split(separator: "-").last.map(String.init) ?? "")
                else { continue }
                best = best.map { min($0, idx) } ?? idx
            }
            if let best { onActive(best) }
            return .undefined
        }
        let options = JSObject.global.Object.function!.new()
        // active band: a step becomes active when its box crosses the
        // 25%–45% viewport band (tuned in smoke, spec §13)
        options.rootMargin = .string("-25% 0px -55% 0px")
        let obs = JSObject.global.IntersectionObserver.function!.new(cb, options)
        for i in 0..<stepCount {
            let el = document.getElementById("\(anchor)-step-\(i)")
            if el.isNull || el.isUndefined { continue }
            _ = obs.observe!(el)
        }
        observer = obs
        callback = cb
    }

    public func detach() {
        if let observer { _ = observer.disconnect?() }
        observer = nil
        callback = nil
    }
}
#else
/// Native/ssg shim: same API, does nothing — prerendered pages show step 0.
@MainActor
public final class ScrollSpy {
    public init() {}
    public func attach(anchor: String, stepCount: Int, onActive: @escaping (Int) -> Void) {}
    public func detach() {}
}
#endif
