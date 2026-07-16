/// Drop zones & drag sources (DnD spec §3). HTMLTag-only, like all event
/// modifiers: they mutate the element's own attribute bag — no wrapper node.
/// One drop zone per element (a second dropDestination overwrites the
/// accepts attribute; handlers compose, so don't stack them).
extension HTMLTag {
    /// OS-file drop zone. `isTargeted(true)` on a valid drag entering,
    /// `false` on leave/drop. Wrong-type drags never target — the decode
    /// layer withholds preventDefault so the cursor shows not-allowed.
    public func dropDestination(
        for type: WebFile.Type,
        allowedTypes: [FileType] = [],
        action: @escaping ([WebFile], DropLocation) -> Bool,
        isTargeted: @escaping (Bool) -> Void = { _ in }
    ) -> Self {
        var copy = self
        let token = allowedTypes.isEmpty
            ? "Files"
            : "Files:" + allowedTypes.map(\.mime).joined(separator: ",")
        copy._attributes.set("data-swui-drop-accepts", token)
        copy._attributes.addHandler(.dragenter, payload: DragEvent.self) { e in
            if !e.isInternalTransition && e.hasFiles { isTargeted(true) }
        }
        copy._attributes.addHandler(.dragleave, payload: DragEvent.self) { e in
            if !e.isInternalTransition { isTargeted(false) }
        }
        // Listener presence makes decode run its acceptance/preventDefault
        // logic on every dragover tick; nothing to do Swift-side.
        copy._attributes.addHandler(.dragover, payload: DragEvent.self) { _ in }
        copy._attributes.addHandler(.drop, payload: DropEvent.self) { e in
            isTargeted(false)
            let files = allowedTypes.isEmpty
                ? e.files
                : e.files.filter { f in allowedTypes.contains { $0.matches(f) } }
            guard !files.isEmpty else { return }
            _ = action(files, DropLocation(x: e.x, y: e.y))
        }
        return copy
    }
}
