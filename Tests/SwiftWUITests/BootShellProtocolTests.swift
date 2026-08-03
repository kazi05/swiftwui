import Testing
import Foundation
@testable import SwiftWUI
@testable import SwiftWUIStatic
@testable import SwiftWUIToolchain

private struct Spin: Tag {
    var body: some Tag { Div(class: "spin") { H1("Loading") } }
}
private struct ShellApp: App {
    static var bootUI: BootUI { .overlay(after: .ms(250)) { Spin() } }
    var body: some Tag { Router { Route("/") { Div { H1("home") } } } }
}
private struct NoShellApp: App {
    var body: some Tag { Router { Route("/") { Div { H1("home") } } } }
}

@Suite struct BootShellProtocolTests {
    /// Exit status carries no signal: a project scaffolded before this feature
    /// prints ArgumentParser usage to stdout and returns EXIT 0. The payload is
    /// therefore identified by content — the tagged key on the last non-empty line.
    @Test func parsesTheTaggedLineAndIgnoresStrayOutput() throws {
        let stdout = """
        some author print
        [logger] starting
        {"swiftwui-boot-shell":1,"html":"<template data-swui-boot-ui></template>","css":".a{}","delayMS":250}
        """
        let shell = try #require(BootShellRunner.parse(stdout: stdout))
        #expect(shell.delayMS == 250)
        #expect(shell.css == ".a{}")
    }

    @Test func rejectsUsageTextFromAnOlderProject() {
        let usage = "usage: MyApp ssg --out <dir> [--static]"
        #expect(BootShellRunner.parse(stdout: usage) == nil)
    }

    @Test func rejectsUntaggedJSON() {
        #expect(BootShellRunner.parse(stdout: #"{"html":"x","css":"","delayMS":0}"#) == nil)
    }

    /// The two halves of the wire contract live in different modules and are
    /// hand-written on both sides, so nothing but this catches a renamed key.
    /// Exactly what a template's `boot-shell` prints, straight into the parser.
    @Test func theSubcommandsLineParsesBack() throws {
        let payload = StaticSite.renderBootShell(ShellApp.self)
        let line = String(data: try JSONEncoder().encode(payload), encoding: .utf8)!
        #expect(!line.contains("\n"), "the payload must be one line: \(line)")
        let shell = try #require(BootShellRunner.parse(stdout: "author print\n" + line))
        #expect(shell.delayMS == 250)
        #expect(shell.html.contains("data-swui-boot-ui"))
        #expect(shell.css.contains("data-swui-boot-veil"))
    }

    /// `.none` is not a failure: the CLI reads the empty html as "no boot UI"
    /// and skips both the splice and the host compile.
    @Test func anAppWithoutBootUIRendersAnEmptyShell() throws {
        let payload = StaticSite.renderBootShell(NoShellApp.self)
        let line = String(data: try JSONEncoder().encode(payload), encoding: .utf8)!
        let shell = try #require(BootShellRunner.parse(stdout: line))
        #expect(shell.html.isEmpty)
        #expect(shell.css.isEmpty)
    }
}
