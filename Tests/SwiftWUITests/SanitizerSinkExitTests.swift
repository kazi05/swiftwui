import Testing
@testable import SwiftWUI

/// Each sanitizer sink traps in debug and drops in release. A trap ends the process,
/// so these run as exit tests; they fail if a sink stops calling its guard.
@Suite struct SanitizerSinkExitTests {
    @Test func attributeNameSinkTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            await MainActor.run { _ = Div().attribute("x onmouseover=alert(1)", "v") }
        }
        let stderr = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
        #expect(stderr.contains("invalid attribute name"))
    }

    @Test func inlineStyleSinkTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            await MainActor.run {
                var bag = _AttributeBag()
                bag.addStyle(StyleDeclaration(property: "color", value: "red} body {display:none"))
            }
        }
        let stderr = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
        #expect(stderr.contains("unsafe inline style value dropped"))
    }

    @Test func ruleBodySinkTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            await MainActor.run {
                _ = StyleRegistry.body([StyleDeclaration(property: "color", value: "red} body {display:none")])
            }
        }
        let stderr = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
        #expect(stderr.contains("unsafe CSS value dropped"))
    }
}
