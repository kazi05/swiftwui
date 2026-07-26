import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

private struct OutcomeApp: App {
    init() {}
    var body: some Tag {
        Router(notFound: { P { Text("nope") } }) {
            Route("/") { P { Text("home") } }
            Route("/admin", guard: { .redirect("/") }) { P { Text("secret") } }
        }
    }
}

@Suite @MainActor struct RenderPrimitiveTests {
    @Test func rendersAPage() async throws {
        let r = try await StaticSite.render(OutcomeApp.self, path: "/",
                                            config: .init(outDir: "unused", mode: .staticOnly))
        #expect(r.outcome == .page)
        #expect(r.html.contains("home"))
    }

    @Test func reportsNotFound() async throws {
        let r = try await StaticSite.render(OutcomeApp.self, path: "/missing",
                                            config: .init(outDir: "unused", mode: .staticOnly))
        #expect(r.outcome == .notFound)
        #expect(r.html.contains("nope"))
    }

    @Test func reportsRedirect() async throws {
        let r = try await StaticSite.render(OutcomeApp.self, path: "/admin",
                                            config: .init(outDir: "unused", mode: .staticOnly))
        #expect(r.outcome == .redirect(to: "/", permanent: false))
    }

    // The invariant that keeps on-demand and build-time output from diverging.
    @Test func renderMatchesGenerateByteForByte() async throws {
        let out = NSTemporaryDirectory() + "swui-eq-\(UUID().uuidString)"
        _ = try await StaticSite.generate(OutcomeApp.self,
                                          config: .init(outDir: out, mode: .staticOnly))
        let fromDisk = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        let direct = try await StaticSite.render(OutcomeApp.self, path: "/",
                                                 config: .init(outDir: out, mode: .staticOnly))
        #expect(direct.html == fromDisk)
    }
}
