import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Pwa: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pwa",
        abstract: "PWA tooling.",
        subcommands: [PwaInit.self])
}

struct PwaInit: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Add PWA artifacts (manifest, icons, service worker) to an existing project.")

    func run() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let name = (cwd as NSString).lastPathComponent
        let r = try Scaffolder.scaffoldPWA(into: cwd, name: name)
        for f in r.created { print("created \(f)") }
        for f in r.skipped { print("skipped \(f) (exists)") }
        if r.created.isEmpty { print("nothing to do — PWA artifacts already present") }
    }
}
