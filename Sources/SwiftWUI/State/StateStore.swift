struct RetainedComponent {
    var tag: AnyTag
    var environment: EnvironmentValues
    /// Transforms applied by enclosing `_StyledTag` wrapper(s) (spec §6, §11).
    /// A `subtreePass` re-resolves this row's tag directly — it never re-runs
    /// the wrappers' own `_resolve` — so each wrapper stashes its transform
    /// here to be replayed after every scoped re-render. Accumulated per
    /// identity (stacked non-collapsed wrappers, e.g. `_StyledTag<_StyledTag<Foo>>`
    /// across an opaque boundary, all stash at Foo's id), reset on the first
    /// write of each pass via `styleWrapperPass`; order = inner→outer, matching
    /// full-pass application order so outer-wins is preserved on replay.
    var styleWrappers: [(declarations: [StyleDeclaration], classes: [String])] = []
    var styleWrapperPass: Int = -1
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
        // previously-stashed style wrappers (only `setStyleWrapper`/sweep touch
        // them) so they survive the many re-retains a scoped-only subtree pass
        // does (where the enclosing wrappers don't re-run to re-stash).
        let existing = retained[id]
        retained[id] = RetainedComponent(tag: tag, environment: environment,
                                         styleWrappers: existing?.styleWrappers ?? [],
                                         styleWrapperPass: existing?.styleWrapperPass ?? -1)
    }
    func retainedRow(at id: NodeIdentity) -> RetainedComponent? { retained[id] }

    /// Accumulates an enclosing `_StyledTag`'s transform for replay on later
    /// subtree passes (see `RetainedComponent.styleWrappers`). Call after
    /// `retain` has run for `id` (i.e. after `resolve(content:...)` returns).
    /// The first write of each `pass` resets the list; subsequent writes in the
    /// same pass append. A wrapper chain nests, so within one resolution it runs
    /// atomically bottom-up (inner first) → the list ends up inner→outer.
    func setStyleWrapper(at id: NodeIdentity, pass: Int,
                         declarations: [StyleDeclaration], classes: [String]) {
        assert(retained[id] != nil, "setStyleWrapper before retain for \(id)")
        guard var row = retained[id] else { return }
        if row.styleWrapperPass != pass {
            row.styleWrappers = []
            row.styleWrapperPass = pass
        }
        row.styleWrappers.append((declarations, classes))
        retained[id] = row
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
