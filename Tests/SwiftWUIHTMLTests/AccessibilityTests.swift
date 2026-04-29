import Testing
@testable import SwiftWUICore
@testable import SwiftWUIHTML

@Suite("Accessibility modifiers")
struct AccessibilityTests {
    @Test("accessibilityLabel sets aria-label")
    func labelSetsAttribute() {
        let div = Div {}.accessibilityLabel("Close dialog")
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["aria-label"] == "Close dialog")
    }

    @Test("accessibilityHidden(true) sets aria-hidden=\"true\"")
    func hiddenTrue() {
        let div = Div {}.accessibilityHidden(true)
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["aria-hidden"] == "true")
    }

    @Test("accessibilityHidden() defaults to true")
    func hiddenDefault() {
        let div = Div {}.accessibilityHidden()
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["aria-hidden"] == "true")
    }

    @Test("accessibilityRole(.button) sets role=\"button\"")
    func roleButton() {
        let div = Div {}.accessibilityRole(.button)
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["role"] == "button")
    }

    @Test("accessibilityRole(.nav) emits role=\"navigation\" (the rawValue is mapped)")
    func roleNavigationRawValue() {
        let div = Div {}.accessibilityRole(.nav)
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["role"] == "navigation")
    }

    @Test("accessibilityLive(.polite) sets aria-live")
    func livePolite() {
        let div = Div {}.accessibilityLive(.polite)
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["aria-live"] == "polite")
    }

    @Test("aria(invalid:) and aria(expanded:) set the corresponding attributes")
    func ariaBooleans() {
        let div = Div {}.aria(invalid: true).aria(expanded: false)
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["aria-invalid"] == "true")
        #expect(el.attributes["aria-expanded"] == "false")
    }

    @Test("aria(controls:) and aria(describedby:) carry their string IDs")
    func ariaIdLinks() {
        let div = Div {}
            .aria(controls: "menu-1")
            .aria(describedby: "hint-1")
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["aria-controls"] == "menu-1")
        #expect(el.attributes["aria-describedby"] == "hint-1")
    }

    @Test("Img requires alt at the type level")
    func imgRequiresAlt() {
        let img = Img(src: "/hero.jpg", alt: "Hero shot")
        let nodes = resolveTagBody(img)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["alt"] == "Hero shot")
        #expect(el.attributes["src"] == "/hero.jpg")
    }
}
