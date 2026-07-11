import Testing
@testable import SwiftWUI

@MainActor @Suite struct PageTests {
    @Test func metaFactories() {
        #expect(MetaTag.charset("utf-8").attributes == ["charset": "utf-8"])
        #expect(MetaTag.named("robots", content: "noindex").attributes
                == ["name": "robots", "content": "noindex"])
        #expect(MetaTag.property("og:title", content: "T").attributes
                == ["property": "og:title", "content": "T"])
        #expect(MetaTag.viewport("width=device-width").attributes
                == ["name": "viewport", "content": "width=device-width"])
        #expect(MetaTag.description("d").attributes
                == ["name": "description", "content": "d"])
    }
    @Test func pageMetaDefaultsEmpty() {
        struct P: Page { var title: String { "t" }
                         var body: some Tag { Text("x") } }
        #expect(P().meta.isEmpty)
    }
    @Test func mockBackendRecordsRoutingCalls() {
        let b = MockBackend()
        b.pushState(path: "/a"); b.replaceState(path: "/b"); b.historyBack()
        b.setTitle("T"); b.setMetaTags([.charset("utf-8")])
        b.setLinks([.icon("/favicon.svg")])
        #expect(b.historyStack == ["/a"])
        #expect(b.replacedStates == ["/b"])
        #expect(b.backCount == 1)
        #expect(b.title == "T")
        #expect(b.metaTags == [.charset("utf-8")])
        #expect(b.links == [.icon("/favicon.svg")])
    }
    @Test func linkTagStatics() {
        #expect(LinkTag.icon("/favicon.svg", type: "image/svg+xml").attributes
            == ["rel": "icon", "href": "/favicon.svg", "type": "image/svg+xml"])
        #expect(LinkTag.stylesheet("/a.css").attributes == ["rel": "stylesheet", "href": "/a.css"])
        #expect(LinkTag.preload("/f.woff2", as: .font).attributes
            == ["rel": "preload", "href": "/f.woff2", "as": "font", "crossorigin": "anonymous"])
        #expect(LinkTag.preload("/h.jpg", as: .image).attributes["crossorigin"] == nil)
        #expect(LinkTag.canonical("https://x.y/p").attributes == ["rel": "canonical", "href": "https://x.y/p"])
    }

    @Test func linkTagSanitizesHref() {
        #expect(LinkTag.icon("javascript:alert(1)").attributes["href"] == "#")
        #expect(LinkTag(attributes: ["rel": "icon", "href": "data:text/html,x"]).attributes["href"] == "#")
    }

    @Test func pageDefaultLinksEmpty() {
        struct P: Page { var title: String { "t" }; var body: some Tag { Div() } }
        #expect(P().links.isEmpty)
    }
}
