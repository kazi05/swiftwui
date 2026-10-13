#if arch(wasm32)
import JavaScriptKit
import SwiftWUI

/// One configured IntersectionObserver, live from `start` until the renderer
/// binding's cancellation closure runs.
@MainActor
final class DOMConfiguredVisibility {
    nonisolated deinit { }

    // One JSClosure for every binding (JavaScriptKit never frees one in WeakRefs
    // builds). It routes by the id stamped on the observer, its second argument.
    private static var live: [Int: DOMConfiguredVisibility] = [:]
    private static var nextID = 0
    private static let callback = JSClosure { args in
        guard args.count > 1, let entries = args[0].object,
              let id = args[1].object?.__swuiVis.number else { return .undefined }
        for index in 0..<Int(entries.length.number ?? 0) {
            guard let owner = live[Int(id)] else { break }
            guard let entry = entries[index].object else { continue }
            let intersects = entry.isIntersecting.boolean ?? false
            let ratio = entry.intersectionRatio.number ?? 0
            owner.onChange(intersects && (owner.threshold == 0 || ratio >= owner.threshold))
        }
        return .undefined
    }

    private let id: Int
    private let threshold: Double
    private let onChange: (Bool) -> Void
    private var observer: JSObject?

    private init(id: Int, threshold: Double, onChange: @escaping (Bool) -> Void) {
        self.id = id
        self.threshold = threshold
        self.onChange = onChange
    }

    static func start(
        _ target: JSObject,
        root: VisibilityObserverRoot<JSObject>,
        threshold: Double,
        margin: VisibilityMargin,
        onChange: @escaping (Bool) -> Void
    ) -> (() -> Void)? {
        if case .unavailable = root { return {} }
        guard let constructor = JSObject.global.IntersectionObserver.function else { return nil }

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

        nextID += 1
        let owner = DOMConfiguredVisibility(id: nextID, threshold: threshold, onChange: onChange)
        let observer = constructor.new(callback, options)
        observer.__swuiVis = .number(Double(owner.id))
        owner.observer = observer
        live[owner.id] = owner
        _ = observer.observe?(target)
        return { owner.stop() }
    }

    private func stop() {
        guard Self.live.removeValue(forKey: id) != nil else { return }
        _ = observer?.disconnect?()
        // disconnect() removes targets but does not clear already queued
        // records. Drain them; one delivered anyway finds no `live` entry.
        _ = observer?.takeRecords?()
        observer = nil
    }
}
#endif
