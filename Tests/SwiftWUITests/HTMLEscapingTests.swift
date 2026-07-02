import Testing
@testable import SwiftWUI

@Suite("HTML Escaping")
struct HTMLEscapingTests {

    // MARK: text

    @Test("text escapes the five HTML-significant characters")
    func textEscapesAll() {
        #expect(HTMLEscaping.text("<a href=\"x\">&'") == "&lt;a href=&quot;x&quot;&gt;&amp;&#39;")
    }

    @Test("text leaves ordinary and unicode content untouched")
    func textPassthrough() {
        #expect(HTMLEscaping.text("Привет 🎉 plain") == "Привет 🎉 plain")
    }

    @Test("style attribute value cannot break out of the attribute")
    func textStyleBreakout() {
        // A double quote in a style value would otherwise close style="…".
        let escaped = HTMLEscaping.text("red\" onmouseover=\"alert(1)")
        #expect(!escaped.contains("\""))
    }

    // MARK: scriptJSON

    @Test("scriptJSON neutralises a </script> breakout")
    func scriptJSONBreakout() {
        let out = HTMLEscaping.scriptJSON("{\"x\":\"</script><script>alert(1)</script>\"}")
        #expect(!out.contains("<"))
        #expect(out.contains("\\u003c"))
    }

    // MARK: rawTextElement

    @Test("rawTextElement neutralises </style> and </script>")
    func rawTextClose() {
        #expect(HTMLEscaping.rawTextElement("a{}</style><script>") == "a{}<\\/style><script>")
        #expect(HTMLEscaping.rawTextElement("x</script>y") == "x<\\/script>y")
    }

    @Test("rawTextElement leaves benign content intact")
    func rawTextBenign() {
        #expect(HTMLEscaping.rawTextElement(".a { color: red }") == ".a { color: red }")
    }

    // MARK: cssToken

    @Test("cssToken strips rule- and element-breaking characters")
    func cssTokenStrips() {
        #expect(HTMLEscaping.cssToken("red} body{display:none") == "red bodydisplay:none")
        #expect(HTMLEscaping.cssToken("</style>") == "/style")
    }

    // MARK: sanitizeURL

    @Test("sanitizeURL drops javascript/data/vbscript, including obfuscated")
    func urlDangerous() {
        #expect(HTMLEscaping.sanitizeURL("javascript:alert(1)") == "#")
        #expect(HTMLEscaping.sanitizeURL("JavaScript:alert(1)") == "#")
        #expect(HTMLEscaping.sanitizeURL("  javascript:alert(1)") == "#")
        #expect(HTMLEscaping.sanitizeURL("java\tscript:alert(1)") == "#")
        #expect(HTMLEscaping.sanitizeURL("data:text/html,<script>") == "#")
        #expect(HTMLEscaping.sanitizeURL("vbscript:msgbox") == "#")
    }

    @Test("sanitizeURL preserves safe absolute and relative URLs")
    func urlSafe() {
        #expect(HTMLEscaping.sanitizeURL("https://example.com/x") == "https://example.com/x")
        #expect(HTMLEscaping.sanitizeURL("mailto:a@b.com") == "mailto:a@b.com")
        #expect(HTMLEscaping.sanitizeURL("tel:+1234") == "tel:+1234")
        #expect(HTMLEscaping.sanitizeURL("/about") == "/about")
        #expect(HTMLEscaping.sanitizeURL("about/team") == "about/team")
        #expect(HTMLEscaping.sanitizeURL("#section") == "#section")
        #expect(HTMLEscaping.sanitizeURL("?q=1") == "?q=1")
        // ":" inside a path segment is not a scheme.
        #expect(HTMLEscaping.sanitizeURL("/a:b/c") == "/a:b/c")
    }
}
