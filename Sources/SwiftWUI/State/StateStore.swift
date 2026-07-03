struct RetainedComponent {
    var tag: AnyTag
    var environment: EnvironmentValues
    /// Declarations/classes applied by an enclosing `_StyledTag` wrapper (spec
    /// §6, §11). A `subtreePass` re-resolves this row's tag directly — it
    /// never re-runs the wrapper's own `_resolve` — so the wrapper stashes its
    /// transform here to be replayed after every scoped re-render.
    var styleWrapper: (declarations: [StyleDeclaration], classes: [String])?
}

@MainActor
public final class StateStore {
    private var rows: [NodeIdentity: [AnyObject]] = [:]
    private var retained: [NodeIdentity: RetainedComponent] = [:]
    public init() {}

    /// Retains the resolved component value + its environment snapshot so a
    /// later scoped pass can re-invoke its body (spec §2.3).
    func retain(_ tag: AnyTag, at id: NodeIdentity, environment: EnvironmentValues) {
        // Every resolve of this id re-retains (fresh tag/environment) — preserve
        // a previously-stashed style wrapper (only `setStyleWrapper`/sweep touch
        // it) so it survives the many re-retains a scoped-only subtree pass does.
        let styleWrapper = retained[id]?.styleWrapper
        retained[id] = RetainedComponent(tag: tag, environment: environment, styleWrapper: styleWrapper)
    }
    func retainedRow(at id: NodeIdentity) -> RetainedComponent? { retained[id] }

    /// Stashes an enclosing `_StyledTag`'s transform for replay on later
    /// subtree passes (see `RetainedComponent.styleWrapper`). Call after
    /// `retain` has run for `id` (i.e. after `resolve(content:...)` returns).
    func setStyleWrapper(_ w: (declarations: [StyleDeclaration], classes: [String]), at id: NodeIdentity) {
        retained[id]?.styleWrapper = w
    }

    /// Grafts persisted boxes onto a freshly constructed component, in Mirror
    /// declaration order, BEFORE its body is evaluated (spec §6).
    func link(_ component: some Tag, at id: NodeIdentity,
              environment: EnvironmentValues, invalidate: @escaping () -> Void) {
        var props: [_StateProperty] = []
        for child in Mirror(reflecting: component).children {
            if let p = child.value as? _StateProperty { props.append(p) }
            if let e = child.value as? _EnvironmentProperty { e._inject(environment) }
        }
        guard !props.isEmpty else { return }

        if let boxes = rows[id], boxes.count == props.count {
            var allAdopted = true
            for (i, p) in props.enumerated() {
                let ok = p._adopt(boxes[i])       // no short-circuit: every prop must try
                allAdopted = allAdopted && ok
            }
            if !allAdopted { rows[id] = props.map { $0._box } }   // shape changed → reset
        } else {
            rows[id] = props.map { $0._box }                       // first mount or count change
        }
        for p in props { p._bindInvalidate(invalidate) }
    }

    func sweep(under root: NodeIdentity, reachable: Set<NodeIdentity>) {
        for id in Array(rows.keys)
        where id.isSelfOrDescendant(of: root) && !reachable.contains(id) {
            rows.removeValue(forKey: id)
        }
        for id in Array(retained.keys)
        where id.isSelfOrDescendant(of: root) && !reachable.contains(id) {
            retained.removeValue(forKey: id)
        }
    }

    var rowCount: Int { rows.count }
}
