#if arch(wasm32)
import JavaScriptKit

/// Site-local scrollspy (spec D9 — deliberately NOT a framework feature).
/// v2: rect-based, no IntersectionObserver. The IO rootMargin band proved
/// unreliable under smoke's synthetic scroll (scrollIntoView + wheel nudge
/// never crossed the band deterministically). A plain scroll/resize listener
/// that checks each step's `getBoundingClientRect().top` against a line at
/// 35% of the viewport height is simpler and deterministic.
/// JSClosure is retained for the component's lifetime (v1 lesson: a JSClosure
/// must outlive its attachment).
@MainActor
public final class ScrollSpy {
    private var scrollHandler: JSClosure?
    private var resizeHandler: JSClosure?
    private var lastActive: Int?
    private var anchor = ""
    private var stepCount = 0
    private var onActive: ((Int) -> Void)?

    public init() {}

    /// Active step = the LAST step (0-based) whose top has crossed the line,
    /// defaulting to 0. `onActive` fires only when the computed step changes
    /// (avoids a re-render on every scroll frame).
    public func attach(anchor: String, stepCount: Int, onActive: @escaping (Int) -> Void) {
        detach()
        self.anchor = anchor
        self.stepCount = stepCount
        self.onActive = onActive

        let scrollCb = JSClosure { [weak self] _ in self?.fire(); return .undefined }
        let resizeCb = JSClosure { [weak self] _ in self?.fire(); return .undefined }
        _ = JSObject.global.window.object?.addEventListener?("scroll", scrollCb)
        _ = JSObject.global.window.object?.addEventListener?("resize", resizeCb)
        scrollHandler = scrollCb
        resizeHandler = resizeCb
        fire()   // initial position
    }

    private func fire() {
        let active = computeActive()
        guard active != lastActive else { return }
        lastActive = active
        onActive?(active)
    }

    private func computeActive() -> Int {
        let document = JSObject.global.document
        let line = (JSObject.global.window.innerHeight.number ?? 0) * 0.35
        var active = 0
        for i in 0..<stepCount {
            let el = document.getElementById("\(anchor)-step-\(i)")
            guard !el.isNull, !el.isUndefined,
                  let top = el.getBoundingClientRect().top.number
            else { continue }
            if top <= line { active = i }
        }
        return active
    }

    public func detach() {
        if let scrollHandler {
            _ = JSObject.global.window.object?.removeEventListener?("scroll", scrollHandler)
        }
        if let resizeHandler {
            _ = JSObject.global.window.object?.removeEventListener?("resize", resizeHandler)
        }
        scrollHandler = nil
        resizeHandler = nil
        lastActive = nil
        onActive = nil
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
