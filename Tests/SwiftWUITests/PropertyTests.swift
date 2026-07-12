import Testing
@testable import SwiftWUI

@MainActor @Suite struct PropertyTests {
    private func el(_ props: [String: PropertyValue]) -> Node {
        .element(ElementNode(identity: .root.appending(.child(0)), tag: "input",
                             attributes: ["type": "text"], properties: props,
                             listeners: [:], observers: [:], children: [], key: nil))
    }

    @Test func diffEmitsSetPropertyOnChange() {
        let patches = Reconciler().diff(old: el(["value": .string("a")]),
                                        new: el(["value": .string("b")]))
        #expect(patches == [.setProperty(name: "value", value: .string("b"))])
    }

    @Test func diffNeutralizesRemovedProperties() {
        let p1 = Reconciler().diff(old: el(["value": .string("a")]), new: el([:]))
        #expect(p1 == [.setProperty(name: "value", value: .string(""))])
        let p2 = Reconciler().diff(old: el(["checked": .bool(true)]), new: el([:]))
        #expect(p2 == [.setProperty(name: "checked", value: .bool(false))])
    }

    @Test func mountSetsProperties() {
        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        _ = applier.mount(el(["value": .string("x"), "checked": .bool(true)]),
                          hostParent: backend.container, before: nil)
        let node = findFirst(backend.container, tag: "input")!
        #expect(node.props["value"] == .string("x"))
        #expect(node.props["checked"] == .bool(true))
    }

    @Test func serializersAgreeOnProperties() {
        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        let node = el(["value": .string("a<b"), "checked": .bool(true), "off": .bool(false)])
        _ = applier.mount(node, hostParent: backend.container, before: nil)
        let viaMock = backend.serializeHTML()
        let viaRenderer = HTMLRenderer.render([node])
        #expect(viaMock == viaRenderer)
        #expect(viaRenderer == #"<input type="text" checked value="a&lt;b">"#)
    }
}
