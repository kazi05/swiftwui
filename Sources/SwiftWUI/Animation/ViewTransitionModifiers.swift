// Every typed style modifier in this codebase exists on three surfaces:
// HTMLTag (returns Self, so HTMLTag-only modifiers keep chaining), Tag
// (returns _StyledTag), and StyleProxy (for .style { } and Rule bodies).
// A Tag-only overload here would silently wrap plain elements in _StyledTag and
// drop `.onClick` / `.draggable` / `.attribute` downstream.

extension HTMLTag {
    /// Marks this element as one side of a shared-element morph: the same `id`
    /// on an element in the destination page makes the browser interpolate one
    /// rect into the other during a view transition (view-transitions spec §2).
    ///
    /// NOTE: a `view-transition-name` is never inert. The element forms a
    /// stacking context, is flattened in 3D transforms, and forms a backdrop
    /// root — always, transition or not. So `z-index` starts mattering,
    /// `transform-style: preserve-3d` descendants flatten, and a descendant
    /// `backdrop-filter` samples inside the element instead of the page behind it.
    ///
    /// `duration`/`timingFunction` tune only this group and register one CSS
    /// rule per id — cheap once, N times inside a `ForEach`.
    public func matchedTransition(id: String, in namespace: TransitionNamespace? = nil,
                                  duration: CSSDuration? = nil,
                                  timingFunction: TimingFunction? = nil,
                                  contentFit: TransitionContentFit? = nil) -> Self {
        let name = namespace?.qualify(id) ?? id
        guard let d = StyleDeclaration.viewTransitionName(name) else { return self }
        var copy = _style(d)
        if let rule = ViewTransitionCSS.groupRule(name: name, duration: duration,
                                                  timingFunction: timingFunction,
                                                  contentFit: contentFit) {
            copy._attributes.addPendingRule(rule)
        }
        return copy
    }
}

extension Tag {
    /// See `HTMLTag.matchedTransition(id:in:duration:timingFunction:contentFit:)`.
    public func matchedTransition(id: String, in namespace: TransitionNamespace? = nil,
                                  duration: CSSDuration? = nil,
                                  timingFunction: TimingFunction? = nil,
                                  contentFit: TransitionContentFit? = nil) -> _StyledTag<Self> {
        let name = namespace?.qualify(id) ?? id
        guard let d = StyleDeclaration.viewTransitionName(name) else {
            return _StyledTag(content: self, declarations: [], rules: [])
        }
        let rules = ViewTransitionCSS.groupRule(name: name, duration: duration,
                                                timingFunction: timingFunction,
                                                contentFit: contentFit).map { [$0] } ?? []
        return _StyledTag(content: self, declarations: [d], rules: rules)
    }
}

extension StyleProxy {
    /// See `HTMLTag.matchedTransition(id:in:duration:timingFunction:contentFit:)`.
    /// The proxy has no rule sink, so per-group tuning is not available here.
    public mutating func matchedTransition(id: String, in namespace: TransitionNamespace? = nil) {
        guard let d = StyleDeclaration.viewTransitionName(namespace?.qualify(id) ?? id) else { return }
        _add(d)
    }
}

extension _StyledTag {
    /// Collapsing overload: chaining `.matchedTransition` after another style
    /// modifier stays inside one `_StyledTag` wrapper rather than nesting a
    /// second one (same collapsing rule every other typed modifier follows).
    public func matchedTransition(id: String, in namespace: TransitionNamespace? = nil,
                                  duration: CSSDuration? = nil,
                                  timingFunction: TimingFunction? = nil,
                                  contentFit: TransitionContentFit? = nil) -> Self {
        let name = namespace?.qualify(id) ?? id
        guard let d = StyleDeclaration.viewTransitionName(name) else { return self }
        var copy = _styled(d)
        if let rule = ViewTransitionCSS.groupRule(name: name, duration: duration,
                                                  timingFunction: timingFunction,
                                                  contentFit: contentFit) {
            copy.rules.append(rule)
        }
        return copy
    }
}
