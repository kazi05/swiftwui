import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainPackageInfoTests {
    @Test func picksExecutableProduct() throws {
        let json = #"{"products":[{"name":"Lib","type":{"library":["automatic"]}},{"name":"MySite","type":{"executable":null}}]}"#
        let runner = MockRunner(results: ["swift package describe": .init(exitCode: 0, stdout: json, stderr: "")])
        #expect(try PackageInfo.executableProduct(in: "/x", runner: runner) == "MySite")
    }
    @Test func fallsBackToExecutableTarget() throws {
        let json = #"{"products":[],"targets":[{"name":"MySite","type":"executable"}]}"#
        let runner = MockRunner(results: ["swift package describe": .init(exitCode: 0, stdout: json, stderr: "")])
        #expect(try PackageInfo.executableProduct(in: "/x", runner: runner) == "MySite")
    }
    @Test func throwsWhenNone() {
        let runner = MockRunner(results: ["swift package describe": .init(exitCode: 0, stdout: #"{"products":[]}"#, stderr: "")])
        #expect(throws: ToolchainError.self) { _ = try PackageInfo.executableProduct(in: "/x", runner: runner) }
    }
}
