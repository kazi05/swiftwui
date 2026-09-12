#if arch(wasm32)
import JavaScriptKit
import SwiftWUI

public enum DOMIslandError: Error { case missingContainer(String), alreadyMounted(String), unsupportedRouting }

/// Retain while the island is needed; dispose explicitly to cancel activation,
/// observers, tasks and event handlers. activate() is an override for every policy.
@MainActor public final class DOMIsland {
    let container: JSObject
    var whenActivated: (() -> Void)?
    var whenDisposed: (() -> Void)?
    private var cancelActivation: (() -> Void)?
    public private(set) var isActive = false
    public private(set) var isDisposed = false
    public internal(set) var failure: DOMIslandError?
    init(container: JSObject) { self.container = container }
    public func activate() {
        guard !isActive, !isDisposed else { return }
        isActive = true
        let keepAlive = cancelActivation
        cancelActivation = nil; keepAlive?()
        let mount = whenActivated; whenActivated = nil
        mount?()
        withExtendedLifetime(keepAlive) { }
    }
    public func dispose() {
        guard !isDisposed else { return }; isDisposed = true
        cancelActivation?(); cancelActivation = nil; whenActivated = nil
        whenDisposed?(); whenDisposed = nil
        _ = container.removeAttribute?("data-swui-island")
    }
    func schedule(_ policy: BootActivation) {
        switch policy {
        case .eager: activate()
        case .visible:
            guard let constructor = JSObject.global.IntersectionObserver.function else { activate(); return }
            let callback = JSClosure { [weak self] args in
                guard let entries = args.first?.object else { return .undefined }
                for index in 0..<Int(entries.length.number ?? 0) where entries[index].object?.isIntersecting.boolean == true {
                    self?.activate(); break
                }
                return .undefined
            }
            let observer = constructor.new(callback)
            _ = observer.observe?(container)
            cancelActivation = { _ = observer.disconnect?(); withExtendedLifetime(callback) { } }
        case .interaction:
            let events = ["pointerdown", "keydown", "focusin"]
            let callback = JSClosure { [weak self] _ in self?.activate(); return .undefined }
            for event in events { _ = container.addEventListener?(event, callback, true) }
            cancelActivation = { [container] in
                for event in events { _ = container.removeEventListener?(event, callback, true) }
            }
        case .idle:
            let callback = JSClosure { [weak self] _ in self?.activate(); return .undefined }
            if let idle = JSObject.global.requestIdleCallback.function {
                let options = JSObject.global.Object.function!.new(); options.timeout = .number(2000)
                let id = idle(callback, options)
                cancelActivation = { _ = JSObject.global.cancelIdleCallback?(id); withExtendedLifetime(callback) { } }
            } else {
                let id = JSObject.global.setTimeout!(callback, 1)
                cancelActivation = { _ = JSObject.global.clearTimeout?(id); withExtendedLifetime(callback) { } }
            }
        }
    }
}
#endif
