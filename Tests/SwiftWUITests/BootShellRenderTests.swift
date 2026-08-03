import Testing
@testable import SwiftWUI

private struct LocalizedSpinner: Tag {
    var body: some Tag {
        Div(class: "boot") {
            Text(LocalizedText(key: "boot.loading") { $0.language == "ru" ? "Загрузка…" : "Loading…" })
        }
    }
}

@Suite @MainActor struct BootShellRenderTests {
    @Test func shellRendersInsideAnInertTemplate() {
        let runtime = Runtime(backend: MockBackend(), container: MockNode(),
                              root: Div { Text("app") }, initialPath: "/",
                              scheduleMicrotask: { $0() })
        runtime.mount()
        let shell = runtime._renderBootShell(AnyTag(LocalizedSpinner()))
        #expect(shell.html.hasPrefix("<template data-swui-boot-ui>"))
        #expect(shell.html.hasSuffix("</template>"))
        #expect(shell.html.contains("class=\"boot\""))
    }

    /// The whole reason `_renderBootShell` exists rather than reusing
    /// `HTMLRenderer.renderWithStylesheet`: that path has no signals, so
    /// `\.locale` falls back to "en" and every localized document would ship
    /// the default language in its overlay.
    @Test func shellResolvesAgainstTheDocumentsLocale() {
        let ru = LocaleID("ru")!
        let runtime = Runtime(backend: MockBackend(), container: MockNode(),
                              root: Div { Text("app") }, initialPath: "/",
                              scheduleMicrotask: { $0() },
                              localization: Localization(supported: [LocaleID("en")!, ru], default: ru))
        runtime.mount()
        let shell = runtime._renderBootShell(AnyTag(LocalizedSpinner()))
        #expect(shell.html.contains("Загрузка…"))
    }

    @Test func bootCSSIsTheExactTwoRules() {
        #expect(BootCSS.text == """
        html:not([data-swui-boot]) [data-swui-boot-ui]{display:none!important}
        html[data-swui-boot] [data-swui-boot-veil]{display:none!important}
        """)
        // `display: revert` rolls back to the UA default, not the author's
        // flex/grid — it must never appear.
        #expect(!BootCSS.text.contains("revert"))
    }

    @Test func shellCSSDoesNotLeakIntoTheAppStylesheet() {
        let runtime = Runtime(backend: MockBackend(), container: MockNode(),
                              root: Div { Text("app") }, initialPath: "/",
                              scheduleMicrotask: { $0() })
        runtime.mount()
        let before = runtime._registryText
        // A pseudo rule, not a typed inline modifier: only rule modifiers reach
        // the registry at all, so this is what a leak would show up in.
        let shell = runtime._renderBootShell(AnyTag(Div(class: "x") { Text("y") }.hover { $0.padding(.px(4)) }))
        #expect(runtime._registryText == before)
        #expect(shell.css.contains(":hover { padding: 4px }"))
        #expect(shell.css.hasSuffix(BootCSS.text))
    }

    @Test func retryCarriesItsMarkerAndNoHandler() {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                                 invalidate: { _ in })
        ctx.isBuildRender = true
        let nodes = resolve(BootRetry { Text("Retry") }, path: .root, ctx: &ctx)
        let html = HTMLRenderer._render(nodes)
        #expect(html.contains("data-swui-boot-retry"))
        #expect(html.contains("Retry"))
        // No Swift closure can run in the failed state — there is no wasm.
        #expect(ctx.liveListeners.isEmpty)
    }
}
