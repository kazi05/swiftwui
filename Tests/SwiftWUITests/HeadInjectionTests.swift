import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

@Suite struct HeadInjectionTests {
    private let payloads = [
        "</title><script>alert(1)</script>",
        "\"><script>alert(1)</script>",
        "</script><img src=x onerror=alert(1)>",
        "javascript:alert(1)",
    ]

    @Test func titleAndMetaAndCanonicalAreInert() {
        for p in payloads {
            let head = PageHead(title: p, meta: [.description(p)], links: [.canonical(p)])
            let doc = DocumentSerializer.render(.init(bodyHTML: "", head: head))
            #expect(!doc.contains("<script>alert(1)</script>"))
            // Substring check, not "onerror=alert(1)" alone: that fragment survives
            // escaping harmlessly as inert text (`onerror=alert(1)` has no chars
            // HTMLEscaping.text touches) once its surrounding `<`/`>` are entities —
            // it is never a live attribute. The unescaped tag IS the exploit surface.
            #expect(!doc.contains("<img src=x onerror=alert(1)>"))
        }
    }

    @Test func canonicalRejectsJavascriptScheme() {
        let link = LinkTag.canonical("javascript:alert(1)")
        #expect(link.attributes["href"] != "javascript:alert(1)")
    }

    @Test func structuredDataCannotBreakOut() {
        let head = PageHead(title: "t", meta: [], links: [],
                            structuredData: [#"{"x":"</script><script>alert(1)</script>"}"#])
        let doc = DocumentSerializer.render(.init(bodyHTML: "", head: head))
        #expect(!doc.contains("<script>alert(1)</script>"))
    }
}
