import Testing
@testable import SwiftWUI

private struct Widget: Tag {
    @State var n = 0
    var body: some Tag {
        Div(class: "chart") {
            Text("n=\(n)")
            Button("+") { n += 1 }
        }
    }
}
private struct Skeleton: Tag { var body: some Tag { Div(class: "skel") { } } }
private struct Leaf: Tag {
    let label: String
    var body: some Tag { Span { Text(label) } }
}

private struct Host: Tag {
    var body: some Tag {
        Section { Widget().whileBooting { Skeleton() } }
    }
}

/// Every shape the spec's §11 golden claims to cover: an element wrapping a
/// component, a `ForEach` row, both sides of a conditional, and two chained
/// `.whileBooting`s (whose wrappers nest, each taking its own `.type` segment).
private struct MultiHost: Tag {
    let flag: Bool
    var body: some Tag {
        Div {
            Section { Widget().whileBooting { Skeleton() } }
            ForEach(["a", "b"], id: \.self) { s in
                Leaf(label: s).whileBooting { Skeleton() }
            }
            if flag {
                Leaf(label: "on").whileBooting { Skeleton() }
            } else {
                Leaf(label: "off").whileBooting { Skeleton() }
            }
            Widget().whileBooting { Skeleton() }.whileBooting { Skeleton() }
        }
    }
}

@MainActor private func resolveHost<T: Tag>(_ tag: T = Host(), buildRender: Bool) -> (nodes: [Node], ctx: ResolveContext) {
    var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                             invalidate: { _ in })
    ctx.isBuildRender = buildRender
    let nodes = resolve(tag, path: .root, ctx: &ctx)
    return (nodes, ctx)
}

/// Canonical paths of every component row of type `name`. Matched on the row's
/// own `typeName`, NOT on `canonicalString.contains(name)`: the wrapper's type
/// is `_WhileBootingTag<Widget, Skeleton>`, so its generic arguments appear in
/// the path of everything below it — including the placeholder's.
@MainActor private func canonicalStrings(ofComponent name: String, under nodes: [Node]) -> [String] {
    allComponentPaths(under: nodes, whereTypeName: { $0 == name })
}

/// Canonical paths of every component row the predicate accepts, in document
/// order. `nil` (an unregistered `.type`) becomes a sentinel rather than
/// vanishing, so a registration failure fails the comparison instead of
/// silently shrinking both sides.
@MainActor private func allComponentPaths(under nodes: [Node],
                                          whereTypeName accept: (String) -> Bool = { _ in true }) -> [String] {
    var out: [String] = []
    func walk(_ node: Node) {
        switch node {
        case .component(let c):
            if accept(c.typeName) { out.append(c.identity._canonicalString ?? "<unregistered>") }
            c.children.forEach(walk)
        case .element(let e):
            e.children.forEach(walk)
        case .text:
            break
        }
    }
    nodes.forEach(walk)
    return out
}

@Suite @MainActor struct WhileBootingTests {
    /// The invariant. `Widget`'s identity keys its @State row in the snapshot
    /// the SSG writes and the snapshot the browser reads; if the two renders
    /// disagree, state re-seeds and prerendered loader data is refetched — with
    /// no diagnostic, because the only one sits inside the branch where the key
    /// already matched.
    @Test func wrappedContentKeepsItsIdentityInBothRenders() {
        let build = resolveHost(buildRender: true)
        let browser = resolveHost(buildRender: false)
        let buildWidget = canonicalStrings(ofComponent: "Widget", under: build.nodes)
        let browserWidget = canonicalStrings(ofComponent: "Widget", under: browser.nodes)
        #expect(!buildWidget.isEmpty)
        #expect(buildWidget == browserWidget)
    }

    /// Spec §11 promises the golden covers "canonical strings for every node
    /// under a `.whileBooting` subtree", not just the one-widget shape above.
    /// Everything outside a placeholder subtree must match segment for segment;
    /// the placeholder rows are build-only by design, so they are excluded by
    /// their `.keyed` marker — the one segment that is allowed to differ.
    @Test(arguments: [true, false]) func everyNodeUnderAWhileBootingSubtreeKeepsItsIdentity(flag: Bool) {
        let build = allComponentPaths(under: resolveHost(MultiHost(flag: flag), buildRender: true).nodes)
            .filter { !$0.contains("/kswui-boot/") }
        let browser = allComponentPaths(under: resolveHost(MultiHost(flag: flag), buildRender: false).nodes)
        #expect(!build.isEmpty)
        #expect(build == browser)
    }

    /// A scoped pass re-resolves the row's own tag and skips back up through
    /// the wrapper's `_resolve`, so the veil has to be replayed the way
    /// `_StyledTag`'s is — or the build render commits an unveiled subtree and
    /// `BootCSS` never hides the real content. Reachable in the real SSG: the
    /// build-task drain pumps after every iteration, and a `.staticTask` write
    /// marks only its own component dirty (StaticSite.swift:584-605).
    @Test func veilSurvivesAScopedPassInTheBuildRender() throws {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Host(), scheduleMicrotask: sched.schedule)
        runtime._effects._buildMode = true
        runtime.mount()
        #expect(backend.serializeHTML().contains("data-swui-boot-veil"))

        let button = try #require(findFirst(backend.container, tag: "button"))
        runtime.dispatch(try #require(button.events["click"]))
        sched.pump()
        #expect(backend.serializeHTML().contains("data-swui-boot-veil"),
                "a state write dropped the veil — the real subtree ships visible")
    }

    @Test func buildRenderEmitsTemplateThenVeiledContent() throws {
        let html = HTMLRenderer._render(resolveHost(buildRender: true).nodes)
        let template = try #require(html.range(of: "<template data-swui-boot-ui>"))
        let veil = try #require(html.range(of: "data-swui-boot-veil"))
        #expect(template.lowerBound < veil.lowerBound, "placeholder must precede the content it stands in for")
        #expect(html.contains("class=\"skel\""))
        #expect(html.contains("class=\"chart\""))
    }

    @Test func browserRenderEmitsNeitherTemplateNorVeil() {
        let html = HTMLRenderer._render(resolveHost(buildRender: false).nodes)
        #expect(!html.contains("data-swui-boot-ui"))
        #expect(!html.contains("data-swui-boot-veil"))
        #expect(html.contains("class=\"chart\""))
    }
}
