import Testing
@testable import SwiftWUI

@Suite @MainActor struct VisibilityConfigurationTests {
    @Test func marginsAreCanonicalFiniteValues() {
        let value = VisibilityMargin(top: .px(-12), right: .percent(2.5),
                                     bottom: .px(-0.0), left: .percent(-10))
        #expect(value.css == "-12px 2.5% 0px -10%")
        #expect(VisibilityMargin.zero.css == "0px 0px 0px 0px")
        #expect(VisibilityMargin(top: .px(-0.0)) == .zero)
        #expect(Set([VisibilityMargin.zero, .init(top: .px(-0.0))]).count == 1)
        #expect(VisibilityMargin(top: .px(Double.greatestFiniteMagnitude)).top
                == .px(Double.greatestFiniteMagnitude))
    }

    @Test func markerDoesNotEmitDOMAttribute() {
        let element = Div().visibilityRoot(id: "timeline")
        #expect(element._attributes.flattened().isEmpty)
        #expect(element._attributes.visibilityRootID == "timeline")
    }
}

@Suite struct VisibilityConfigurationValidationTests {
    @Test func nonFiniteMarginIsRejected() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = VisibilityMargin(top: .px(.infinity)) }
        }
    }

    @Test func nanPercentageIsRejected() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = VisibilityMargin(bottom: .percent(.nan)) }
        }
    }

    @Test func negativeInfinityIsRejected() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = VisibilityMargin(left: .px(-.infinity)) }
        }
    }

    @Test func emptyMarkerIsRejected() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = Div().visibilityRoot(id: "") }
        }
    }

    @Test func emptyAncestorIsRejected() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = Div().onVisibilityChange(root: .ancestor(id: "")) { _ in } }
        }
    }

    @Test func configuredThresholdIsValidated() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = Div().onVisibilityChange(threshold: .nan, root: .viewport) { _ in } }
        }
    }
}
