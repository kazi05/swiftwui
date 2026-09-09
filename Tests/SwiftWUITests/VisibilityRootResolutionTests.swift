import Testing
@testable import SwiftWUI

@Suite @MainActor struct VisibilityRootResolutionTests {
    private func elements(_ nodes: [Node]) -> [ElementNode] {
        nodes.flatMap { node -> [ElementNode] in
            switch node {
            case .text: return []
            case .element(let e): return [e] + elements(e.children)
            case .component(let c): return elements(c.children)
            }
        }
    }

    @Test func nearestAncestorWinsAndTargetMarkerIsExcluded() {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(), invalidate: { _ in })
        let tag = Div(id: "outer") {
            Div(id: "inner") {
                Span(id: "leaf").onVisibilityChange(root: .ancestor(id: "same")) { _ in }
            }
            .visibilityRoot(id: "same")
            .onVisibilityChange(root: .ancestor(id: "same")) { _ in }
        }.visibilityRoot(id: "same")
        let all = elements(resolve(tag, path: .root, ctx: &ctx))
        #expect(all[1].configuredVisibility[0].root == .ancestor(all[0].identity))
        #expect(all[2].configuredVisibility[0].root == .ancestor(all[1].identity))
        #expect(all.allSatisfy { $0.attributes.keys.allSatisfy { !$0.contains("visibilityRoot") } })
        #expect(ctx.visibilityRoots.isEmpty)
    }

    @Test func siblingRootsDoNotLeakAndMissingDoesNotBecomeViewport() {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(), invalidate: { _ in })
        let tag = Section {
            Div { Span().onVisibilityChange(root: .ancestor(id: "same")) { _ in } }
                .visibilityRoot(id: "same")
            Div { Span().onVisibilityChange(root: .ancestor(id: "same")) { _ in } }
                .visibilityRoot(id: "same")
            Span().onVisibilityChange(root: .ancestor(id: "same")) { _ in }
        }
        let all = elements(resolve(tag, path: .root, ctx: &ctx))
        #expect(all[2].configuredVisibility[0].root == .ancestor(all[1].identity))
        #expect(all[4].configuredVisibility[0].root == .ancestor(all[3].identity))
        #expect(all[5].configuredVisibility[0].root == .unavailable)
    }

    @Test func configuredAndLegacyObserversCoexist() {
        let registry = ListenerRegistry()
        var ctx = ResolveContext(store: StateStore(), listeners: registry, invalidate: { _ in })
        var log: [Int] = []
        let tag = Div().onVisibilityChange { _ in log.append(0) }
            .onVisibilityChange(root: .viewport) { _ in log.append(1) }
            .onVisibilityChange(root: .viewport) { _ in log.append(2) }
        let e = elements(resolve(tag, path: .root, ctx: &ctx))[0]
        #expect(e.observers.count == 1 && e.configuredVisibility.count == 2)
        for observation in e.configuredVisibility {
            #expect(ctx.liveListeners.contains(observation.id))
            registry.handler(for: observation.id)?(true)
        }
        #expect(log == [1, 2])
    }
}
