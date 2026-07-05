import Testing
@testable import SwiftWUI

/// Parses OUR compact serializer output back into MockNodes. Test helper only.
@MainActor
func parseHTMLSubset(_ html: String, into backend: MockBackend) {
    var stack: [MockNode] = [backend.container]
    var i = html.startIndex

    func decodeEntities(_ s: Substring) -> String {
        var out = ""
        var j = s.startIndex
        while j < s.endIndex {
            if s[j] == "&" {
                let rest = s[j...]
                if rest.hasPrefix("&amp;") { out += "&"; j = s.index(j, offsetBy: 5); continue }
                if rest.hasPrefix("&lt;")  { out += "<"; j = s.index(j, offsetBy: 4); continue }
                if rest.hasPrefix("&gt;")  { out += ">"; j = s.index(j, offsetBy: 4); continue }
                if rest.hasPrefix("&quot;") { out += "\""; j = s.index(j, offsetBy: 6); continue }
                if rest.hasPrefix("&#39;") { out += "'"; j = s.index(j, offsetBy: 5); continue }
            }
            out.append(s[j]); j = s.index(after: j)
        }
        return out
    }
    func appendText(_ t: String) {
        guard !t.isEmpty else { return }
        // Coalesce like a browser: adjacent text merges.
        if let last = stack.last!.children.last, last.text != nil {
            last.text! += t
        } else {
            let n = MockNode(); n.text = t; n.parent = stack.last
            stack.last!.children.append(n)
        }
    }

    while i < html.endIndex {
        if html[i] == "<" {
            guard let close = html[i...].firstIndex(of: ">") else { break }
            let inner = html[html.index(after: i)..<close]
            if inner.hasPrefix("/") {
                stack.removeLast()
            } else {
                let n = MockNode()
                var rest = inner
                let nameEnd = rest.firstIndex(where: { $0 == " " }) ?? rest.endIndex
                n.tag = String(rest[..<nameEnd])
                rest = rest[nameEnd...].drop(while: { $0 == " " })
                while !rest.isEmpty {
                    let attrNameEnd = rest.firstIndex(where: { $0 == "=" || $0 == " " }) ?? rest.endIndex
                    let name = String(rest[..<attrNameEnd])
                    if attrNameEnd < rest.endIndex, rest[attrNameEnd] == "=" {
                        let vStart = rest.index(attrNameEnd, offsetBy: 2)   // skip ="
                        let vEnd = rest[vStart...].firstIndex(of: "\"")!
                        n.attrs[name] = decodeEntities(rest[vStart..<vEnd])
                        rest = rest[rest.index(after: vEnd)...].drop(while: { $0 == " " })
                    } else {
                        if !name.isEmpty { n.attrs[name] = "" }             // boolean attr
                        rest = rest[attrNameEnd...].drop(while: { $0 == " " })
                    }
                }
                n.parent = stack.last
                stack.last!.children.append(n)
                if !HTMLRenderer.voidElements.contains(n.tag!) { stack.append(n) }
            }
            i = html.index(after: close)
        } else {
            let next = html[i...].firstIndex(of: "<") ?? html.endIndex
            appendText(decodeEntities(html[i..<next]))
            i = next
        }
    }
}

private struct RoundTripApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/") { RTPage() }
        }
    }
}
private struct RTPage: Tag, Page {
    @State var n = 0
    @State var note = "seed & <breakout>"
    var title: String { "RT" }
    var body: some Tag {
        Div(class: "rt") {
            H1("n = \(n)")
            P { Text(note) }
            Button("+") { n += 1 }
            Ul { ForEach([1, 2, 3], id: \.self) { i in Li { Text("item \(i)") } } }
            Details(open: true) { Summary { Text("more") }; P { Text("hidden") } }
            Abbr(title: "A & \"quoted\"") { Text("AB") }
            Div { Wbr() }
        }
    }
}

@Suite @MainActor struct HydrationRoundTripTests {
    /// SSG body → parse → adopt: zero creates, listeners live, then click works.
    @Test func roundTripAdoptsWithZeroCreates() {
        // 1. Prerender via the same path StaticSite uses.
        let ssgBackend = MockBackend()
        let ssg = Runtime(backend: ssgBackend, container: ssgBackend.container,
                          root: RoundTripApp().body, initialPath: "/",
                          scheduleMicrotask: { $0() })
        ssg.mount()
        let bodyHTML = ssgBackend.serializeHTML()

        // 2. Parse into a fresh Mock DOM (the "browser").
        let dom = MockBackend()
        parseHTMLSubset(bodyHTML, into: dom)

        // 3. Hydrate.
        let adopting = AdoptingBackend(base: dom, container: dom.container)
        let sched = TestScheduler()
        let client = Runtime(backend: adopting, container: dom.container,
                             root: RoundTripApp().body, initialPath: "/",
                             scheduleMicrotask: sched.schedule)
        client.mount()
        #expect(adopting.finishAdoption())
        #expect(dom.counts["createElement"] == nil)
        #expect(dom.counts["createTextNode"] == nil)
        #expect(dom.counts["remove"] == nil)

        // 4. The adopted tree is live.
        clickFirst(dom, client, tag: "button", sched: sched)
        #expect(dom.serializeHTML().contains("n = 1"))
    }

    /// Trailing foreign nodes (browser-extension injections, legacy
    /// post-</body> whitespace) after the app's own nodes must NOT cold-fallback —
    /// only mid-stream divergence is a real mismatch.
    @Test func trailingForeignNodesAreToleratedNotAMismatch() {
        let ssgBackend = MockBackend()
        let ssg = Runtime(backend: ssgBackend, container: ssgBackend.container,
                          root: RoundTripApp().body, initialPath: "/",
                          scheduleMicrotask: { $0() })
        ssg.mount()
        let bodyHTML = ssgBackend.serializeHTML()

        let dom = MockBackend()
        parseHTMLSubset(bodyHTML, into: dom)

        // Simulate: post-</body> whitespace reparented into body, plus a
        // browser-extension element (e.g. DeepL's <deepl-input-controller>).
        let whitespace = MockNode(); whitespace.text = "\n\n"
        whitespace.parent = dom.container
        dom.container.children.append(whitespace)
        let extNode = MockNode(); extNode.tag = "deepl-input-controller"
        extNode.parent = dom.container
        dom.container.children.append(extNode)

        let adopting = AdoptingBackend(base: dom, container: dom.container)
        let sched = TestScheduler()
        let client = Runtime(backend: adopting, container: dom.container,
                             root: RoundTripApp().body, initialPath: "/",
                             scheduleMicrotask: sched.schedule)
        client.mount()
        #expect(adopting.finishAdoption())          // tolerated, no cold fallback
        #expect(dom.counts["createElement"] == nil)
        #expect(dom.counts["createTextNode"] == nil)
        #expect(dom.counts["remove"] == nil)

        // Foreign nodes left exactly where they were.
        #expect(dom.container.children.last === extNode)
        #expect(dom.container.children[dom.container.children.count - 2] === whitespace)
    }

    /// Every single-node mutation of the prerendered DOM must fail adoption —
    /// and the fallback cold mount must reproduce the canonical HTML.
    @Test func mutationSweepAlwaysFallsBackCleanly() {
        let ssgBackend = MockBackend()
        let ssg = Runtime(backend: ssgBackend, container: ssgBackend.container,
                          root: RoundTripApp().body, initialPath: "/",
                          scheduleMicrotask: { $0() })
        ssg.mount()
        let canonical = ssgBackend.serializeHTML()

        for mutation in 0..<3 {
            let dom = MockBackend()
            parseHTMLSubset(canonical, into: dom)
            switch mutation {
            case 0: findFirst(dom.container, tag: "h1")!.tag = "h3"          // tag swap
            case 1:                                                          // extra node
                // Inserted at the FRONT (not appended trailing) — a genuine
                // mid-stream mismatch, distinct from tolerated trailing leftovers.
                let junk = MockNode(); junk.tag = "p"
                let div = findFirst(dom.container, tag: "div")!
                junk.parent = div; div.children.insert(junk, at: 0)
            default:                                                         // missing node
                let ul = findFirst(dom.container, tag: "ul")!
                ul.children.removeLast()
            }
            let adopting = AdoptingBackend(base: dom, container: dom.container)
            adopting._assertOnMismatch = false
            let sched = TestScheduler()
            let client = Runtime(backend: adopting, container: dom.container,
                                 root: RoundTripApp().body, initialPath: "/",
                                 scheduleMicrotask: sched.schedule)
            client.mount()
            #expect(!adopting.finishAdoption(), "mutation \(mutation) must fail adoption")

            // Fallback: clear + cold mount on the SAME dom backend.
            for c in dom.container.children { dom.remove(c, from: dom.container) }
            let cold = Runtime(backend: dom, container: dom.container,
                               root: RoundTripApp().body, initialPath: "/",
                               scheduleMicrotask: sched.schedule)
            cold.mount()
            #expect(dom.serializeHTML() == canonical, "mutation \(mutation) fallback diverged")
        }
    }
}
