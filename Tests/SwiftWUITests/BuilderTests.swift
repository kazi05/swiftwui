import Testing
@testable import SwiftWUI

@Suite struct BuilderTests {
    @Test func stringBecomesText() {
        @TagBuilder func build() -> Text { "hello" }
        #expect(build().content == "hello")
    }
    @Test func multipleChildrenBecomeTupleTag() {
        @TagBuilder func build() -> TupleTag<Text, Text> { "a"; "b" }
        _ = build()   // type checked at compile time
    }
    @Test func ifElseBecomesConditional() {
        @TagBuilder func build(_ flag: Bool) -> ConditionalTag<Text, EmptyTag> {
            if flag { "yes" } else { EmptyTag() }
        }
        guard case .first(let t) = build(true) else { Issue.record("expected .first"); return }
        #expect(t.content == "yes")
        guard case .second = build(false) else { Issue.record("expected .second"); return }
    }
    @Test func bareIfBecomesOptional() {
        @TagBuilder func build(_ flag: Bool) -> Text? { if flag { "yes" } }
        #expect(build(true)?.content == "yes")
        #expect(build(false) == nil)
    }
    @Test func anyTagFlattensNesting() {
        let inner = AnyTag(Text("x"))
        let outer = AnyTag(inner)
        #expect(outer.base is Text)
    }
}
extension Text: Equatable { public static func == (l: Text, r: Text) -> Bool { l.content == r.content } }
