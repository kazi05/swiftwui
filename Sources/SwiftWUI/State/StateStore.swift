struct RetainedComponent {
    var tag: AnyTag
    var environment: EnvironmentValues
    /// Caller's `Styled` scope at retain time. Almost every component resets
    /// scope at its own boundary (unused for them), but `ModifiedTag`
    /// deliberately preserves the caller's scope — a later `subtreePass` must
    /// re-seed it or the scope marker vanishes from the modifier body until the
    /// next full pass ("scoped ≡ full" invariant, spec §6/§11).
    var scopeClass: String?
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

    /// Snapshot seed (spec §7): canonical id → slot JSON fragments, consumed on
    /// first link() of each row. Seeded by DOMRuntime before mount.
    public var _pendingRows: [String: [String]] = [:]
    public var _decodeSlot: SnapshotDecode? = nil
    /// SSG build-task write attribution (phase-6 I3): set during _drainBuildTasks only.
    public var _writeObserver: ((NodeIdentity) -> Void)? = nil

    /// Retains the resolved component value + its environment snapshot so a
    /// later scoped pass can re-invoke its body (spec §2.3).
    func retain(_ tag: AnyTag, at id: NodeIdentity, environment: EnvironmentValues,
                scopeClass: String?) {
        // Every resolve of this id re-retains (fresh tag/environment) — preserve
        // previously-stashed style wrappers (only `setStyleWrapper`/sweep touch
        // them) so they survive the many re-retains a scoped-only subtree pass
        // does (where the enclosing wrappers don't re-run to re-stash).
        let existing = retained[id]
        retained[id] = RetainedComponent(tag: tag, environment: environment,
                                         scopeClass: scopeClass,
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
    /// `pass` must be unique per resolution against this shared store — every
    /// caller threads the SAME `ResolveContext.pass`/`Runtime.passCounter`
    /// value for one renderPass/subtreePass, never a stale or reused one
    /// (a reused `pass` value would silently fail to reset the accumulator).
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
    func link(_ component: Any, at id: NodeIdentity,
              environment: EnvironmentValues, invalidate: @escaping () -> Void) {
        var props: [_StateProperty] = []
        for child in Mirror(reflecting: component).children {
            if let p = child.value as? _StateProperty { props.append(p) }
            if let e = child.value as? _EnvironmentProperty { e._inject(environment) }
        }
        guard !props.isEmpty else { return }

        if rows[id] == nil, !_pendingRows.isEmpty, let decode = _decodeSlot,
           let key = id._canonicalString, let slots = _pendingRows.removeValue(forKey: key) {
            if slots.count == props.count {
                var boxes: [AnyObject] = []
                boxes.reserveCapacity(slots.count)
                var ok = true
                for (json, p) in zip(slots, props) {
                    guard let box = p._boxDecoding(json: json, decode: decode) else { ok = false; break }
                    boxes.append(box)
                }
                if ok {
                    rows[id] = boxes       // the adopt path below grafts them like any persisted row
                } else {
                    #if DEBUG
                    print("SwiftWUI snapshot: row '\(key)' failed to decode — using initial values")
                    #endif
                }
            } else {
                #if DEBUG
                print("SwiftWUI snapshot: row '\(key)' slot count \(slots.count) != \(props.count) — using initial values")
                #endif
            }
        }

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
        // Tap writes for SSG build-task attribution (phase-6 I3) — nil observer
        // outside a build-task drain, so this costs nothing at runtime.
        let tracked: () -> Void = { [weak self] in
            if let self { self._writeObserver?(id) }
            invalidate()
        }
        for p in props { p._bindInvalidate(tracked) }
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

    /// Identities of grafted `@State` rows. `BootProbe` needs the identities and
    /// not just `rowCount`: a `.whileBooting` placeholder shares this store with
    /// the page around it, so its own rows are found by path.
    var rowIdentities: [NodeIdentity] { Array(rows.keys) }

    /// SSG side (spec §7): Encodable-only rows; a single non-encodable slot drops
    /// the WHOLE row (partial rows would desync Mirror order on restore).
    /// Constraint (Task 5 review I1): private/function-local component types won't survive hydration — `String(reflecting:)` yields a per-binary address, not a stable name.
    public func _encodeSnapshotRows(_ encode: SnapshotEncode) -> [String: [String]] {
        var out: [String: [String]] = [:]
        outer: for (id, boxes) in rows {
            guard let key = id._canonicalString else { continue }
            #if DEBUG
            if key.contains("(unknown context") {
                print("SwiftWUI snapshot: state of private/local type won't survive hydration — make the component internal or public (key: '\(key)')")
            }
            #endif
            var slots: [String] = []
            slots.reserveCapacity(boxes.count)
            for box in boxes {
                guard let enc = box as? _SnapshotEncodableBox,
                      let json = enc._encodeJSON(encode) else { continue outer }
                slots.append(json)
            }
            out[key] = slots
        }
        return out
    }
}
