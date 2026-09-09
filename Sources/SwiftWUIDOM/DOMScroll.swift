#if arch(wasm32)
import JavaScriptKit
@_spi(DOM) import SwiftWUI

private struct _DOMScrollRect {
    let left: Double
    let top: Double
    let width: Double
    let height: Double

    var right: Double { left + width }
    var bottom: Double { top + height }

    init?(left: Double?, top: Double?, width: Double?, height: Double?) {
        guard let left, left.isFinite,
              let top, top.isFinite,
              let width, width.isFinite, width > 0,
              let height, height.isFinite, height > 0 else { return nil }
        self.left = left
        self.top = top
        self.width = width
        self.height = height
    }

    func intersection(with other: _DOMScrollRect) -> _DOMScrollRect? {
        let intersectionLeft = max(left, other.left)
        let intersectionTop = max(top, other.top)
        let intersectionRight = min(right, other.right)
        let intersectionBottom = min(bottom, other.bottom)
        return _DOMScrollRect(
            left: intersectionLeft,
            top: intersectionTop,
            width: intersectionRight - intersectionLeft,
            height: intersectionBottom - intersectionTop
        )
    }
}

private struct _DOMScrollWindow {
    let document: JSObject
    let window: JSObject
    let root: JSObject
    let scrollingElement: JSObject
}

private extension DOMBackend {
    func scrollWindow(for target: _ScrollTarget<JSObject>) -> _DOMScrollWindow? {
        let document: JSObject?
        switch target {
        case .window:
            document = JSObject.global.document.object
        case .element(let element):
            document = element.ownerDocument.object
        }
        guard let document,
              let window = document.defaultView.object,
              let root = document.documentElement.object,
              let scrollingElement = document.scrollingElement.object,
              isConnectedElement(root),
              isConnectedElement(scrollingElement) else { return nil }
        return _DOMScrollWindow(
            document: document,
            window: window,
            root: root,
            scrollingElement: scrollingElement
        )
    }

    func isConnectedElement(_ element: JSObject) -> Bool {
        element.nodeType.number == 1 && element.isConnected.boolean == true
    }

    func layoutRect(of element: JSObject) -> _DOMScrollRect? {
        guard isConnectedElement(element),
              let clientRects = element.getClientRects?().object,
              let count = clientRects.length.number, count > 0,
              let rect = element.getBoundingClientRect?().object else { return nil }
        return _DOMScrollRect(
            left: rect.left.number,
            top: rect.top.number,
            width: rect.width.number,
            height: rect.height.number
        )
    }

    func visualViewportRect(in context: _DOMScrollWindow) -> _DOMScrollRect? {
        if let viewport = context.window.visualViewport.object {
            return _DOMScrollRect(
                left: viewport.offsetLeft.number,
                top: viewport.offsetTop.number,
                width: viewport.width.number,
                height: viewport.height.number
            )
        }
        return _DOMScrollRect(
            left: 0,
            top: 0,
            width: context.root.clientWidth.number,
            height: context.root.clientHeight.number
        )
    }

    func visibleRect(for target: _ScrollTarget<JSObject>, in context: _DOMScrollWindow) -> _DOMScrollRect? {
        guard let viewport = visualViewportRect(in: context) else { return nil }
        switch target {
        case .window:
            return viewport
        case .element(let element):
            guard element.ownerDocument.object == context.document,
                  let borderRect = layoutRect(of: element),
                  let scrollport = _DOMScrollRect(
                    left: borderRect.left + (element.clientLeft.number ?? .nan),
                    top: borderRect.top + (element.clientTop.number ?? .nan),
                    width: element.clientWidth.number,
                    height: element.clientHeight.number
                  ) else { return nil }
            return scrollport.intersection(with: viewport)
        }
    }

    func layoutMetrics(for target: _ScrollTarget<JSObject>, in context: _DOMScrollWindow) -> ScrollMetrics? {
        let metrics: ScrollMetrics
        switch target {
        case .window:
            metrics = ScrollMetrics(
                x: context.window.scrollX.number ?? .nan,
                y: context.window.scrollY.number ?? .nan,
                viewportWidth: context.root.clientWidth.number ?? .nan,
                viewportHeight: context.root.clientHeight.number ?? .nan,
                contentWidth: context.scrollingElement.scrollWidth.number ?? .nan,
                contentHeight: context.scrollingElement.scrollHeight.number ?? .nan
            )
        case .element(let element):
            guard element.ownerDocument.object == context.document,
                  layoutRect(of: element) != nil else { return nil }
            metrics = ScrollMetrics(
                x: element.scrollLeft.number ?? .nan,
                y: element.scrollTop.number ?? .nan,
                viewportWidth: element.clientWidth.number ?? .nan,
                viewportHeight: element.clientHeight.number ?? .nan,
                contentWidth: element.scrollWidth.number ?? .nan,
                contentHeight: element.scrollHeight.number ?? .nan
            )
        }
        guard metrics._isValid,
              metrics.viewportWidth > 0,
              metrics.viewportHeight > 0 else { return nil }
        return metrics
    }

    func currentOffsets(for target: _ScrollTarget<JSObject>, in context: _DOMScrollWindow)
        -> (scrollObject: JSObject, x: Double, y: Double)? {
        let scrollObject: JSObject
        let x: Double?
        let y: Double?
        switch target {
        case .window:
            scrollObject = context.window
            x = context.window.scrollX.number
            y = context.window.scrollY.number
        case .element(let element):
            scrollObject = element
            x = element.scrollLeft.number
            y = element.scrollTop.number
        }
        guard let x, x.isFinite, let y, y.isFinite else { return nil }
        return (scrollObject, x, y)
    }

    func scroll(_ object: JSObject, x: Double, y: Double, behavior: String) {
        guard x.isFinite, y.isFinite,
              let options = JSObject.global.Object.function?.new() else { return }
        options.left = .number(x)
        options.top = .number(y)
        options.behavior = .string(behavior)
        _ = object.scroll?(options)
    }
}

extension DOMBackend {
    public func _scrollMetrics(in target: _ScrollTarget<JSObject>) -> ScrollMetrics? {
        guard let context = scrollWindow(for: target) else { return nil }
        return layoutMetrics(for: target, in: context)
    }

    public func _captureScrollAnchor(in target: _ScrollTarget<JSObject>,
                                     candidates: [JSObject]) -> _ScrollAnchorGeometry? {
        guard !candidates.isEmpty,
              let context = scrollWindow(for: target),
              let visibleRect = visibleRect(for: target, in: context) else { return nil }
        for (index, candidate) in candidates.enumerated() {
            guard candidate.ownerDocument.object == context.document,
                  let candidateRect = layoutRect(of: candidate),
                  candidateRect.intersection(with: visibleRect) != nil else { continue }
            let offset = candidateRect.top - visibleRect.top
            guard offset.isFinite else { continue }
            return _ScrollAnchorGeometry(index: index, offsetFromVisibleTop: offset)
        }
        return nil
    }

    public func _restoreScrollAnchor(in target: _ScrollTarget<JSObject>,
                                     element: JSObject, offset: Double) {
        guard offset.isFinite,
              let context = scrollWindow(for: target),
              element.ownerDocument.object == context.document,
              let anchorRect = layoutRect(of: element),
              let visibleRect = visibleRect(for: target, in: context) else { return }

        // Keep these offset reads after all geometry reads. A geometry read makes
        // any pending native scroll-anchoring adjustment observable first.
        guard let current = currentOffsets(for: target, in: context) else { return }
        let targetY = current.y + anchorRect.top - visibleRect.top - offset
        scroll(current.scrollObject, x: current.x, y: targetY, behavior: "instant")
    }

    public func _scrollToEnd(in target: _ScrollTarget<JSObject>, behavior: ScrollProxy.Behavior) {
        guard let context = scrollWindow(for: target),
              let metrics = layoutMetrics(for: target, in: context),
              let current = currentOffsets(for: target, in: context) else { return }
        let targetY = max(0, metrics.contentHeight - metrics.viewportHeight)
        let jsBehavior = behavior == .smooth ? "smooth" : "instant"
        scroll(current.scrollObject, x: current.x, y: targetY, behavior: jsBehavior)
    }
}
#endif
