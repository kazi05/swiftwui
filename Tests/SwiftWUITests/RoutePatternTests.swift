import Testing
@testable import SwiftWUI

@MainActor @Suite struct RoutePatternTests {
    @Test func staticAndRoot() {
        #expect(RoutePattern("/").match("/") == [:])
        #expect(RoutePattern("/about").match("/about") == [:])
        #expect(RoutePattern("/about").match("/abou") == nil)
        #expect(RoutePattern("/about").match("/about/x") == nil)
        #expect(RoutePattern("/about").match("/About") == nil)          // case-sensitive
        #expect(RoutePattern("/about").match("/about/") == [:])          // trailing slash
        #expect(RoutePattern("/a/b").match("/a//b") == [:])              // empty segments dropped
    }
    @Test func params() {
        #expect(RoutePattern("/todo/:id").match("/todo/42") == ["id": "42"])
        #expect(RoutePattern("/todo/:id").match("/todo") == nil)
        #expect(RoutePattern("/todo/:id").match("/todo/42/x") == nil)
        #expect(RoutePattern("/u/:a/p/:b").match("/u/1/p/2") == ["a": "1", "b": "2"])
        #expect(RoutePattern("/f/:name").match("/f/caf%C3%A9") == ["name": "café"])
        #expect(RoutePattern("/f/:name").match("/f/bad%GG") == ["name": "bad%GG"])  // invalid escape kept raw
    }
    @Test func catchAll() {
        #expect(RoutePattern("/docs/*").match("/docs/a/b") == ["*": "a/b"])
        #expect(RoutePattern("/docs/*").match("/docs") == ["*": ""])
        #expect(RoutePattern("/*").match("/anything/at/all") == ["*": "anything/at/all"])
    }
    @Test func urlSplit() {
        let (p, q, s) = RouteURL.split("/a/b?x=1&y=two%20words&flag")
        #expect(p == "/a/b")
        #expect(q == ["x": "1", "y": "two words", "flag": ""])
        #expect(s == "x=1&y=two%20words&flag")
        #expect(RouteURL.split("/plain").path == "/plain")
        #expect(RouteURL.split("/a?x=1#frag").query == ["x": "1"])       // fragment dropped
        #expect(RouteURL.parseQuery("a=b=c") == ["a": "b=c"])            // first '=' only
        #expect(RouteURL.normalizePath("x/") == "/x")
        #expect(RouteURL.normalizePath("/") == "/")
    }
    @Test func percentDecode() {
        #expect(RouteURL.percentDecode("no-escapes") == "no-escapes")
        #expect(RouteURL.percentDecode("%2Fslash") == "/slash")
        #expect(RouteURL.percentDecode("%E2%9C%93") == "✓")
        #expect(RouteURL.percentDecode("trunc%2") == "trunc%2")          // invalid: whole input unchanged
    }
    @Test func normalizePathStripsManyTrailingSlashes() {
        #expect(RouteURL.normalizePath("/a" + String(repeating: "/", count: 1000)) == "/a")
        #expect(RouteURL.normalizePath(String(repeating: "/", count: 1000)) == "/")
    }
    @Test func isExternalClassifiesDestinations() {
        #expect(RouteURL.isExternal("https://x.dev"))
        #expect(RouteURL.isExternal("mailto:a@b.c"))
        #expect(RouteURL.isExternal("//cdn.x.dev/lib.js"))
        #expect(!RouteURL.isExternal("/docs/intro"))
        #expect(!RouteURL.isExternal("/search?q=a:b"))     // ':' after '?' is not a scheme
        #expect(!RouteURL.isExternal("#section"))
    }
    #if !DEBUG
    @Test func catchAllMidPatternDegradesToPrefixMatch() {   // release-only: debug asserts in init
        let p = RoutePattern("/files/*/edit")
        #expect(p.match("/files/a/b") == ["*": "a/b"])
    }
    #endif
}
