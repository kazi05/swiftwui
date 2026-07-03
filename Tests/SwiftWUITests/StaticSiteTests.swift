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
        #expect(about.contains("prerendered-fact\\\"") || about.contains("prerendered-fact"))  // value in snapshot rows
        #expect(about.contains("\"tasks\":["))                    // completed loader recorded
        #expect(about.contains("<script type=\"module\" src=\"/app.js\">"))
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

    @Test func cssFileModeWritesUnion() async throws {
        let out = tempDir()
        _ = try await StaticSite.generate(SiteApp.self, config: .init(
            outDir: out, mode: .staticOnly, cssFile: true))
        let home = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(home.contains("<link rel=\"stylesheet\" href=\"/styles.css\">"))
        #expect(!home.contains("<style data-swiftwui>"))
        #expect(FileManager.default.fileExists(atPath: out + "/styles.css"))
    }
}
