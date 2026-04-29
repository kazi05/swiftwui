import Testing
@testable import SwiftWUICore
@testable import SwiftWUIHTML
@testable import SwiftWUIState

private final class BoolBox: @unchecked Sendable { var value = false }

@Suite("Overlay modifiers")
struct OverlayTests {
    @Test("sheet renders no overlay when isPresented is false")
    func sheetHidden() {
        let box = BoolBox()
        let binding = Binding(get: { box.value }, set: { box.value = $0 })
        let tag = Div { "host" }.sheet(isPresented: binding) { Div { "modal" } }
        let nodes = resolveTagBody(tag)
        // Only the host Div, no overlay sibling.
        #expect(nodes.count == 1)
    }

    @Test("sheet renders overlay sibling when isPresented is true")
    func sheetVisible() {
        let box = BoolBox(); box.value = true
        let binding = Binding(get: { box.value }, set: { box.value = $0 })
        let tag = Div { "host" }.sheet(isPresented: binding) { Div { "modal" } }
        let nodes = resolveTagBody(tag)
        // Host Div + overlay Div.
        #expect(nodes.count == 2)
    }

    @Test("alert renders dialog with role=alertdialog when presented")
    func alertVisibleHasRole() {
        let box = BoolBox(); box.value = true
        let binding = Binding(get: { box.value }, set: { box.value = $0 })
        let tag = Div { "host" }
            .alert("Delete?", isPresented: binding) {
                Div { "ok" }
            }
        let nodes = resolveTagBody(tag)
        #expect(nodes.count == 2)
        // Walk the overlay subtree looking for role=alertdialog.
        let foundRole = containsAttribute(nodes[1], name: "role", value: "alertdialog")
        #expect(foundRole, "alert overlay must carry role=alertdialog for AT")
    }

    @Test("alert hidden when isPresented is false")
    func alertHidden() {
        let box = BoolBox()
        let binding = Binding(get: { box.value }, set: { box.value = $0 })
        let tag = Div { "host" }
            .alert("Title", isPresented: binding) { Div { "ok" } }
        let nodes = resolveTagBody(tag)
        #expect(nodes.count == 1)
    }

    @Test("sheet click on backdrop dismisses the binding")
    func sheetBackdropDismisses() {
        let box = BoolBox(); box.value = true
        let binding = Binding(get: { box.value }, set: { box.value = $0 })
        let tag = Div { "host" }.sheet(isPresented: binding) { Div { "modal" } }
        let nodes = resolveTagBody(tag)
        guard case .element(let overlay) = nodes[1],
              let listenerID = overlay.eventListeners["click"] else {
            Issue.record("expected click listener on overlay")
            return
        }
        // Fire the registered handler — should flip isPresented to false.
        EventHandlerRegistry.handler(for: listenerID)?()
        #expect(box.value == false)
    }

    // MARK: - Helpers

    /// Recursively walk a TagNode looking for an element whose attribute
    /// `name` equals `value`.
    private func containsAttribute(_ node: TagNode, name: String, value: String) -> Bool {
        switch node {
        case .text:
            return false
        case .element(let el):
            if el.attributes[name] == value { return true }
            return el.children.contains { containsAttribute($0, name: name, value: value) }
        case .fragment(let kids):
            return kids.contains { containsAttribute($0, name: name, value: value) }
        }
    }
}
