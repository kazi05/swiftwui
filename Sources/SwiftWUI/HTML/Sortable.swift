public enum SortAxis: Sendable { case vertical, horizontal }

extension ForEach {
    /// Drag-reorder for the list (DnD spec §4). Requirements (debug-asserted):
    /// each row resolves to exactly ONE root node, and that root (or its first
    /// element descendant) is an HTML element. onMove owns the drag events on
    /// row roots — user drag modifiers on the same element are overwritten.
    /// Reorder is same-list only; a drag from another list shows a droppable
    /// cursor (shared content type) but its drop is a no-op.
    ///
    /// SwiftUI's `(IndexSet, Int)` shape deliberately not mirrored: `IndexSet`
    /// lives in full Foundation, which costs ~40 MB of ICU in wasm binaries;
    /// HTML5 DnD is single-item anyway. `action` receives (fromIndex,
    /// toInsertionOffset) with SwiftUI's toOffset semantics.
    public func onMove(axis: SortAxis = .vertical,
                       perform action: @escaping (Int, Int) -> Void) -> some Tag {
        _SortableCoordinator(forEach: self, axis: axis, action: action)
    }
}

/// Component boundary: owns drag state so writes re-render only this subtree.
struct _SortableCoordinator<Data: RandomAccessCollection, ID: Hashable, Content: Tag>: Tag {
    let forEach: ForEach<Data, ID, Content>
    let axis: SortAxis
    let action: (Int, Int) -> Void
    @State private var sourceIndex: Int? = nil
    @State private var hoverInsertion: Int? = nil
    @State private var rowExtent: Double = 0

    var body: some Tag {
        _SortableDecorator(forEach: forEach, axis: axis, action: action,
                           sourceIndex: $sourceIndex,
                           hoverInsertion: $hoverInsertion,
                           rowExtent: $rowExtent)
    }
}

let _sortableMoveType = "application/x-swiftwui.move"

struct _SortableDecorator<Data: RandomAccessCollection, ID: Hashable, Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let forEach: ForEach<Data, ID, Content>
    let axis: SortAxis
    let action: (Int, Int) -> Void
    let sourceIndex: Binding<Int?>
    let hoverInsertion: Binding<Int?>
    let rowExtent: Binding<Double>

    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        var nodes = resolve(forEach, path: path, ctx: &ctx)
        assert(nodes.count == forEach.data.count,
               "onMove requires a single root node per row")
        for i in nodes.indices {
            let decorated = Self.withFirstElement(&nodes[i]) { elem in
                self.decorate(&elem, index: i, ctx: &ctx)
            }
            assert(decorated, "onMove: row \(i) has no element root to decorate")
        }
        return nodes
    }

    /// Mutates the first element node in the subtree (row roots are usually
    /// elements; component roots are walked). Returns false if none found.
    static func withFirstElement(_ node: inout Node,
                                 _ mutate: (inout ElementNode) -> Void) -> Bool {
        switch node {
        case .element(var e):
            mutate(&e); node = .element(e); return true
        case .component(var c):
            for idx in c.children.indices
            where withFirstElement(&c.children[idx], mutate) {
                node = .component(c); return true
            }
            return false
        case .text:
            return false
        }
    }

    private func decorate(_ elem: inout ElementNode, index: Int,
                          ctx: inout ResolveContext) {
        // Live preview: while a move-drag is active, rows between the source
        // and the insertion point shift by one row extent; the source dims.
        // Styles exist ONLY mid-drag — user styling is untouched when idle.
        if let s = sourceIndex.wrappedValue {
            let translate = axis == .vertical ? "translateY" : "translateX"
            elem.style.set("transition", "transform 150ms ease")
            if index == s {
                elem.style.set("opacity", "0.4")
            } else if let ins = hoverInsertion.wrappedValue {
                let px = rowExtent.wrappedValue
                if ins > s, index > s, index < ins {
                    elem.style.set("transform", "\(translate)(-\(px)px)")
                } else if ins <= s, index >= ins, index < s {
                    elem.style.set("transform", "\(translate)(\(px)px)")
                }
            }
        }
        elem.attributes["draggable"] = "true"
        elem.attributes["data-swui-drag-type"] = _sortableMoveType
        elem.attributes["data-swui-drag"] = String(index)
        elem.attributes["data-swui-drop-accepts"] = _sortableMoveType

        let axis = self.axis
        let src = self.sourceIndex
        let hover = self.hoverInsertion
        let extent = self.rowExtent
        let act = self.action

        func install(_ event: String, _ handler: @escaping (Any?) -> Void) {
            let lid = ListenerID(owner: elem.identity, event: event)
            ctx.listeners.set(lid, payloadHandler: handler)
            ctx.liveListeners.insert(lid)
            elem.listeners[event] = lid
        }
        install("dragstart") { payload in
            let e = payload as? DragEvent ?? DragEvent()
            src.wrappedValue = index
            extent.wrappedValue = axis == .vertical ? e.targetHeight : e.targetWidth
        }
        install("dragover") { payload in
            guard src.wrappedValue != nil, let e = payload as? DragEvent else { return }
            let firstHalf = axis == .vertical
                ? e.offsetY < e.targetHeight / 2
                : e.offsetX < e.targetWidth / 2
            let insertion = firstHalf ? index : index + 1
            if hover.wrappedValue != insertion { hover.wrappedValue = insertion }
        }
        install("drop") { _ in
            if let s = src.wrappedValue {
                act(s, hover.wrappedValue ?? s)
            }
            src.wrappedValue = nil; hover.wrappedValue = nil
        }
        install("dragend") { _ in
            src.wrappedValue = nil; hover.wrappedValue = nil
        }
    }
}
