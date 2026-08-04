import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

private struct Interactive: Tag {
    var body: some Tag { Button("no") { } }
}
private struct Stateful: Tag {
    @State var n = 0
    var body: some Tag { Div { Text("\(n)") } }
}
private struct LinkInBoot: Tag {
    var body: some Tag { Link("/") { Text("home") } }
}
private struct Effectful: Tag {
    var body: some Tag { Div { Text("x") }.onAppear { } }
}

@Suite @MainActor struct BootProbeTests {
    @Test func listenersAndStateAreReported() {
        #expect(BootProbe.check(AnyTag(Interactive())).contains { $0.isError })
        #expect(BootProbe.check(AnyTag(Stateful())).contains { $0.isError })
        #expect(BootProbe.check(AnyTag(Effectful())).contains { $0.isError })
    }

    /// `Link` registers an internal click handler yet navigates perfectly well
    /// through its own <a href>. Warning, not an error.
    @Test func linkIsExemptAndOnlyWarns() {
        let found = BootProbe.check(AnyTag(LinkInBoot()))
        #expect(!found.contains { $0.isError })
        #expect(found.contains { !$0.isError })
    }

    /// A Link next to a real handler must not launder it: the exemption is per
    /// listener, not "all or nothing".
    @Test func aLinkDoesNotExemptItsNeighbours() {
        let mixed = AnyTag(Div { Link("/") { Text("home") }; Button("no") { } })
        #expect(BootProbe.check(mixed).contains { $0.isError })
    }

    @Test func plainMarkupIsClean() {
        #expect(BootProbe.check(AnyTag(Div(class: "x") { Text("y") })).isEmpty)
    }
}

// MARK: - The two surfaces that report

private struct DeadOverlay: Tag {
    @State var dots = 0
    var body: some Tag { Div(class: "spin") { Button("retry") { } } }
}
private struct HomeBody: Tag {
    var body: some Tag { Main { H1("Home") } }
}
private struct DeadOverlayPage: Page {
    var title: String { "Home" }
    var body: some Tag { HomeBody() }
}
private struct DeadOverlayApp: App {
    static var bootUI: BootUI { .overlay { DeadOverlay() } }
    var body: some Tag { Router { Route("/") { DeadOverlayPage() } } }
}

private struct StatefulPlaceholder: Tag {
    @State var n = 0
    var body: some Tag { Div(class: "skeleton") { Text("\(n)") } }
}
private struct PlaceholderPage: Page {
    var title: String { "Home" }
    var body: some Tag { HomeBody().whileBooting { StatefulPlaceholder() } }
}
private struct PlaceholderApp: App {
    var body: some Tag { Router { Route("/") { PlaceholderPage() } } }
}

private struct CleanPage: Page {
    var title: String { "Home" }
    var body: some Tag { HomeBody() }
}
private struct CleanApp: App {
    static var bootUI: BootUI { .overlay { Div(class: "spin") { Text("Loading…") } } }
    var body: some Tag { Router { Route("/") { CleanPage() } } }
}

@Suite @MainActor struct BootProbeReportingTests {
    private var config: StaticSiteConfig {
        .init(outDir: "/tmp/swiftwui-bootprobe", mode: .hydrate(wasmScriptPath: "/app/index.js"))
    }

    /// The specific case, never just "it threw": `generate()` throws for a
    /// dozen unrelated reasons (`.io` on the write loop above all), and matching
    /// `StaticSiteError.self` alone would pass on any of them.
    private func bootProblems<A: App>(_ app: A.Type) async -> [String]? {
        do { _ = try await StaticSite.generate(app, config: config) } catch {
            guard case .bootUIUnsupported(let problems)? = error as? StaticSiteError else {
                Issue.record("generate() threw \(error), not a boot-UI failure")
                return nil
            }
            return problems
        }
        Issue.record("generate() succeeded on boot UI that cannot work")
        return nil
    }

    /// The requirement the whole task turns on: a build FAILS, and it fails by
    /// throwing rather than by asserting — `swiftwui build` defaults to
    /// `-c release`, where an assert is stripped and the check would vanish.
    /// This test would fail in a release test run if the mechanism were one.
    @Test func generateFailsOnDeadBootUI() async {
        guard let problems = await bootProblems(DeadOverlayApp.self) else { return }
        #expect(problems.contains { $0.contains("@State") })
        #expect(problems.contains { $0.contains("event handler") })
    }

    /// `@State` in a `.whileBooting` placeholder is caught too — those rows are
    /// real: they enter `ctx.reachable`, are retained, and ship into the
    /// snapshot. The app declares no `bootUI`, so nothing but the placeholder
    /// can be the source.
    @Test func generateFailsOnStateInAPlaceholder() async {
        guard let problems = await bootProblems(PlaceholderApp.self) else { return }
        #expect(problems.allSatisfy { $0.hasPrefix(".whileBooting placeholder") })
        #expect(problems.contains { $0.contains("@State") })
    }

    /// The probe must not fail an honest boot UI, or every author turns it off.
    /// A full `generate()`, not a `render()`: only the former runs the gate.
    @Test func markupOnlyBootUIGeneratesClean() async throws {
        let out = NSTemporaryDirectory() + "swiftwui-bootprobe-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: out) }
        let report = try await StaticSite.generate(
            CleanApp.self, config: .init(outDir: out, mode: .hydrate(wasmScriptPath: "/app/index.js")))
        #expect(report.pages == ["/"])
    }

    /// The boot-shell subcommand's surface stays non-fatal: `BootShellRunner`
    /// reads a non-zero exit as "this project predates boot UI" and would then
    /// build without the boot UI entirely. It reports on stderr and returns a
    /// payload like any other.
    @Test func bootShellStillAnswersForDeadBootUI() {
        let payload = StaticSite.renderBootShell(DeadOverlayApp.self)
        #expect(!payload.html.isEmpty)
    }
}
