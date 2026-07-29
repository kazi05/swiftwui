import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

/// The prerender writes two kinds of head link, and only one of them is the
/// app's. `<link rel="canonical">` and the hreflang set are computed from the
/// URL by SwiftWUIStatic; the wasm client has neither helper, neither
/// `siteURL` nor the locale list — so if hydration's `setLinks` sweep counts
/// them as part of the managed set, they are deleted the moment wasm boots and
/// nothing can put them back.
private struct MetaBody: Tag {
    var body: some Tag {
        Router {
            Route("/about") { _ in
                Div { Text("about") }.pageMeta(title: "About",
                                               links: [.icon("/favicon.svg")])
            }
        }
    }
}

private struct PrefixMetaSite: App {
    init() {}
    var body: some Tag { MetaBody() }
    static var localization: Localization? {
        Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                     strategy: .pathPrefix())
    }
}

private struct NavProbe: Tag {
    @Environment(\.navigate) var navigate
    var body: some Tag { Button("go") { navigate("/next") } }
}

@Suite @MainActor struct PrerenderedHeadLinksTests {
    @Test func hydratedPageKeepsCanonicalAndHreflangOutOfTheManagedSet() async throws {
        let out = NSTemporaryDirectory() + "swiftwui-ssg-" + UUID().uuidString
        _ = try await StaticSite.generate(PrefixMetaSite.self, config: .init(
            outDir: out, mode: .hydrate(wasmScriptPath: "/app.js"),
            siteURL: "https://example.com"))
        let ru = try String(contentsOfFile: out + "/ru/about/index.html", encoding: .utf8)

        // The app's own link stays managed: the client re-emits it every commit.
        #expect(ru.contains(#"<link href="/favicon.svg" rel="icon" data-swiftwui>"#))
        // The prerender's own links must NOT be, or `setLinks` deletes them at boot.
        #expect(ru.contains(#"<link href="https://example.com/ru/about" rel="canonical" data-swiftwui-ssg>"#))
        #expect(ru.contains(#"<link href="https://example.com/about" hreflang="en" rel="alternate" data-swiftwui-ssg>"#))
        #expect(ru.contains(#"<link href="https://example.com/about" hreflang="x-default" rel="alternate" data-swiftwui-ssg>"#))
        // `link[data-swiftwui]` is an exact attribute-NAME match, so the sweep
        // must find exactly one link — the icon — on this page.
        let swept = ru.split(separator: "\n").filter {
            $0.hasPrefix("<link") && $0.hasSuffix(" data-swiftwui>")
        }
        #expect(swept.count == 1)
    }

    /// Same page, no localization: the synthesized canonical alone still has to
    /// land outside the managed set.
    @Test func canonicalIsPrerenderOnlyWithoutLocalization() {
        let head = PageHead(title: "T", meta: [], links: [.icon("/f.svg")])
        let canonical = CanonicalSynthesis.synthesized(for: head, path: "/a",
                                                       siteURL: "https://x.test", enabled: true)
        let html = DocumentSerializer.render(.init(bodyHTML: "", head: head,
                                                   prerenderedLinks: [canonical!]))
        #expect(html.contains(#"<link href="/f.svg" rel="icon" data-swiftwui>"#))
        #expect(html.contains(#"<link href="https://x.test/a" rel="canonical" data-swiftwui-ssg>"#))
    }

    /// The other half of the contract: surviving the sweep means the client
    /// owns their removal, and every client-side URL move has to perform it.
    @Test func navigationDropsThem() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: NavProbe(), initialPath: "/", scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(backend.hasPrerenderedHeadLinks)          // hydration alone must not drop them
        rt.navigate(to: "/next")
        #expect(!backend.hasPrerenderedHeadLinks)
    }

    /// The forward that the whole fix rides on. A page carrying
    /// `data-swiftwui-ssg` links is BY DEFINITION prerendered, so it hydrates
    /// through AdoptingBackend and keeps it for the page lifetime — while the
    /// two tests above drive a bare MockBackend, i.e. the cold-mount path that
    /// never has links to drop. RendererBackend's default no-op makes a missing
    /// forward compile, so nothing but this notices its deletion.
    @Test func adoptingBackendForwardsTheDrop() {
        let base = MockBackend()
        let adopting = AdoptingBackend(base: base, container: base.container)
        adopting.dropPrerenderedHeadLinks()
        #expect(!base.hasPrerenderedHeadLinks)
    }

    @Test func backForwardDropsThem() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: NavProbe(), initialPath: "/", scheduleMicrotask: sched.schedule)
        rt.mount()
        rt.handlePopState(url: "/other")
        #expect(!backend.hasPrerenderedHeadLinks)
    }
}
