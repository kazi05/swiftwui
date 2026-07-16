import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import SwiftWUI

private struct TaskCard: DragPayload, Equatable {
    let title: String
    let id: Int
}

@Suite struct DragPayloadTests {
    @Test func defaultContentTypeFromTypeName() {
        #expect(TaskCard.dragContentType == "application/x-swiftwui.taskcard")
    }
    @Test func jsonRoundTripSortedKeys() {
        let card = TaskCard(title: "hi", id: 7)
        let body = card._encodeDragBody()
        #expect(body == #"{"id":7,"title":"hi"}"#)
        #expect(TaskCard._decodeDragBody(body!) == card)
        #expect(TaskCard._decodeDragBody("not json") == nil)
    }
    @Test func stringIsPlainText() {
        #expect(String.dragContentType == "text/plain")
        #expect("привет"._encodeDragBody() == "привет")
        #expect(String._decodeDragBody("x") == "x")
    }
    @Test func urlUriList() {
        let url = URL(string: "https://example.com/a?b=1")!
        #expect(URL.dragContentType == "text/uri-list")
        #expect(url._encodeDragBody() == "https://example.com/a?b=1")
        #expect(URL._decodeDragBody("# comment\r\nhttps://example.com/a?b=1\r\n") == url)
        #expect(URL._decodeDragBody("# only comments") == nil)
    }
}
