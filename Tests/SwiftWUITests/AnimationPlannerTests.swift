import Testing
@testable import SwiftWUI

@Suite struct AnimationPlannerTests {
    @Test func additiveForMatchingUnits() {
        let r = AnimationPlanner.request(property: "translate", from: "10px 20px", to: "30px 20px",
                                          timing: Animation.linear(duration: 1).resolved())!
        #expect(r.mode == .additive)
        #expect(r.from == "-20px 0px")
        #expect(r.to == "0px 0px")
    }
    @Test func replaceForColors() {
        let r = AnimationPlanner.request(property: "color", from: "red", to: "blue",
                                          timing: Animation.linear(duration: 1).resolved())!
        #expect(r.mode == .replace)
        #expect(r.from == "red")
        #expect(r.to == "blue")
    }
    @Test func nilForNoPrevious() {
        let r = AnimationPlanner.request(property: "opacity", from: nil, to: "1",
                                          timing: Animation.linear(duration: 1).resolved())
        #expect(r == nil)
    }
    @Test func nilForIdentical() {
        let r = AnimationPlanner.request(property: "opacity", from: "1", to: "1",
                                          timing: Animation.linear(duration: 1).resolved())
        #expect(r == nil)
    }
    @Test func unitlessOpacityAdditive() {
        let r = AnimationPlanner.request(property: "opacity", from: "0.5", to: "1",
                                          timing: Animation.linear(duration: 1).resolved())!
        #expect(r.mode == .additive)
        #expect(r.from == "-0.5")
        #expect(r.to == "0")
    }
    @Test func commaSeparatedRoundTrip() {
        let r = AnimationPlanner.request(property: "background-position", from: "10px, 20px", to: "30px, 40px",
                                          timing: Animation.linear(duration: 1).resolved())!
        #expect(r.mode == .additive)
        #expect(r.from == "-20px, -20px")
        #expect(r.to == "0px, 0px")
    }
    @Test func mismatchedShapeIsReplace() {
        let r = AnimationPlanner.request(property: "transform", from: "10px", to: "10px 20px",
                                          timing: Animation.linear(duration: 1).resolved())!
        #expect(r.mode == .replace)
        #expect(r.from == "10px")
        #expect(r.to == "10px 20px")
    }

    @Test func mockSettleAnimationIsIdempotent() {
        let backend = MockBackend()
        let node = backend.createElement("div")
        let request = AnimationRequest(property: "opacity", from: "0", to: "1",
                                        mode: .replace, timing: Animation.linear(duration: 1).resolved())
        var settleCount = 0
        _ = backend.animate(node, request: request) { _ in settleCount += 1 }
        backend.settleAnimation(at: 0)
        backend.settleAnimation(at: 0)
        #expect(settleCount == 1)
    }
}
