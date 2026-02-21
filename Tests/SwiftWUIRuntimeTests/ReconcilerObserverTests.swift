import Testing
@testable import SwiftWUICore
@testable import SwiftWUIRuntime

@Suite("Reconciler Observer Diffing")
struct ReconcilerObserverTests {
    let reconciler = Reconciler()

    @Test("Adding observers produces patch")
    func addObservers() {
        let old = TagNode.element(.init(tagName: "div"))
        let obs = WebObserver.resize(callbackID: EventListenerID("cb"))
        let new = TagNode.element(.init(tagName: "div", observers: [obs]))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch != nil)
    }

    @Test("Removing observers produces patch")
    func removeObservers() {
        let obs = WebObserver.resize(callbackID: EventListenerID("cb"))
        let old = TagNode.element(.init(tagName: "div", observers: [obs]))
        let new = TagNode.element(.init(tagName: "div"))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch != nil)
    }

    @Test("Unchanged observers produce no patch")
    func unchangedObservers() {
        let obs = WebObserver.resize(callbackID: EventListenerID("cb"))
        let old = TagNode.element(.init(tagName: "div", observers: [obs]))
        let new = TagNode.element(.init(tagName: "div", observers: [obs]))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch == nil)
    }

    @Test("Changing observer type produces patch")
    func changeObserverType() {
        let oldObs = WebObserver.resize(callbackID: EventListenerID("cb1"))
        let newObs = WebObserver.intersection(threshold: 0.5, callbackID: EventListenerID("cb2"))
        let old = TagNode.element(.init(tagName: "div", observers: [oldObs]))
        let new = TagNode.element(.init(tagName: "div", observers: [newObs]))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch != nil)
    }

    @Test("Changing observer callback ID produces patch")
    func changeObserverCallbackID() {
        let oldObs = WebObserver.resize(callbackID: EventListenerID("cb1"))
        let newObs = WebObserver.resize(callbackID: EventListenerID("cb2"))
        let old = TagNode.element(.init(tagName: "div", observers: [oldObs]))
        let new = TagNode.element(.init(tagName: "div", observers: [newObs]))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch != nil)
    }

    @Test("Changed swiftwui-id forces element replacement")
    func idChangeForceReplacement() {
        let old = TagNode.element(.init(tagName: "div", attributes: ["data-swiftwui-id": "1"]))
        let new = TagNode.element(.init(tagName: "div", attributes: ["data-swiftwui-id": "2"]))
        let patch = reconciler.diff(old: old, new: new)
        if case .replaceNode = patch {
            // Expected
        } else {
            Issue.record("Expected replaceNode patch when id changes")
        }
    }

    @Test("Lifecycle observers produce patch when added")
    func addLifecycleObservers() {
        let old = TagNode.element(.init(tagName: "div"))
        let mountObs = WebObserver.lifecycle(event: .mount, callbackID: EventListenerID("mount"))
        let unmountObs = WebObserver.lifecycle(event: .unmount, callbackID: EventListenerID("unmount"))
        let new = TagNode.element(.init(tagName: "div", observers: [mountObs, unmountObs]))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch != nil)
    }
}
