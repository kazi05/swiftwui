import ArgumentParser

@main
struct SwiftWUICommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftwui",
        abstract: "SwiftWUI toolchain: scaffold, develop, build and prerender SwiftWUI sites.",
        version: "0.6.0",
        subcommands: [Init.self, Build.self, Dev.self, SSG.self, Serve.self])
}
