import ArgumentParser
import SwiftWUIToolchain

@main
struct SwiftWUICommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftwui",
        abstract: "SwiftWUI toolchain: scaffold, develop, build and prerender SwiftWUI sites.",
        version: SwiftWUIVersion.current,
        subcommands: [Init.self, Build.self, Dev.self, SSG.self, Serve.self, Pwa.self, L10n.self, Metrics.self, Interop.self])
}
