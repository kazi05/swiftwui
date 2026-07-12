import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scaffold a new SwiftWUI project.")

    @Argument(help: "Project name ([A-Za-z][A-Za-z0-9_]*).") var name: String
    @Option(name: .long, help: "Template: basic, mvvm, or tca.") var template: String = "basic"
    @Option(name: .long, help: "Path to a local SwiftWUI checkout (default: fetch from GitHub).")
    var swiftwuiPath: String?
    @Flag(name: .long, help: "Also scaffold PWA artifacts (manifest, icons, service worker).")
    var pwa = false

    func run() throws {
        let dir = FileManager.default.currentDirectoryPath + "/" + name
        try Scaffolder.scaffold(template: template, name: name, swiftwuiPath: swiftwuiPath, into: dir)
        if pwa {
            let r = try Scaffolder.scaffoldPWA(into: dir, name: name)
            for f in r.created { print("created \(f)") }
        }
        print("""
        created \(name)/ (template: \(template))
          cd \(name)
          swiftwui dev
        """)
    }
}
