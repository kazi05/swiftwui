import Testing
@testable import SwiftWUI

@Suite @MainActor struct CrossCheckTests {
    @Test func anchorSanitizesHref() {
        #expect(HTMLRenderer.render(A(href: "javascript:alert(1)") { Text("x") })
            == "<a href=\"#\">x</a>")
        #expect(HTMLRenderer.render(A(href: "https://ok.example") { Text("x") })
            == "<a href=\"https://ok.example\">x</a>")
    }
    @Test func imgSanitizesSrcAndIsVoid() {
        #expect(HTMLRenderer.render(Img(src: "data:text/html,evil", alt: "a"))
            == "<img alt=\"a\" src=\"#\">")
    }
    @Test func semanticTagsRender() {
        struct PageShape: Tag {
            var body: some Tag {
                Main {
                    Header { Nav { Ul { Li { "one" }; Li { "two" } } } }
                    Section { Article { H2("head"); Pre { Code { "let x = 1" } } } }
                    Footer { Strong { "end" } }
                }
            }
        }
        let html = HTMLRenderer.render(PageShape())
        for t in ["main", "header", "nav", "ul", "li", "section", "article", "h2", "pre", "code", "footer", "strong"] {
            #expect(html.contains("<\(t)>") || html.contains("<\(t) "), "missing <\(t)>")
        }
    }
    /// Cross-check property (spec §10.4): after ANY apply, the mock host tree
    /// serializes to exactly what HTMLRenderer produces for the same tags.
    @Test func mockSerializationMatchesHTMLRenderer() {
        struct Sample: Tag {
            let n: Int
            var body: some Tag {
                Div(class: "wrap") {
                    H1("n=\(n)")
                    ForEach(0..<n) { i in Li { "item \(i)" } }
                    if n % 2 == 0 { P { "even" } }
                    Br()
                    Table { Thead { Tr { Th(scope: "col") { Text("N") } } }
                            Tbody { Tr { Td { Text("1") } } } }
                    Details(open: true) { Summary { Text("more") }; P { Text("detail") } }
                    Video(src: "/v.mp4", controls: true) { Source(src: "/v.webm", type: "video/webm") }
                }
            }
        }
        let backend = MockBackend()
        let sched = TestScheduler2()
        var current = 1
        // Runtime over a mutable wrapper driven by @State:
        struct Host: Tag {
            @State var n = 1
            var body: some Tag {
                Sample(n: n)
                Button("bump") { n += 1 }
            }
        }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Host(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        for _ in 0..<4 {
            let button = findAllX(backend.container, tag: "button").last!
            runtime.dispatch(button.events["click"]!)
            sched.pump()
            current += 1
            let expected = HTMLRenderer.render(TupleTag(Sample(n: current), Button("bump", onClick: {})))
            #expect(backend.serializeHTML() == expected, "divergence at n=\(current)")
        }
    }
}

@MainActor final class TestScheduler2 {
    private var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func pump() { while !queue.isEmpty { queue.removeFirst()() } }
}
@MainActor func findAllX(_ node: MockNode, tag: String) -> [MockNode] {
    var out: [MockNode] = []
    if node.tag == tag { out.append(node) }
    for c in node.children { out += findAllX(c, tag: tag) }
    return out
}
