import Testing
@testable import SwiftWUI

@MainActor @Suite struct PageTests {
    @Test func metaFactories() {
        #expect(MetaTag.charset("utf-8").attributes == ["charset": "utf-8"])
        #expect(MetaTag.named("robots", content: "noindex").attributes
                == ["name": "robots", "content": "noindex"])
        #expect(MetaTag.property("og:title", content: "T").attributes
                == ["property": "og:title", "content": "T"])
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
        #expect(b.historyStack == ["/a"])
        #expect(b.replacedStates == ["/b"])
        #expect(b.backCount == 1)
        #expect(b.title == "T")
        #expect(b.metaTags == [.charset("utf-8")])
    }
}
