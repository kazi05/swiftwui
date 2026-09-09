import Testing
@testable import SwiftWUI

@MainActor
private final class ObjectURLCounter {
    var value = 0
}

@MainActor
private final class WeakObjectURL {
    weak var value: WebObjectURL?
    init(_ value: WebObjectURL?) { self.value = value }
}

@MainActor
private func resolvedElement(_ tag: some Tag) -> ElementNode {
    var context = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                                 invalidate: { _ in })
    let nodes = resolve(tag, path: .root, ctx: &context)
    guard case .element(let element) = nodes.first else {
        preconditionFailure("expected one resolved element")
    }
    return element
}

@MainActor
private func element(_ tag: String, id: NodeIdentity = .root,
                     attributes: [String: String] = [:],
                     objectURLs: [String: WebObjectURL] = [:],
                     children: [Node] = []) -> Node {
    .element(ElementNode(identity: id, tag: tag, attributes: attributes,
                         objectURLs: objectURLs,
                         listeners: [:], observers: [:], children: children, key: nil))
}

@Suite @MainActor
struct ObjectURLRenderingTests {
    @Test func typedConstructorsAndModifiersResolveResources() {
        let imageURL = WebObjectURL(url: "blob:image", revoke: {})
        let videoURL = WebObjectURL(url: "blob:video", revoke: {})
        let audioURL = WebObjectURL(url: "blob:audio", revoke: {})
        let linkURL = WebObjectURL(url: "blob:link", revoke: {})

        let image = resolvedElement(Img(src: imageURL, alt: "Preview", width: 20))
        #expect(image.objectURLs["src"] === imageURL)
        #expect(image.attributes["alt"] == "Preview")
        #expect(image.attributes["width"] == "20")

        let videoBuilder = resolvedElement(Video(src: videoURL, controls: true) { Text("fallback") })
        #expect(videoBuilder.objectURLs["src"] === videoURL)
        #expect(videoBuilder.attributes["controls"] == "")
        let videoEmpty = resolvedElement(Video(src: videoURL))
        #expect(videoEmpty.objectURLs["src"] === videoURL)
        #expect(resolvedElement(Video().source(videoURL)).objectURLs["src"] === videoURL)

        let audioBuilder = resolvedElement(Audio(src: audioURL, autoplay: true) { Text("fallback") })
        #expect(audioBuilder.objectURLs["src"] === audioURL)
        #expect(audioBuilder.attributes["autoplay"] == "")
        let audioEmpty = resolvedElement(Audio(src: audioURL))
        #expect(audioEmpty.objectURLs["src"] === audioURL)
        #expect(resolvedElement(Audio().source(audioURL)).objectURLs["src"] === audioURL)

        let anchorBuilder = resolvedElement(A(href: linkURL, target: .blank) { Text("download") })
        #expect(anchorBuilder.objectURLs["href"] === linkURL)
        #expect(anchorBuilder.attributes["target"] == "_blank")
        let anchorEmpty = resolvedElement(A(href: linkURL))
        #expect(anchorEmpty.objectURLs["href"] === linkURL)
        #expect(resolvedElement(A(href: "/fallback").destination(linkURL)).objectURLs["href"] === linkURL)

        #expect(resolvedElement(Img(src: "/fallback", alt: "Preview").source(imageURL))
            .objectURLs["src"] === imageURL)
    }

    @Test func laterOrdinaryAttributeReplacesTypedResourceCaseInsensitively() {
        let url = WebObjectURL(url: "blob:test-resource", revoke: {})
        let image = resolvedElement(
            Img(src: url, alt: "Preview").attribute("SRC", "/fallback.png")
        )

        #expect(image.objectURLs.isEmpty)
        #expect(image.attributes["SRC"] == "/fallback.png")
    }

    @Test func laterTypedResourceReplacesOrdinaryAttributeCaseInsensitively() {
        let url = WebObjectURL(url: "blob:test-resource", revoke: {})
        let image = resolvedElement(
            Img(src: "/first.png", alt: "Preview")
                .attribute("SRC", "/second.png")
                .source(url)
        )

        #expect(image.objectURLs["src"] === url)
        #expect(image.attributes.keys.allSatisfy { $0.lowercased() != "src" })
    }

    @Test func nilOrdinaryAttributeDoesNotRemoveTypedResource() {
        let url = WebObjectURL(url: "blob:test-resource", revoke: {})
        let image = resolvedElement(
            Img(src: url, alt: "Preview").attribute("SRC", nil as String?)
        )

        #expect(image.objectURLs["src"] === url)
    }

    @Test func localizedAttributeWinsOverTypedResource() {
        let url = WebObjectURL(url: "blob:test-resource", revoke: {})
        let localized = LocalizedText(key: "preview-source") { _ in "/localized.png" }
        let image = resolvedElement(
            Img(src: url, alt: "Preview").attribute("SRC", localized)
        )

        #expect(image.objectURLs.isEmpty)
        #expect(image.attributes["SRC"] == "/localized.png")
    }

    @Test func revokedResourceIsFilteredDuringResolution() {
        let revocations = ObjectURLCounter()
        let url = WebObjectURL(url: "blob:revoked") { revocations.value += 1 }
        url.revoke()
        url.revoke()

        let image = resolvedElement(Img(src: url, alt: "Preview"))
        #expect(revocations.value == 1)
        #expect(image.objectURLs.isEmpty)
        #expect(image.attributes["src"] == nil)
    }

    @Test func reconcilerUsesIdentityAndOrdersResourceReplacementSafely() {
        let oldURL = WebObjectURL(url: "blob:old", revoke: {})
        let equalAlias = oldURL
        let newURL = WebObjectURL(url: "blob:new", revoke: {})
        let reconciler = Reconciler()

        #expect(reconciler.diff(
            old: element("img", objectURLs: ["src": oldURL]),
            new: element("img", objectURLs: ["src": equalAlias])
        ).isEmpty)
        #expect(reconciler.diff(
            old: element("img", objectURLs: ["src": oldURL]),
            new: element("img", objectURLs: ["src": newURL])
        ) == [.setObjectURL(name: "src", value: newURL)])
        #expect(reconciler.diff(
            old: element("img", objectURLs: ["src": oldURL]),
            new: element("img", attributes: ["src": "/fallback.png"])
        ) == [
            .setObjectURL(name: "src", value: nil),
            .setAttribute(name: "src", value: "/fallback.png"),
        ])
        #expect(reconciler.diff(
            old: element("img", attributes: ["src": "/fallback.png"]),
            new: element("img", objectURLs: ["src": newURL])
        ) == [
            .removeAttribute(name: "src"),
            .setObjectURL(name: "src", value: newURL),
        ])
    }

    @Test func mountAndHydrationForwardResources() {
        let url = WebObjectURL(url: "blob:preview", revoke: {})
        let base = MockBackend()
        let existing = base.createElement("img")
        base.insert(existing, into: base.container, before: nil)
        let adopting = AdoptingBackend(base: base, container: base.container)
        let applier = TreeApplier(backend: adopting, container: base.container)

        let mounted = applier.mount(element("img", objectURLs: ["src": url]),
                                    hostParent: base.container, before: nil)

        #expect(mounted.host === existing)
        #expect(existing.objectURLs["src"] === url)
        #expect(adopting.finishAdoption())

        let laterURL = WebObjectURL(url: "blob:after-hydration", revoke: {})
        adopting.setObjectURL(existing, name: "src", value: laterURL)
        #expect(existing.objectURLs["src"] === laterURL)
    }

    @Test func appliedIdentityUpdateReleasesOldResourceAndRetainsNewResource() {
        var oldURL: WebObjectURL? = WebObjectURL(url: "blob:old", revoke: {})
        let oldReference = WeakObjectURL(oldURL)
        let newURL = WebObjectURL(url: "blob:new", revoke: {})
        var oldNode: Node? = element("img", objectURLs: ["src": oldURL!])
        let newNode = element("img", objectURLs: ["src": newURL])
        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        let mounted = applier.mount(oldNode!, hostParent: backend.container, before: nil)

        let patches = Reconciler().diff(old: oldNode!, new: newNode)
        oldNode = nil
        oldURL = nil
        #expect(oldReference.value != nil)
        applier.apply(patches, to: mounted)

        #expect(oldReference.value == nil)
        #expect(mounted.objectURLs["src"] === newURL)
        #expect(mounted.host?.objectURLs["src"] === newURL)
        #expect(backend.counts["setObjectURL"] == 2)
    }

    @Test func serializationOmitsObjectURLHandles() {
        let url = WebObjectURL(url: "blob:must-not-serialize", revoke: {})
        let node = element("img", attributes: ["alt": "Preview"], objectURLs: ["src": url])
        #expect(HTMLRenderer._render([node]) == #"<img alt="Preview">"#)
        #expect(!HTMLRenderer.render(Img(src: url, alt: "Preview")).contains("blob:"))
        let rendered = HTMLRenderer.renderWithStylesheet(Img(src: url, alt: "Preview"))
        #expect(!rendered.html.contains("blob:"))
        #expect(!rendered.css.contains("blob:"))

        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        _ = applier.mount(node, hostParent: backend.container, before: nil)
        #expect(backend.serializeHTML() == #"<img alt="Preview">"#)
    }

    @Test func mockBackendClearsDescendantResourceRecordsOnHostRemoval() {
        let url = WebObjectURL(url: "blob:mock-record", revoke: {})
        let backend = MockBackend()
        let parent = backend.createElement("div")
        let child = backend.createElement("img")
        backend.setObjectURL(child, name: "src", value: url)
        backend.insert(child, into: parent, before: nil)
        backend.insert(parent, into: backend.container, before: nil)

        backend.remove(parent, from: backend.container)

        #expect(child.objectURLs.isEmpty)
    }

    @Test func sharedHandleLivesUntilEveryMountedConsumerIsRemoved() {
        var url: WebObjectURL? = WebObjectURL(url: "blob:shared", revoke: {})
        let weakURL = WeakObjectURL(url)
        var firstNode: Node? = element("img", objectURLs: ["src": url!])
        var secondNode: Node? = element("a", objectURLs: ["href": url!])
        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        let first = applier.mount(firstNode!, hostParent: backend.container, before: nil)
        let second = applier.mount(secondNode!, hostParent: backend.container, before: nil)
        // MockBackend records handles for diff assertions. Clear those test-double
        // references so this test proves MountedNode is the lifetime owner.
        first.host?.objectURLs.removeAll()
        second.host?.objectURLs.removeAll()
        firstNode = nil
        secondNode = nil
        url = nil

        #expect(weakURL.value != nil)
        applier.unmount(first)
        #expect(first.objectURLs.isEmpty)
        #expect(weakURL.value != nil)
        applier.unmount(second)
        #expect(second.objectURLs.isEmpty)
        #expect(weakURL.value == nil)
    }

    @Test func replacementExitRetainsResourceUntilGhostRemoval() {
        var url: WebObjectURL? = WebObjectURL(url: "blob:exiting", revoke: {})
        let weakURL = WeakObjectURL(url)
        var oldNode: Node? = element("img", objectURLs: ["src": url!])
        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        let registry = TransitionRegistry()
        applier.transitionsRef = registry
        registry.register(.opacity.animation(.linear(duration: 1)), for: .root)
        let mounted = applier.mount(oldNode!, hostParent: backend.container, before: nil)
        mounted.parent = applier.root
        mounted.indexInParent = 0
        applier.root.children = [mounted]
        // Simulate a backend that stores the URL string rather than the handle.
        mounted.host?.objectURLs.removeAll()
        oldNode = nil
        url = nil

        applier.animationPass = AnimationPassContext(transactions: [:], reduceMotion: false,
                                                     suppressTransitions: false,
                                                     defaultTransaction: nil)
        applier.apply([.replaceSelf(with: element("span"))], to: mounted)
        applier.animationPass = nil

        #expect(weakURL.value != nil)
        #expect(mounted.objectURLs["src"] === weakURL.value)
        let exitIndex = backend.animations.firstIndex { $0.request.from == nil }!
        backend.settleAnimation(at: exitIndex)
        #expect(mounted.objectURLs.isEmpty)
        #expect(weakURL.value == nil)
    }

    @Test func parentExitRetainsDescendantResourceUntilSubtreeRemoval() {
        var url: WebObjectURL? = WebObjectURL(url: "blob:child", revoke: {})
        let weakURL = WeakObjectURL(url)
        let childID = NodeIdentity.root.appending(.child(0))
        var oldNode: Node? = element("div", children: [
            element("img", id: childID, objectURLs: ["src": url!]),
        ])
        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        let registry = TransitionRegistry()
        applier.transitionsRef = registry
        registry.register(.opacity.animation(.linear(duration: 1)), for: .root)
        let mounted = applier.mount(oldNode!, hostParent: backend.container, before: nil)
        let resourceMount = mounted.children[0]
        // Do not let MockNode's test record mask descendant MountedNode ownership.
        resourceMount.host?.objectURLs.removeAll()

        applier.animationPass = AnimationPassContext(transactions: [:], reduceMotion: false,
                                                     suppressTransitions: false,
                                                     defaultTransaction: nil)
        #expect(applier.beginExit(mounted, node: oldNode))
        applier.animationPass = nil
        oldNode = nil
        url = nil

        #expect(weakURL.value != nil)
        #expect(resourceMount.objectURLs["src"] === weakURL.value)
        backend.settleAnimation(at: 0)
        #expect(resourceMount.objectURLs.isEmpty)
        #expect(weakURL.value == nil)
    }
}
