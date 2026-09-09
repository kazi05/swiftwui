enum ScrollCommand {
    case restore(ScrollAnchor)
    case end(ScrollProxy.Behavior)
}

/// Reads committed geometry and requests scrolling after the runtime's next commit.
/// A proxy belongs to one mounted `ScrollReader`; retained proxies become inert on removal.
@MainActor
public final class ScrollProxy {
    nonisolated deinit { }

    /// Imperative scroll behavior, independent of the CSS `ScrollBehavior` type.
    public enum Behavior: Equatable, Sendable {
        case instant
        case smooth
    }

    private let readMetrics: () -> ScrollMetrics?
    private let capture: ([String]) -> ScrollAnchor?
    private let submit: (ScrollCommand) -> Void

    init(metrics: @escaping () -> ScrollMetrics?,
         capture: @escaping ([String]) -> ScrollAnchor?,
         submit: @escaping (ScrollCommand) -> Void) {
        readMetrics = metrics; self.capture = capture; self.submit = submit
    }

    static func inert() -> ScrollProxy {
        ScrollProxy(metrics: { nil }, capture: { _ in nil }, submit: { _ in })
    }

    /// Returns layout geometry now, or nil when this reader has no available scrollport.
    public func metrics() -> ScrollMetrics? {
        guard let value = readMetrics(), value._isValid else { return nil }
        return value
    }

    /// Captures the first visible candidate in the supplied reading order.
    public func captureAnchor(in orderedElementIDs: [String]) -> ScrollAnchor? {
        capture(orderedElementIDs)
    }

    /// Restores this identity's visible-top offset after commit, using instant scrolling.
    /// Missing anchors do nothing. A later command replaces an earlier pending command.
    public func restore(_ anchor: ScrollAnchor) {
        guard !anchor.elementID.isEmpty, anchor.offsetFromVisibleTop.isFinite else { return }
        submit(.restore(anchor))
    }

    /// Requests the physical bottom of the selected scrollport. Reduced motion disables smoothness.
    public func scrollToEnd(behavior: Behavior = .instant) {
        submit(.end(behavior))
    }
}
