#if arch(wasm32)
import JavaScriptKit
import SwiftWUI

/// Owns one configured IntersectionObserver and its Swift callback for exactly
/// the lifetime of the renderer binding's cancellation closure.
@MainActor
final class DOMConfiguredVisibility {
    nonisolated deinit { }

    private var observer: JSObject?
    private var closure: JSClosure?
    private var active = true

    static func start(
        _ target: JSObject,
        root: VisibilityObserverRoot<JSObject>,
        threshold: Double,
        margin: VisibilityMargin,
        onChange: @escaping (Bool) -> Void
    ) -> (() -> Void)? {
        if case .unavailable = root { return {} }
        guard let constructor = JSObject.global.IntersectionObserver.function else { return nil }

        let owner = DOMConfiguredVisibility()
        let callback = JSClosure { [weak owner] args in
            guard let owner, owner.active, let entries = args.first?.object else {
                return .undefined
            }
            for index in 0..<Int(entries.length.number ?? 0) {
                guard owner.active else { break }
                guard let entry = entries[index].object else { continue }
                let intersects = entry.isIntersecting.boolean ?? false
                let ratio = entry.intersectionRatio.number ?? 0
                onChange(intersects && (threshold == 0 || ratio >= threshold))
            }
            return .undefined
        }

        let options = JSObject.global.Object.function!.new()
        options.threshold = .number(threshold)
        options.rootMargin = .string(margin.css)
        switch root {
        case .viewport:
            options.root = .null
        case .ancestor(let host):
            options.root = .object(host)
        case .unavailable:
            return {}
        }

        let observer = constructor.new(callback, options)
        owner.closure = callback
        owner.observer = observer
        _ = observer.observe?(target)
        return { owner.stop() }
    }

    private func stop() {
        guard active else { return }
        active = false
        _ = observer?.disconnect?()
        // disconnect() removes targets but does not clear already queued
        // records. Drain them before releasing the Swift host function so a
        // scheduled native notification cannot call a released JSClosure.
        _ = observer?.takeRecords?()
        observer = nil
        closure = nil
    }
}
#endif
