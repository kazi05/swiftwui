import Testing
@testable import SwiftWUICore
@testable import SwiftWUIRuntime

@Suite("Reconciler Responsive Styles")
struct ReconcilerResponsiveTests {

    let reconciler = Reconciler()

    @Test("Adding responsive styles produces class update patch")
    func addResponsiveStyles() {
        let old = TagNode.element(.init(tagName: "div"))
        let new = TagNode.element(.init(
            tagName: "div",
            responsiveStyles: ["@media (max-width: 767px)": ["font-size": "16px"]]
        ))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch != nil)
    }

    @Test("Removing responsive styles produces class update patch")
    func removeResponsiveStyles() {
        let old = TagNode.element(.init(
            tagName: "div",
            responsiveStyles: ["@media (max-width: 767px)": ["font-size": "16px"]]
        ))
        let new = TagNode.element(.init(tagName: "div"))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch != nil)
    }

    @Test("Unchanged responsive styles produce no patch")
    func unchangedResponsiveStyles() {
        let styles: [String: [String: String]] = ["@media (max-width: 767px)": ["font-size": "16px"]]
        let old = TagNode.element(.init(tagName: "div", responsiveStyles: styles))
        let new = TagNode.element(.init(tagName: "div", responsiveStyles: styles))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch == nil)
    }

    @Test("Changing responsive style values produces class update")
    func changingResponsiveStyles() {
        let old = TagNode.element(.init(
            tagName: "div",
            responsiveStyles: ["@media (max-width: 767px)": ["font-size": "16px"]]
        ))
        let new = TagNode.element(.init(
            tagName: "div",
            responsiveStyles: ["@media (max-width: 767px)": ["font-size": "24px"]]
        ))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch != nil)
    }
}
