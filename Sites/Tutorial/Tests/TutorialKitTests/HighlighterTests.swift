import Testing
@testable import TutorialKit

@Suite struct HighlighterTests {
    private func kinds(_ line: String) -> [(String, SwiftHighlighter.Kind)] {
        SwiftHighlighter.tokenize(line: line).map { ($0.text, $0.kind) }
    }

    @Test func stateDeclaration() {
        let t = kinds("    @State var count = 0")
        #expect(t.map(\.0) == ["    ", "@State", " ", "var", " count = ", "0"])
        #expect(t.map(\.1) == [.plain, .wrapper, .plain, .keyword, .plain, .number])
    }

    @Test func structHeader() {
        let t = kinds("struct Counter: Tag {")
        #expect(t.map(\.0) == ["struct", " ", "Counter", ": ", "Tag", " {"])
        #expect(t.map(\.1) == [.keyword, .plain, .type, .plain, .type, .plain])
    }

    @Test func stringWithInterpolationStaysOneToken() {
        let t = kinds(#"H1("Count: \(count)")"#)
        #expect(t.map(\.0) == ["H1", "(", #""Count: \(count)""#, ")"])
        #expect(t.map(\.1) == [.type, .plain, .string, .plain])
    }

    @Test func commentSwallowsRestOfLine() {
        let t = kinds("let x = 1 // trailing")
        #expect(t.last?.1 == .comment)
        #expect(t.last?.0 == "// trailing")
    }

    @Test func deterministicAcrossCalls() {
        let line = #"Route("/docs/:page") { params in Docs() }"#
        #expect(kinds(line).map(\.0) == kinds(line).map(\.0))
        #expect(kinds(line).map(\.1) == kinds(line).map(\.1))
    }

    @Test func roundTripPreservesText() {
        for line in ["struct Hello: Tag {", #"    P { "Knock, knock." }"#,
                     "        .padding(.px(12))", "}"] {
            let joined = SwiftHighlighter.tokenize(line: line).map(\.text).joined()
            #expect(joined == line)
        }
    }

    @Test func unterminatedStringConsumesRestOfLineSafely() {
        let t = kinds(#"let s = "unterminated"#)
        #expect(t.last?.1 == .string)
        #expect(SwiftHighlighter.tokenize(line: #"let s = "unterminated"#).map(\.text).joined()
                == #"let s = "unterminated"#)
    }

    @Test func bareTrailingAtSignIsAWrapperToken() {
        let t = kinds("something @")
        #expect(t.last?.0 == "@")
        #expect(t.last?.1 == .wrapper)
    }

    @Test func underscorePrefixedIdentifierStaysPlain() {
        let t = kinds("let _private = 1")
        #expect(t.contains { $0.0.contains("_private") && $0.1 == .plain })
    }
}
