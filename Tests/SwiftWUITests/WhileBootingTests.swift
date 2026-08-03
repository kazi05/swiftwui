import Testing
@testable import SwiftWUI

private struct Widget: Tag {
    @State var n = 0
    var body: some Tag { Div(class: "chart") { Text("n=\(n)") } }
}
private struct Skeleton: Tag { var body: some Tag { Div(class: "skel") { } } }

private struct Host: Tag {
    var body: some Tag {
        Section { Widget().whileBooting { Skeleton() } }
    }
}

@MainActor private func resolveHost(buildRender: Bool) -> (nodes: [Node], ctx: ResolveContext) {
    var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                             invalidate: { _ in })
    ctx.isBuildRender = buildRender
    let nodes = resolve(Host(), path: .root, ctx: &ctx)
    return (nodes, ctx)
}

/// Canonical paths of every component row of type `name`. Matched on the row's
/// own `typeName`, NOT on `canonicalString.contains(name)`: the wrapper's type
/// is `_WhileBootingTag<Widget, Skeleton>`, so its generic arguments appear in
/// the path of everything below it — including the placeholder's.
@MainActor private func canonicalStrings(ofComponent name: String, under nodes: [Node]) -> [String] {
    var out: [String] = []
    func walk(_ node: Node) {
        switch node {
        case .component(let c):
            if c.typeName == name { out.append(c.identity._canonicalString ?? "<unregistered>") }
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
