import Testing
@testable import SwiftWUI

private struct Card: Tag {
    var body: some Tag { Div(class: "card") { Text("hi") } }
}
private struct TwoRoots: Tag {
    var body: some Tag {
        Div { Text("a") }
        Span { Text("b") }
    }
}
private struct StatefulCard: Tag {
    @State var n = 0
    var body: some Tag { Div { Button("+") { n += 1 }; Text("\(n)") } }
}

@Suite struct StyledWrapperTests {
    @Test func componentGetsWrapperStyles() {
        let html = HTMLRenderer.render(Card().margin(.px(16)))
        #expect(html.contains(#"style="margin: 16px""#))
    }
    @Test func htmlTagStaysOnBagPathNoWrapper() {
        // overload check: modifier on a concrete HTML tag returns the tag itself
        // (accessing _attributes compiles ⇔ the HTMLTag overload won, no wrapper)
        let d = Div { Text("x") }.padding(.px(4))
        #expect(d._attributes.styles.count == 1)
    }
    @Test func consecutiveModifiersCollapse() {
        let styled = Card().padding(.px(2)).margin(.px(4))
        #expect(styled.declarations.count == 2)          // one wrapper, two declarations
    }
    @Test func outerWins() {
        // Card's root Div has no margin; give it one inline and override from outside
        struct Inner: Tag { var body: some Tag { Div { Text("x") }.margin(.px(1)) } }
        let html = HTMLRenderer.render(Inner().margin(.px(9)))
        // both appear; CSS last-wins → 9px is effective. Pin the order:
        #expect(html.contains("margin: 1px; margin: 9px"))
    }
    @Test func multiRootAppliesToEveryElementRoot() {
        let html = HTMLRenderer.render(TwoRoots().color(.hex("#111")))
        #expect(html.ranges(of: "color: #111").count == 2)
    }
    @Test func wrapperRulesAttachClasses() {
        let (html, css) = HTMLRenderer.renderWithStylesheet(
            Card().hover { $0.opacity(0.5) }
        )
        #expect(html.contains("swui-"))
        #expect(css.contains(":hover { opacity: 0.5 }"))
    }
    @Test func statePreservedAcrossReRenderWithWrapper() {
        struct Root: Tag {
            @State var tick = 0
            var body: some Tag {
                Div {
                    StatefulCard().padding(.px(4))
                    Button("t") { tick += 1 }
                    Text("tick \(tick)")
                }
            }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Root(), scheduleMicrotask: sched.schedule)
        rt.mount()
        let plus = findAll(backend.container, tag: "button").first { $0.children.first?.text == "+" }!
        rt.dispatch(plus.events["click"]!); sched.pump()
        #expect(backend.serializeHTML().contains("1"))
        let t = findAll(backend.container, tag: "button").first { $0.children.first?.text == "t" }!
        rt.dispatch(t.events["click"]!); sched.pump()
        // wrapper identity is stable → StatefulCard keeps n == 1 across parent re-render
        #expect(backend.serializeHTML().contains("tick 1"))
        let plusAfter = findAll(backend.container, tag: "button").first { $0.children.first?.text == "+" }!
        #expect(plusAfter.parent!.children.last?.text == "1")   // counter text survived
    }
}
