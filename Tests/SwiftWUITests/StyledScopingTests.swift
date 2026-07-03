import Testing
@testable import SwiftWUI

private struct SearchForm: Tag, Styled {
    @RulesBuilder var styles: [Rule] {
        Rule(class: "field") { s in
            s.padding(.px(8))
            s.hover { $0.borderColor(.hex("#00f")) }
        }
        Rule(id: "submit") { $0.fontWeight(.bold) }
        Rule(element: "input") { $0.outline(.none) }
    }
    var body: some Tag {
        Form {
            Input(type: .text).classes("field")
            Button("Go") {}.classes("field").id("submit")
            ChildPlain()
        }
    }
}
private struct ChildPlain: Tag {
    var body: some Tag { Div(class: "field") { Text("child") } }
}
// D12 fixtures: a Styled parent passes builder content into a child
// component ("slot"). The slotted content resolves in the CHILD's body
// pass, not the parent's — it must NOT carry the parent's scope marker.
private struct SlotChild<Content: Tag>: Tag {
    let content: Content
    var body: some Tag { Div(class: "slot-wrap") { content } }
}
private struct SlotParent: Tag, Styled {
    @RulesBuilder var styles: [Rule] {
        Rule(class: "own") { $0.padding(.px(4)) }
    }
    var body: some Tag {
        Div(class: "own") {
            SlotChild(content: Span(class: "slotted") { Text("x") })
        }
    }
}
private struct DynamicRules: Tag, Styled {
    @State var wide = false
    @RulesBuilder var styles: [Rule] {
        Rule(class: "row") { $0.gap(.px(4)) }
        if wide { Rule(class: "row") { $0.gap(.px(16)) } }
    }
    var body: some Tag {
        Div(class: "row") { Button("w") { wide.toggle() } }
    }
}

@Suite struct StyledScopingTests {
    private var marker: String { scopeMarker(forTypeName: String(reflecting: SearchForm.self)) }

    @Test func selectorsCompileWithMarker() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(SearchForm())
        #expect(css.contains(".field.\(marker) { padding: 8px }"))
        #expect(css.contains(".field.\(marker):hover { border-color: #00f }"))
        #expect(css.contains("#submit.\(marker) { font-weight: bold }"))
        #expect(css.contains("input.\(marker) { outline: none }"))
    }
    @Test func markerOnOwnElementsNotChildComponents() {
        let (html, _) = HTMLRenderer.renderWithStylesheet(SearchForm())
        // the form + its input + button carry the marker
        #expect(html.ranges(of: marker).count >= 3)
        // the child component's div does NOT (extract child div and check)
        let childStart = html.firstRange(of: "child")!
        let childTagStart = html[..<childStart.lowerBound].lastIndex(of: "<")!
        let childOpenTag = html[childTagStart..<childStart.lowerBound]
        #expect(!childOpenTag.contains(marker))
    }
    @Test func slotContentInChildComponentIsUnmarked() {
        let slotMarker = scopeMarker(forTypeName: String(reflecting: SlotParent.self))
        let (html, _) = HTMLRenderer.renderWithStylesheet(SlotParent())
        #expect(html.contains(#"class="own \#(slotMarker)""#))
        #expect(html.contains(#"class="slot-wrap""#))   // unmarked: child component's own root
        #expect(html.contains(#"class="slotted""#))     // unmarked: slot content resolves in child's pass
    }
    @Test func nInstancesOneRegistryEntry() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(Div { SearchForm(); SearchForm() })
        #expect(css.ranges(of: ".field.\(marker) { padding: 8px }").count == 1)
    }
    @Test func dynamicRulesRegisterOnStateChange() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: DynamicRules(), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(backend.stylesheetText?.contains("gap: 4px") == true)
        #expect(backend.stylesheetText?.contains("gap: 16px") != true)
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(backend.stylesheetText?.contains("gap: 16px") == true)   // grew during scoped pass
    }
    @Test func globalStylesUnscoped() {
        struct Root: Tag { var body: some Tag { Div { Text("x") } } }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Root(), scheduleMicrotask: sched.schedule,
                         globalStyles: [Rule(element: "body") { $0.margin(.zero) }])
        rt.mount()
        #expect(backend.stylesheetText == "body { margin: 0 }")
    }
    @Test func rulesBuilderSupportsEmptyAndConditionals() {
        @RulesBuilder func empty() -> [Rule] { }
        #expect(empty().isEmpty)
    }
}
