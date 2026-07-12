/// Built-in interaction modifiers (spec 2026-07-12 §2.2). Event modifiers are
/// HTMLTag-only by design — they ride the attribute-bag path and return Self.
extension HTMLTag {
    public func onTap(_ action: @escaping () -> Void) -> Self {
        var copy = self; copy._attributes.addHandler(.click, action); return copy
    }
    /// Payload variant. A dispatch without payload (non-DOM backends, tests)
    /// arrives as an unmodified default ClickEvent.
    public func onTap(_ action: @escaping (ClickEvent) -> Void) -> Self {
        var copy = self
        copy._attributes.addRawHandler(.click) { any in action(any as? ClickEvent ?? ClickEvent()) }
        return copy
    }
    public func onDoubleTap(_ action: @escaping () -> Void) -> Self {
        var copy = self; copy._attributes.addHandler(.dblclick, action); return copy
    }
    public func onHover(_ action: @escaping (Bool) -> Void) -> Self {
        var copy = self
        copy._attributes.addRawHandler(.mouseenter) { _ in action(true) }
        copy._attributes.addRawHandler(.mouseleave) { _ in action(false) }
        return copy
    }
    public func onKeyDown(_ action: @escaping (KeyEvent) -> Void) -> Self {
        var copy = self
        copy._attributes.addHandler(.keydown, payload: KeyEvent.self, action)
        return copy
    }
    public func onKeyUp(_ action: @escaping (KeyEvent) -> Void) -> Self {
        var copy = self
        copy._attributes.addHandler(.keyup, payload: KeyEvent.self, action)
        return copy
    }
    /// Filtered form: fires only when key AND the exact modifier set match.
    public func onKeyDown(_ key: KeyEquivalent, modifiers: EventModifiers = [],
                          _ action: @escaping () -> Void) -> Self {
        var copy = self
        copy._attributes.addHandler(.keydown, payload: KeyEvent.self) { e in
            if e.key == key.key && e.modifiers == modifiers { action() }
        }
        return copy
    }
    public func onFocus(_ action: @escaping () -> Void) -> Self {
        var copy = self; copy._attributes.addHandler(.focus, action); return copy
    }
    public func onBlur(_ action: @escaping () -> Void) -> Self {
        var copy = self; copy._attributes.addHandler(.blur, action); return copy
    }
    /// The DOM backend always calls preventDefault() on submit (spec D10).
    public func onSubmit(_ action: @escaping () -> Void) -> Self {
        var copy = self; copy._attributes.addHandler(.submit, action); return copy
    }
}
