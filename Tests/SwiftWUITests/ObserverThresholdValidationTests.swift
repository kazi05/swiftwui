import Testing
@testable import SwiftWUI

@Suite struct ObserverThresholdValidationTests {
    @Test func negativeThresholdIsRejected() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = Div().onVisibilityChange(threshold: -0.1) { _ in }
            }
        }
    }

    @Test func thresholdAboveOneIsRejected() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = Div().onVisibilityChange(threshold: 1.1) { _ in }
            }
        }
    }

    @Test func nanThresholdIsRejected() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = Div().onVisibilityChange(threshold: .nan) { _ in }
            }
        }
    }

    @Test func infiniteThresholdIsRejected() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = Div().onVisibilityChange(threshold: .infinity) { _ in }
            }
        }
    }
}
