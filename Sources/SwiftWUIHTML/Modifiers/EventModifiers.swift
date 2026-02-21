// EventModifiers.swift - DOM event modifier extensions for HTMLTag

import SwiftWUICore

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
    public func onInput(_ action: @escaping @Sendable (String) -> Void) -> Self {
        var copy = self
        copy.eventListeners["input"] = { action("") }
        return copy
    }

    /// Called when a form is submitted.
    public func onSubmit(_ action: @escaping @Sendable () -> Void) -> Self {
        on(.submit, handler: action)
    }

    /// Called on scroll.
    public func onScroll(_ action: @escaping @Sendable (ScrollOffset) -> Void) -> Self {
        var copy = self
        copy.eventListeners["scroll"] = { action(ScrollOffset(x: 0, y: 0)) }
        return copy
    }

    /// Called on keydown.
    public func onKeyDown(_ action: @escaping @Sendable (KeyInfo) -> Void) -> Self {
        var copy = self
        let placeholder = KeyInfo(key: "", code: "", ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
        copy.eventListeners["keydown"] = { action(placeholder) }
        return copy
    }

    /// Called on keyup.
    public func onKeyUp(_ action: @escaping @Sendable (KeyInfo) -> Void) -> Self {
        var copy = self
        let placeholder = KeyInfo(key: "", code: "", ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
        copy.eventListeners["keyup"] = { action(placeholder) }
        return copy
    }

    /// Called on copy.
    public func onCopy(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        copy.eventListeners["copy"] = action
        return copy
    }

    /// Called on paste.
    public func onPaste(_ action: @escaping @Sendable (String) -> Void) -> Self {
        var copy = self
        copy.eventListeners["paste"] = { action("") }
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
