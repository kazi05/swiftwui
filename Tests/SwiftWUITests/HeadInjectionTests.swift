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
            // Positive: the value must not silently vanish — a channel that DROPPED
            // the payload instead of escaping it would also pass a purely negative
            // check, and that's a bug too. Negative: skip when escaping is a no-op
            // for this payload (e.g. "javascript:alert(1)" has no HTML metacharacters)
            // — there's nothing to distinguish there, and raw presence is expected.
            #expect(doc.contains(HTMLEscaping.text(p)))
            if p != HTMLEscaping.text(p) {
                #expect(!doc.contains(p))
            }
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
