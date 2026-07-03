import Testing
@testable import SwiftWUI

@Suite struct PseudoMediaTests {
    @Test func hoverGeneratesClassAndRule() {
        let (html, css) = HTMLRenderer.renderWithStylesheet(
            Button("+") {}.hover { $0.background(.hex("#eee")) }
        )
        // the button carries exactly the generated class, and the rule targets it
        let clsStart = html.firstRange(of: "swui-")!
        let cls = String(html[clsStart.lowerBound...].prefix(while: { $0 != "\"" && $0 != " " }))
        #expect(css == ".\(cls):hover { background: #eee }")
    }
    @Test func sameRuleTwoElementsOneEntry() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div {
                Button("a") {}.hover { $0.opacity(0.5) }
                Button("b") {}.hover { $0.opacity(0.5) }
            }
        )
        #expect(css.split(separator: "\n").count == 1)
    }
    @Test func mediaRuleWraps() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.media(.maxWidth(.px(600))) { $0.display(.none) }
        )
        #expect(css.hasPrefix("@media (max-width: 600px) { .swui-"))
        #expect(css.contains("display: none"))
    }
    @Test func emptyPseudoRuleRegistersNothing() {
        // MINOR 8: `.hover { _ in }` collects zero declarations — registerAnonymous
        // must not register a useless `.swui-x { }` stylesheet entry for it.
        let (_, css) = HTMLRenderer.renderWithStylesheet(Button("+") {}.hover { _ in })
        #expect(css.isEmpty)
    }
    @Test func emptyRuleBuilderPseudoBlockRegistersNothing() {
        // Same guard, other collector: a `Rule`'s `s.hover { _ in }` sub-block
        // (StyleProxy._pseudo) must not append an empty block either.
        struct EmptyHoverRule: Tag, Styled {
            @RulesBuilder var styles: [Rule] {
                Rule(class: "field") { s in s.hover { _ in } }
            }
            var body: some Tag { Div(class: "field") { Text("x") } }
        }
        let (_, css) = HTMLRenderer.renderWithStylesheet(EmptyHoverRule())
        #expect(css.isEmpty)
    }
    @Test func mediaQueryConditions() {
        #expect(MediaQuery.minWidth(.rem(40)).condition == "(min-width: 40rem)")
        #expect(MediaQuery.prefersColorScheme(.dark).condition == "(prefers-color-scheme: dark)")
    }
    @Test func runtimeSetsStylesheetOnMount() {
        struct Root: Tag {
            var body: some Tag { Div { Text("x") }.hover { $0.color(.white) } }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Root(), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(backend.stylesheetText?.contains(":hover { color: #fff }") == true)
        #expect(backend.counts["setStylesheet"] == 1)
    }
}
