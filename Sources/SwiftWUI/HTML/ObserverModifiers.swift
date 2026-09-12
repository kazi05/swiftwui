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
    /// Reports whether the element intersects the viewport with at least
    /// `threshold` of its area visible. Threshold must be finite and in 0...1.
    /// At zero, uses IntersectionObserver's `isIntersecting` semantics,
    /// including edge contact; at one, the entire area must intersect.
    public func onVisibilityChange(threshold: Double = 0.0,
                                   _ action: @escaping (Bool) -> Void) -> Self {
        precondition(threshold.isFinite && (0...1).contains(threshold),
                     "Visibility threshold must be finite and in 0...1")
        var copy = self
        copy._attributes.addObserver(.visibility(threshold: threshold)) { any in
            guard let v = any as? Bool else { return }
            action(v)
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
