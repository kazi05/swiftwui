import Testing
@testable import SwiftWUICore

@Suite("WebObserver")
struct WebObserverTests {
    @Test("WebObserver intersection is equatable")
    func intersectionEquatable() {
        let id1 = EventListenerID("test-1")
        let id2 = EventListenerID("test-1")
        let obs1 = WebObserver.intersection(threshold: 0.5, callbackID: id1)
        let obs2 = WebObserver.intersection(threshold: 0.5, callbackID: id2)
        #expect(obs1 == obs2)
    }

    @Test("WebObserver resize stores callback")
    func resizeStoresCallback() {
        let id = EventListenerID("resize-cb")
        let obs = WebObserver.resize(callbackID: id)
        if case .resize(let cbID) = obs {
            #expect(cbID == id)
        } else {
            Issue.record("Expected resize observer")
        }
    }

    @Test("MutationOptions defaults")
    func mutationOptionsDefaults() {
        let opts = MutationOptions()
        #expect(opts.childList == false)
        #expect(opts.attributes == false)
        #expect(opts.subtree == false)
    }

    @Test("LifecycleEvent cases")
    func lifecycleEventCases() {
        #expect(LifecycleEvent.mount != LifecycleEvent.unmount)
    }
}
