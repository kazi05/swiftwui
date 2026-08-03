import Testing
import Foundation
@testable import SwiftWUI
@testable import SwiftWUIStatic

private struct Widget: Tag {
    @State var n = 0
    var body: some Tag { Div(class: "chart") { Text("n=\(n)") } }
}
private struct WithSkeleton: Page {
    var title: String { "T" }
    var body: some Tag { Main { Widget().whileBooting { Div(class: "skel") { } } } }
}
private struct PlainVariant: Page {
    var title: String { "T" }
    var body: some Tag { Main { Widget() } }
}
private struct BootApp: App {
    init() {}
    static var bootUI: BootUI { .overlay { Div(class: "spin") { } } }
    var body: some Tag { Router { Route("/") { WithSkeleton() } } }
}
private struct PlainApp: App {
    init() {}
    var body: some Tag { Router { Route("/") { PlainVariant() } } }
}

/// Mirrors what `BootShim.stripBootNodes()` does to the parsed DOM, at the
/// string level: drop every `<template data-swui-boot-ui>…</template>` and every
/// veil attribute.
private func stripBootMarkup(_ html: String) -> String {
    var out = html
    while let open = out.range(of: "<template data-swui-boot-ui>"),
          let close = out.range(of: "</template>", range: open.upperBound..<out.endIndex) {
        out.removeSubrange(open.lowerBound..<close.upperBound)
    }
    return out.replacingOccurrences(of: " data-swui-boot-veil=\"\"", with: "")
              .replacingOccurrences(of: " data-swui-boot-veil", with: "")
}

@Suite @MainActor struct BootAdoptionTests {
    /// `stripBootNodes` is `JSObject` code behind `#if arch(wasm32)` and no
    /// native test can execute it — browser acceptance covers the real strip.
    /// What the native gate CAN prove is the property adoption depends on:
    /// boot markup is purely additive and removable. If removing it does not
    /// return the document to byte-identical no-boot output, then no strip,
    /// however written, can restore the stream `AdoptingBackend` expects.
    ///
    /// Body markup only, deliberately: `_WhileBootingTag` contributes a `.type`
    /// identity segment, so a wrapped `Widget`'s snapshot key genuinely differs
    /// from an unwrapped one. Task 4 owns that identity invariant.
    @Test func bootMarkupIsAdditiveAndRemovable() async throws {
        let cfg = StaticSiteConfig(outDir: "/tmp/unused",
                                   mode: .hydrate(wasmScriptPath: "/app/index.js"))
        let withBoot = try await StaticSite.render(BootApp.self, path: "/", config: cfg)
        let plain = try await StaticSite.render(PlainApp.self, path: "/", config: cfg)

        func bodyOf(_ html: String) throws -> String {
            let start = try #require(html.range(of: "<body>")).upperBound
            let end = try #require(html.range(of: "</body>")).lowerBound
            return String(html[start..<end])
        }
        let booted = try bodyOf(withBoot.html)
        // Non-vacuity: both markers must actually be in the body, or the
        // equality below would pass on an app that emits no boot markup at all.
        #expect(booted.contains("<template data-swui-boot-ui>"))
        #expect(booted.contains("data-swui-boot-veil"))
        #expect(try stripBootMarkup(booted) == bodyOf(plain.html))
    }
}
