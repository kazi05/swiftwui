import Testing
@testable import SwiftWUI

@Suite struct OrderedStyleTests {
    @Test func lastWinsKeepsPosition() {
        var s = OrderedStyle()
        s.set("color", "red"); s.set("width", "10px"); s.set("color", "blue")
        #expect(s.cssText == "color: blue; width: 10px")
    }

    @Test func parserRoundTrip() {
        let s = OrderedStyle(parsing: "color: red; width: 10px")
        #expect(s.cssText == "color: red; width: 10px")
    }

    @Test func parserIgnoresSemicolonsInsideParens() {
        let s = OrderedStyle(parsing: "background: url(data:image/png;base64,AA); color: red")
        #expect(s["background"] == "url(data:image/png;base64,AA)")
        #expect(s["color"] == "red")
    }

    @Test func parserDropsChunkWithNoColon() {
        let s = OrderedStyle(parsing: "color: red; garbage; width: 10px")
        #expect(s.entries.count == 2)
        #expect(s["color"] == "red")
        #expect(s["width"] == "10px")
    }

    @Test func parserEmptyTextYieldsEmpty() {
        let s = OrderedStyle(parsing: "")
        #expect(s.isEmpty)
        #expect(s.cssText == "")
    }

    @Test func subscriptReturnsValueOrNil() {
        var s = OrderedStyle()
        s.set("color", "red")
        #expect(s["color"] == "red")
        #expect(s["width"] == nil)
    }

    @Test func mergeAppliesDeclarationsInOrder() {
        var s = OrderedStyle()
        s.merge([.color(.white), .display(.flex), .color(.black)])
        #expect(s.cssText == "color: #000; display: flex")
    }
}
