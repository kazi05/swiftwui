import Testing
@testable import SwiftWUI

private struct DataPage: Tag {
    @State var price: Int? = nil
    var body: some Tag {
        P { Text("body") }
            .staticTask { price = 4320 }
            .pageMeta(title: price.map { "Махачкала → Москва от \($0) ₽" },
                      meta: price.map { [.description("от \($0) ₽")] })
    }
}

private struct PlainPage: Tag, Page {
    var title: String { "Plain" }
    var body: some Tag { P { Text("plain") } }
}

private struct LinksOnlyPage: Tag {                       // deliberately NOT a Page
    var body: some Tag {
        P { Text("b") }.pageMeta(links: [.canonical("https://x.test/b")])
    }
}

private struct LeakApp: Tag {
    var body: some Tag {
        Router {
            Route("/a") { PlainPage() }
            Route("/b") { LinksOnlyPage() }
        }
    }
}

@Suite @MainActor struct PageMetaTests {
    @Test func patchOverridesPageTitleInTheSamePass() {
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: TitlePatchApp(), scheduleMicrotask: { $0() })
        runtime.mount()
        #expect(backend.title == "patched")
    }

    @Test func unsetFieldsInheritThePagesOwnHead() {
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: TitlePatchApp(), scheduleMicrotask: { $0() })
        runtime.mount()
        #expect(backend.links.contains { $0.attributes["rel"] == "canonical" })
        #expect(backend.metaTags.contains { $0.attributes["name"] == "description" })
    }

    // The leak this design exists to prevent: /a sets title "Plain" via Page,
    // /b sets ONLY links and conforms to no Page — /b must not inherit "Plain".
    // `TestScheduler` lives in Tests/SwiftWUITests/RuntimeE2ETests.swift:42 and
    // is shared across the test target; `pump()` drains queued microtasks.
    @Test func headDoesNotLeakAcrossRoutes() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: LeakApp(), initialPath: "/a",
                              scheduleMicrotask: sched.schedule)
        runtime.mount()
        sched.pump()
        #expect(backend.title == "Plain")
        runtime.navigate(to: "/b")
        sched.pump()
        #expect(backend.title == "")
        #expect(backend.links.contains { $0.attributes["href"] == "https://x.test/b" })
    }

    @Test func patchAppliesAfterStaticTaskWrites() async throws {
        let backend = MockBackend()
        var queue: [() -> Void] = []
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: DataPage(), scheduleMicrotask: { queue.append($0) })
        runtime._effects._buildMode = true
        runtime.mount()
        while !queue.isEmpty { queue.removeFirst()() }
        _ = await runtime._effects._drainBuildTasks(store: runtime._store)
        while !queue.isEmpty { queue.removeFirst()() }
        #expect(backend.title == "Махачкала → Москва от 4320 ₽")
    }

    @Test func foldedOverKeepsUnsetFields() {
        let base = PageHead(title: "base", meta: [.description("d")], links: [.canonical("/c")])
        let patch = PageHeadPatch(title: "new", meta: nil, links: nil)
        let out = patch.folded(over: base)
        #expect(out.title == "new")
        #expect(out.meta == base.meta)
        #expect(out.links == base.links)
    }
}

private struct TitlePatchApp: Tag {
    var body: some Tag {
        Router {
            Route("/") { RichPage() }
        }
    }
}
private struct RichPage: Tag, Page {
    var title: String { "original" }
    var meta: [MetaTag] { [.description("from Page")] }
    var links: [LinkTag] { [.canonical("https://x.test/")] }
    var body: some Tag { P { Text("x") }.pageMeta(title: "patched") }
}

private struct JSONLDPage: Tag {
    var body: some Tag {
        P { Text("x") }.pageMeta(structuredData: [#"{"@type":"Offer","price":"4320"}"#])
    }
}

@Suite @MainActor struct StructuredDataTests {
    @Test func backendReceivesBlocks() {
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: JSONLDPage(), scheduleMicrotask: { $0() })
        runtime.mount()
        #expect(backend.structuredData == [#"{"@type":"Offer","price":"4320"}"#])
    }

    // Guards a hole this project has been bitten by: RendererBackend's default
    // implementation makes a missing forward COMPILE, and prerendered pages
    // then silently lose the feature while the dev server looks fine.
    @Test func adoptingBackendForwardsStructuredData() {
        let base = MockBackend()
        let adopting = AdoptingBackend(base: base, container: base.container)
        adopting.setStructuredData([#"{"a":1}"#])
        #expect(base.structuredData == [#"{"a":1}"#])
    }
}
