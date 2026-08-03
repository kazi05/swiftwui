import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

private struct SiteApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/") { HomePage() }
            Route("/about") { AboutPage() }
            Route("/todo/:id") { params in Text("todo \(params["id"] ?? "?")") }
            Route("/admin", guard: { .redirect("/") }) { Text("secret") }
        }
    }
}
private struct HomePage: Tag, Page {
    var title: String { "Home" }
    var body: some Tag { H1("Welcome") }
}
private struct AboutPage: Tag, Page {
    @State var fact = "loading"
    var title: String { "About" }
    var body: some Tag {
        P { Text(fact) }.staticTask { fact = "prerendered-fact" }
    }
}
private final class NotCodableBlob { var v = 1 }
private struct BrokenPage: Tag, Page {
    @State var blob = NotCodableBlob()
    var title: String { "Broken" }
    var body: some Tag {
        P { Text("x") }.staticTask { blob = NotCodableBlob() }
    }
}

private struct StaticVsDynamicApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/todo/1") { Text("literal") }
            Route("/todo/:id") { params in Text("todo \(params["id"] ?? "?")") }
        }
    }
}

private final class NotCodableBlob2 { var v = 2 }
private struct InnerLoader: Tag {
    @State var blob = NotCodableBlob2()
    var body: some Tag {
        P { Text("inner") }.staticTask { blob = NotCodableBlob2() }
    }
}
/// OuterPage's own row (`count`, never mutated) is encodable and, by tree
/// nesting, its identity path is a PREFIX of InnerLoader's nested task path —
/// exactly the shape the old path-prefix heuristic (I3) falsely matched on.
private struct OuterPage: Tag, Page {
    @State var count = 0
    var title: String { "Outer" }
    var body: some Tag { Div { InnerLoader() } }
}
private struct BuildAttributionApp: App {
    init() {}
    var body: some Tag { Router { Route("/") { OuterPage() } } }
}

@Suite @MainActor struct StaticSiteTests {
    func tempDir() -> String {
        let dir = NSTemporaryDirectory() + "swiftwui-ssg-\(UUID().uuidString)"
        return dir
    }

    @Test func generatesStaticRoutesAndExplicitDynamicPaths() async throws {
        let out = tempDir()
        let report = try await StaticSite.generate(SiteApp.self, config: .init(
            outDir: out, mode: .staticOnly, paths: ["/todo/1", "/todo/2"]))
        #expect(Set(report.pages) == ["/", "/about", "/todo/1", "/todo/2"])
        #expect(report.redirects == ["/admin": "/"])
        #expect(report.skippedPatterns.isEmpty)
        let home = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(home.contains("<h1>Welcome</h1>"))
        #expect(home.contains("<title>Home</title>"))
        #expect(!home.contains("application/swiftwui-state"))     // staticOnly: no snapshot
        #expect(!home.contains("type=\"module\""))                //             no boot script
        let todo = try String(contentsOfFile: out + "/todo/1/index.html", encoding: .utf8)
        #expect(todo.contains("todo 1"))
        let admin = try String(contentsOfFile: out + "/admin/index.html", encoding: .utf8)
        #expect(admin.contains("http-equiv=\"refresh\""))
        #expect(admin.contains("url=/"))
    }

    @Test func buildTaskResultLandsInHTMLAndSnapshot() async throws {
        let out = tempDir()
        _ = try await StaticSite.generate(SiteApp.self, config: .init(
            outDir: out, mode: .hydrate(wasmScriptPath: "/app.js")))
        let about = try String(contentsOfFile: out + "/about/index.html", encoding: .utf8)
        #expect(about.contains("prerendered-fact"))               // loader awaited before HTML
        #expect(about.contains("application/swiftwui-state"))
        // Assert the value lives INSIDE the snapshot script tag (not merely
        // somewhere in the document, e.g. the pre-rendered body HTML) — scriptJSON
        // escapes < > U+2028/2029 but not plain letters, so the raw string survives.
        let marker = "application/swiftwui-state\" data-swiftwui>"
        let afterMarker = try #require(about.range(of: marker))
        let snapshotRegion = about[afterMarker.upperBound...]
        let scriptEnd = try #require(snapshotRegion.range(of: "</script>"))
        #expect(snapshotRegion[..<scriptEnd.lowerBound].contains("prerendered-fact"))
        #expect(about.contains("\"tasks\":[\""))                  // completed loader recorded (non-empty list)
        #expect(about.contains(#"<script type="module">import { init } from "\/app.js"; await init();</script>"#))
        #expect(about.contains("<script type=\"importmap\">"))    // dist bundle's bare wasi-shim import needs this
        let mapRange = try #require(about.range(of: "<script type=\"importmap\">"))
        let moduleRange = try #require(about.range(of: "<script type=\"module\">import"))
        #expect(mapRange.lowerBound < moduleRange.lowerBound)
    }

    @Test func explicitDynamicPathWithQueryIsNotMisclassifiedAsRedirect() async throws {
        // _locationPath is query-stripped by Runtime; the requested path must be
        // stripped the same way before the redirect compare, or every query-bearing
        // explicit path misfires as a self-redirect stub (infinite refresh).
        struct TodoApp: App {
            init() {}
            var body: some Tag {
                Router { Route("/todo/:id") { params in Text("todo \(params["id"] ?? "?")") } }
            }
        }
        let out = tempDir()
        let report = try await StaticSite.generate(TodoApp.self, config: .init(
            outDir: out, mode: .staticOnly, paths: ["/todo/1?tab=all"]))
        #expect(report.redirects.isEmpty)
        let todo = try String(contentsOfFile: out + "/todo/1/index.html", encoding: .utf8)
        #expect(todo.contains("todo 1"))
        #expect(!todo.contains("http-equiv=\"refresh\""))
    }

    @Test func dynamicPatternWithoutPathsIsSkippedWithWarning() async throws {
        let out = tempDir()
        let report = try await StaticSite.generate(SiteApp.self, config: .init(
            outDir: out, mode: .staticOnly))
        #expect(report.skippedPatterns == ["/todo/:id"])
    }

    @Test func buildTaskOverflowThrows() async {
        struct LoopApp: App {
            init() {}
            var body: some Tag { Router { Route("/") { LoopPage() } } }
        }
        struct LoopPage: Tag {
            @State var n = 0
            var body: some Tag {
                // Statement 0's loader identity is constant (never re-schedules
                // after the first run). The ForEach item at index n-1 is a FRESH
                // identity each time n grows, so its loader always schedules a
                // brand-new build task — genuinely never quiesces.
                Div { Text("\(n)") }.staticTask { n += 1 }
                ForEach(0..<n, id: \.self) { i in
                    Div { Text("child \(i)") }.staticTask { n += 1 }
                }
            }
        }
        let out = tempDir()
        await #expect(throws: StaticSiteError.self) {
            _ = try await StaticSite.generate(LoopApp.self, config: .init(
                outDir: out, mode: .staticOnly))
        }
    }

    @Test func unserializableLoaderStateIsNotListedAsCompletedTask() async throws {
        struct BrokenApp: App {
            init() {}
            var body: some Tag { Router { Route("/") { BrokenPage() } } }
        }
        let out = tempDir()
        _ = try await StaticSite.generate(BrokenApp.self, config: .init(
            outDir: out, mode: .hydrate(wasmScriptPath: "/app.js")))
        let html = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        let marker = "application/swiftwui-state\" data-swiftwui>"
        let afterMarker = try #require(html.range(of: marker))
        let snapshotRegion = html[afterMarker.upperBound...]
        let scriptEnd = try #require(snapshotRegion.range(of: "</script>"))
        #expect(snapshotRegion[..<scriptEnd.lowerBound].contains("\"tasks\":[]"))
    }

    @Test func cssFileModeWritesUnion() async throws {
        let out = tempDir()
        _ = try await StaticSite.generate(SiteApp.self, config: .init(
            outDir: out, mode: .staticOnly, cssFile: true))
        let home = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        // Root-relative, not root-absolute (item 2: subdirectory deploys) — depth
        // 0 from the root page is just "styles.css".
        #expect(home.contains("<link rel=\"stylesheet\" href=\"styles.css\">"))
        #expect(!home.contains("<style data-swiftwui>"))
        #expect(FileManager.default.fileExists(atPath: out + "/styles.css"))
    }

    @Test func cssFileModeUsesRelativeHrefInSubdirectories() async throws {
        let out = tempDir()
        _ = try await StaticSite.generate(SiteApp.self, config: .init(
            outDir: out, mode: .staticOnly, paths: ["/todo/1"], cssFile: true))
        let home = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(home.contains("<link rel=\"stylesheet\" href=\"styles.css\">"))
        let todo = try String(contentsOfFile: out + "/todo/1/index.html", encoding: .utf8)
        #expect(todo.contains("<link rel=\"stylesheet\" href=\"../../styles.css\">"))
    }

    @Test func unmatchedConfigPathSurfacesInReport() async throws {
        let out = tempDir()
        let report = try await StaticSite.generate(SiteApp.self, config: .init(
            outDir: out, mode: .staticOnly, paths: ["/todo/1", "/does-not-exist"]))
        #expect(report.unmatchedPaths == ["/does-not-exist"])
    }

    @Test func staticPatternClaimsItsPathSoRedundantConfigPathDoesntDoubleRender() async throws {
        let out = tempDir()
        let report = try await StaticSite.generate(StaticVsDynamicApp.self, config: .init(
            outDir: out, mode: .staticOnly, paths: ["/todo/1"]))
        #expect(report.pages == ["/todo/1"])                  // not rendered twice
        #expect(report.skippedPatterns == ["/todo/:id"])       // path already claimed by the literal route
        #expect(report.unmatchedPaths.isEmpty)
    }

    @Test func writeAttributionExcludesUnrelatedNestedNonEncodableTask() async throws {
        let out = tempDir()
        _ = try await StaticSite.generate(BuildAttributionApp.self, config: .init(
            outDir: out, mode: .hydrate(wasmScriptPath: "/app.js")))
        let html = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        let marker = "application/swiftwui-state\" data-swiftwui>"
        let afterMarker = try #require(html.range(of: marker))
        let snapshotRegion = html[afterMarker.upperBound...]
        let scriptEnd = try #require(snapshotRegion.range(of: "</script>"))
        // InnerLoader's task wrote to its own (non-encodable) row. The old
        // path-prefix heuristic would have falsely matched it against the
        // unrelated ancestor OuterPage row — real write attribution (phase-6
        // I3) must exclude it regardless.
        #expect(snapshotRegion[..<scriptEnd.lowerBound].contains("\"tasks\":[]"))
    }
}

/// `/ghost`'s guard redirects to itself, which `Runtime.navigate` no-ops — the
/// render settles on the path it was asked for while `_routeMatched` is false,
/// so the Router falls through and the notFound content is the document body.
/// That is the only shape in which `generate()` reaches serialize with a
/// `.notFound` outcome (same fixture idea as `SitemapExcludesNotFoundTests`).
private struct FallThroughSite: App {
    init() {}
    var body: some Tag {
        Router(notFound: { Text("nothing here") }) {
            Route("/") { Text("home") }
            Route("/ghost", guard: { .redirect("/ghost") }) { Text("secret") }
        }
    }
}

/// Same fall-through shape, plus the site-wide `.pageMeta` canonical that makes
/// `tree.head` non-nil on a page no route matched: `_PageMetaTag` writes
/// `ctx.pageHeadPatch` from ABOVE the Router, and `commitRouteEffects` folds it
/// over an empty baseline. Synthesis stands down when the app declared its own,
/// so gating only the synthesized links would still ship this one.
private struct FallThroughSiteWithSiteWideCanonical: App {
    init() {}
    var body: some Tag {
        Router(notFound: { Text("nothing here") }) {
            Route("/") { Text("home") }
            Route("/ghost", guard: { .redirect("/ghost") }) { Text("secret") }
        }
        .pageMeta(links: [.canonical("https://example.com/")])
    }
}

@Suite @MainActor struct NotFoundIndexingTests {
    func tempDir() -> String { NSTemporaryDirectory() + "swiftwui-nf-\(UUID().uuidString)" }

    @Test func fallThroughPageIsNoindexedAndUncanonicalised() async throws {
        let out = tempDir()
        defer { try? FileManager.default.removeItem(atPath: out) }
        let report = try await StaticSite.generate(FallThroughSite.self, config: .init(
            outDir: out, mode: .staticOnly, siteURL: "https://example.com"))
        let html = try String(contentsOfFile: out + "/ghost/index.html", encoding: .utf8)
        // Full string, marker included: under `data-swiftwui` instead,
        // `setMetaTags` would sweep it on the first hydrated commit.
        #expect(html.contains("<meta content=\"noindex\" name=\"robots\" data-swiftwui-ssg>"))
        #expect(!html.contains("rel=\"canonical\""))
        #expect(report.notFoundPages.contains("/ghost"))
        #expect(!report.notFoundPages.contains("/"))
    }

    @Test func appDeclaredCanonicalIsStrippedFromAFallThrough() async throws {
        let out = tempDir()
        defer { try? FileManager.default.removeItem(atPath: out) }
        _ = try await StaticSite.generate(FallThroughSiteWithSiteWideCanonical.self, config: .init(
            outDir: out, mode: .staticOnly, siteURL: "https://example.com"))
        let ghost = try String(contentsOfFile: out + "/ghost/index.html", encoding: .utf8)
        #expect(ghost.contains("<meta content=\"noindex\" name=\"robots\" data-swiftwui-ssg>"))
        #expect(!ghost.contains("rel=\"canonical\""))     // noindex + canonical would poison the target URL
        let home = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(home.contains("rel=\"canonical\""))       // the real page keeps the app's own
        #expect(!home.contains("content=\"noindex\""))
    }

    @Test func realPageStillGetsItsCanonical() async throws {
        let out = tempDir()
        defer { try? FileManager.default.removeItem(atPath: out) }
        _ = try await StaticSite.generate(FallThroughSite.self, config: .init(
            outDir: out, mode: .staticOnly, siteURL: "https://example.com"))
        let html = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(html.contains("rel=\"canonical\""))
        #expect(!html.contains("content=\"noindex\""))
    }
}
