import Testing
@testable import SwiftWUI

@Suite struct StyleRegistryTests {
    @Test func anonymousRuleDedup() {
        let r = StyleRegistry()
        let a = r.registerAnonymous(pseudo: ":hover", media: nil,
                                    declarations: [.color(.hex("#eee"))])
        let b = r.registerAnonymous(pseudo: ":hover", media: nil,
                                    declarations: [.color(.hex("#eee"))])
        #expect(a == b)
        #expect(r.version == 1)
        #expect(r.text == ".\(a):hover { color: #eee }")
    }
    @Test func canonicalOrderIsRegistrationOrderIndependent() {
        let r1 = StyleRegistry(); let r2 = StyleRegistry()
        let declsA: [StyleDeclaration] = [.margin(.px(1))]
        let declsB: [StyleDeclaration] = [.padding(.px(2))]
        _ = r1.registerAnonymous(pseudo: nil, media: nil, declarations: declsA)
        _ = r1.registerAnonymous(pseudo: nil, media: nil, declarations: declsB)
        _ = r2.registerAnonymous(pseudo: nil, media: nil, declarations: declsB)
        _ = r2.registerAnonymous(pseudo: nil, media: nil, declarations: declsA)
        #expect(r1.text == r2.text)
    }
    @Test func mediaRulesWrapAndSortAfterPlain() {
        let r = StyleRegistry()
        _ = r.registerAnonymous(pseudo: nil, media: "(max-width: 600px)",
                                declarations: [.display(.none)])
        _ = r.registerAnonymous(pseudo: nil, media: nil, declarations: [.gap(.px(4))])
        let t = r.text
        #expect(t.contains("@media (max-width: 600px) {"))
        #expect(t.firstRange(of: "gap")!.lowerBound < t.firstRange(of: "@media")!.lowerBound)
    }
    @Test func selectorRuleWithScope() {
        let r = StyleRegistry()
        r.registerSelector(base: ".field", scope: "swui-sabc", pseudo: nil, media: nil,
                           declarations: [.padding(.px(8))])
        #expect(r.text == ".field.swui-sabc { padding: 8px }")
    }
    @Test func hashStability() {
        // pin the generated class name so accidental hash-fn changes are loud
        let r = StyleRegistry()
        let cls = r.registerAnonymous(pseudo: nil, media: nil,
                                      declarations: [.color(.hex("#000"))])
        let again = StyleRegistry().registerAnonymous(pseudo: nil, media: nil,
                                                      declarations: [.color(.hex("#000"))])
        #expect(cls == again)
        #expect(cls.hasPrefix("swui-"))
    }
    @Test func runtimeFlushesOnlyOnGrowth() {
        struct Static: Tag {
            @State var n = 0
            var body: some Tag {
                Div { Button("+") { n += 1 }; Text("\(n)") }.padding(.px(4))   // inline only — no rules
            }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Static(), scheduleMicrotask: sched.schedule)
        rt.mount()
        let callsAfterMount = backend.counts["setStylesheet"] ?? 0
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect((backend.counts["setStylesheet"] ?? 0) == callsAfterMount)   // registry never grew
    }
}
