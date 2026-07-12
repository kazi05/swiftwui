/// Element observers (spec 2026-07-12 §2.3). Same lifecycle discipline as
/// event listeners: attach on mount/patch, detach on unmount/patch.
public enum ObserverKind: Hashable {
    case visibility(threshold: Double)
    case size

    /// Reserved "event" namespace for ListenerID routing. Threshold is part of
    /// the key so two visibility observers with different thresholds coexist.
    /// Public: DOMBackend (SwiftWUIDOM module) keys its retention dictionaries
    /// by it, same as every other cross-module backend surface.
    public var key: String {
        switch self {
        case .visibility(let t): return "swui:visibility:\(t)"
        case .size: return "swui:size"
        }
    }
}

extension HTMLTag {
    /// Fires with `true`/`false` as the element enters/leaves the viewport
    /// (IntersectionObserver).
    public func onVisibilityChange(threshold: Double = 0.0,
                                   _ action: @escaping (Bool) -> Void) -> Self {
        var copy = self
        copy._attributes.addObserver(.visibility(threshold: threshold)) { any in
            action(any as? Bool ?? false)
        }
        return copy
    }
    /// Fires with the element's content size on every resize (ResizeObserver).
    public func onSizeChange(_ action: @escaping (SizeEvent) -> Void) -> Self {
        var copy = self
        copy._attributes.addObserver(.size) { any in
            guard let s = any as? SizeEvent else { return }
            action(s)
        }
        return copy
    }
}
