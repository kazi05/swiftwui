import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Interop: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Install or regenerate the app-owned BridgeJS boundary.", subcommands: [Init.self, Generate.self])

    struct Init: ParsableCommand {
        @Option(name: .long, help: "Existing executable target that should import AppInterop.") var target: String
        func run() throws {
            let root = FileManager.default.currentDirectoryPath
            for path in try InteropScaffolder.install(projectDir: root, target: target) { print("created \(path)") }
            try InteropScaffolder.generate(projectDir: root, runner: FoundationProcessRunner())
            print("BridgeJS bindings generated. Import AppInterop from \(target) and commit Interop/Sources/AppInterop/Generated/.")
        }
    }

    struct Generate: ParsableCommand {
        func run() throws {
            try InteropScaffolder.generate(projectDir: FileManager.default.currentDirectoryPath, runner: FoundationProcessRunner())
            print("BridgeJS bindings regenerated.")
        }
    }
}
