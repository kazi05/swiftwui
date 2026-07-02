import Testing
@testable import SwiftWUI

private struct ThemeKey: EnvironmentKey { static let defaultValue = "light" }
extension EnvironmentValues {
    var theme: String { get { self[ThemeKey.self] } set { self[ThemeKey.self] = newValue } }
}

private struct ThemedLabel: Tag {
    @Environment(\.theme) var theme
    var body: some Tag { P { theme } }
}
private struct EnvFixture: Tag {
    var body: some Tag {
        Div {
            ThemedLabel()                                   // default
            Div { ThemedLabel() }.environment(\.theme, "dark")
        }
    }
}

@MainActor @Suite struct EnvironmentTests {
    @Test func defaultsAndOverridesAndRestore() {
        let html = HTMLRenderer.render(EnvFixture())
        #expect(html.contains("<p>light</p>"))              // outside writer: default
        #expect(html.contains("<p>dark</p>"))               // inside writer: override
    }

    @Test func unlinkedWrapperFallsBackToDefault() {
        let label = ThemedLabel()
        #expect(label.theme == "light")                     // constructed outside runtime
    }

    @Test func writerAppendsOneIdentitySegment() {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(), invalidate: { _ in })
        let nodes = resolve(Div { EmptyTag() }.environment(\.theme, "x"), path: .root, ctx: &ctx)
        guard case .element(let el) = nodes[0] else { Issue.record("expected element"); return }
        #expect(el.identity.segments.count == 1)            // writer's .type segment, div at that path
    }
}
