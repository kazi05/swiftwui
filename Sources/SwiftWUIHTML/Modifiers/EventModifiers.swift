// EventModifiers.swift - DOM event modifier extensions for HTMLTag

import SwiftWUICore

// MARK: - DOM Event Modifiers

extension HTMLTag {
    /// Called when the mouse enters or leaves the element.
    public func onHover(_ action: @escaping @Sendable (Bool) -> Void) -> Self {
        var copy = self
        copy.eventListeners["mouseenter"] = { action(true) }
        copy.eventListeners["mouseleave"] = { action(false) }
        return copy
    }

    /// Called when the element receives focus.
    public func onFocus(_ action: @escaping @Sendable () -> Void) -> Self {
        on(.focus, handler: action)
    }

    /// Called when the element loses focus.
    public func onBlur(_ action: @escaping @Sendable () -> Void) -> Self {
        on(.blur, handler: action)
    }

    /// Called when the element's input value changes.
    /// The DOMRenderer extracts the real value from the JS event via InputEventContext.
    public func onInput(_ action: @escaping @Sendable (String) -> Void) -> Self {
        var copy = self
        copy.eventListeners["input"] = {
            let value = InputEventContext.currentValue ?? ""
            action(value)
        }
        return copy
    }

    /// Called when a form is submitted.
    public func onSubmit(_ action: @escaping @Sendable () -> Void) -> Self {
        on(.submit, handler: action)
    }

    /// Called on scroll.
    /// The DOMRenderer extracts scroll position from the JS event via ScrollEventContext.
    public func onScroll(_ action: @escaping @Sendable (ScrollOffset) -> Void) -> Self {
        var copy = self
        copy.eventListeners["scroll"] = {
            let offset = ScrollEventContext.currentOffset ?? ScrollOffset(x: 0, y: 0)
            action(offset)
        }
        return copy
    }

    /// Called on keydown.
    /// The DOMRenderer extracts key info from the JS event via KeyEventContext.
    public func onKeyDown(_ action: @escaping @Sendable (KeyInfo) -> Void) -> Self {
        var copy = self
        copy.eventListeners["keydown"] = {
            let key = KeyEventContext.currentKey ?? KeyInfo(
                key: "", code: "", ctrlKey: false, shiftKey: false, altKey: false, metaKey: false
            )
            action(key)
        }
        return copy
    }

    /// Called on keyup.
    /// The DOMRenderer extracts key info from the JS event via KeyEventContext.
    public func onKeyUp(_ action: @escaping @Sendable (KeyInfo) -> Void) -> Self {
        var copy = self
        copy.eventListeners["keyup"] = {
            let key = KeyEventContext.currentKey ?? KeyInfo(
                key: "", code: "", ctrlKey: false, shiftKey: false, altKey: false, metaKey: false
            )
            action(key)
        }
        return copy
    }

    /// Called on copy.
    public func onCopy(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        copy.eventListeners["copy"] = action
        return copy
    }

    /// Called on paste.
    /// The DOMRenderer extracts clipboard text from the JS event via PasteEventContext.
    public func onPaste(_ action: @escaping @Sendable (String) -> Void) -> Self {
        var copy = self
        copy.eventListeners["paste"] = {
            let text = PasteEventContext.currentText ?? ""
            action(text)
        }
        return copy
    }

    /// Called on drag start.
    public func onDrag(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        copy.eventListeners["dragstart"] = action
        return copy
    }

    /// Called on drop.
    public func onDrop(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        copy.eventListeners["drop"] = action
        return copy
    }
}

// MARK: - Observer-based Modifiers

extension HTMLTag {
    /// Called when the element enters the viewport (via IntersectionObserver).
    public func onAppear(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register(action)
        copy.observers.append(.intersection(threshold: 0, callbackID: id))
        return copy
    }

    /// Called when the element leaves the viewport (via IntersectionObserver).
    public func onDisappear(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register(action)
        // threshold == -1 signals "onDisappear" to DOMRenderer
        copy.observers.append(.intersection(threshold: -1, callbackID: id))
        return copy
    }

    /// Called when the element is resized (via ResizeObserver).
    /// The DOMRenderer populates ResizeEventContext before calling the handler.
    public func onResize(_ action: @escaping @Sendable (ElementSize) -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register {
            let size = ResizeEventContext.currentSize ?? ElementSize(width: 0, height: 0)
            action(size)
        }
        copy.observers.append(.resize(callbackID: id))
        return copy
    }

    /// Called when the element's frame (position + size) changes (via ResizeObserver + getBoundingClientRect).
    /// The DOMRenderer populates FrameChangeContext before calling the handler.
    public func onFrameChange(_ action: @escaping @Sendable (ElementRect) -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register {
            let rect = FrameChangeContext.currentRect ?? ElementRect(x: 0, y: 0, width: 0, height: 0)
            action(rect)
        }
        copy.observers.append(.resize(callbackID: id))
        return copy
    }

    /// Called with the intersection ratio when the element's visibility changes (via IntersectionObserver).
    /// The DOMRenderer populates IntersectionContext before calling the handler.
    public func onIntersection(threshold: Double = 0.5, action: @escaping @Sendable (Double) -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register {
            let ratio = IntersectionContext.currentRatio ?? 0
            action(ratio)
        }
        copy.observers.append(.intersection(threshold: threshold, callbackID: id))
        return copy
    }
}

// MARK: - Lifecycle Modifiers

extension HTMLTag {
    /// Called when the element is mounted to the DOM.
    public func onMount(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register(action)
        copy.observers.append(.lifecycle(event: .mount, callbackID: id))
        return copy
    }

    /// Called when the element is removed from the DOM.
    public func onUnmount(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register(action)
        copy.observers.append(.lifecycle(event: .unmount, callbackID: id))
        return copy
    }
}
