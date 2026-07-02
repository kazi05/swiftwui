import Testing
@testable import SwiftWUI

@Suite struct StateTests {
    @Test func readWriteAndInvalidate() {
        let s = State(wrappedValue: 1)
        var fired = 0
        s._bindInvalidate { fired += 1 }
        s.wrappedValue = 2
        #expect(s.wrappedValue == 2)
        #expect(fired == 1)
    }
    @Test func invalidateRunsAfterWrite() {
        let s = State(wrappedValue: 1)
        var seen = -1
        s._bindInvalidate { seen = s.wrappedValue }   // didSet semantics: reads NEW value
        s.wrappedValue = 5
        #expect(seen == 5)
    }
    @Test func adoptRetargetsAllCopies_andBindingsFollow() {
        let a = State(wrappedValue: 1)
        let binding = a.projectedValue                // captured BEFORE adoption
        let persisted = StateBox(42)
        #expect(a._adopt(persisted))
        #expect(a.wrappedValue == 42)
        #expect(binding.wrappedValue == 42)           // binding followed the graft
        binding.wrappedValue = 43
        #expect(persisted.value == 43)                // writes reach the persisted box
    }
    @Test func adoptTypeMismatchReturnsFalse() {
        let s = State(wrappedValue: 1)
        #expect(!s._adopt(StateBox("string")))
        #expect(s.wrappedValue == 1)                  // untouched
    }
    @Test func bindingConstant() {
        let b = Binding.constant(9)
        b.wrappedValue = 10                           // no-op
        #expect(b.wrappedValue == 9)
    }
}
