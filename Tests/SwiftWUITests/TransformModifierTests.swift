import Testing
@testable import SwiftWUI

@Suite struct TransformModifierTests {
    // MARK: - StyleDeclaration factories render exactly

    @Test func translateRendersExactly() {
        let d = StyleDeclaration.translate(x: .px(10), y: .px(20))
        #expect(d.property == "translate")
        #expect(d.value == "10px 20px")
    }

    @Test func scaleRendersExactly() {
        let d = StyleDeclaration.scale(1.2)
        #expect(d.property == "scale")
        #expect(d.value == "1.2")
    }

    @Test func rotateRendersExactly() {
        let d = StyleDeclaration.rotate(degrees: 45)
        #expect(d.property == "rotate")
        #expect(d.value == "45deg")
    }

    @Test func transformOriginRendersOnlyForNonCenterAnchor() {
        let center = StyleDeclaration.transformOrigin(.center)
        #expect(center.value == "50% 50%")
        let topLeading = StyleDeclaration.transformOrigin(.topLeading)
        #expect(topLeading.value == "0% 0%")
        let bottomTrailing = StyleDeclaration.transformOrigin(.bottomTrailing)
        #expect(bottomTrailing.value == "100% 100%")
    }

    // MARK: - Tag modifiers render via HTMLRenderer

    @Test func offsetRendersTranslate() {
        let html = HTMLRenderer.render(Div().offset(x: 10, y: 20))
        #expect(html.contains(#"translate: 10px 20px"#))
    }

    @Test func scaleEffectDefaultAnchorOmitsTransformOrigin() {
        let html = HTMLRenderer.render(Div().scaleEffect(1.2))
        #expect(html.contains("scale: 1.2"))
        #expect(!html.contains("transform-origin"))
    }

    @Test func scaleEffectNonCenterAnchorEmitsTransformOrigin() {
        let html = HTMLRenderer.render(Div().scaleEffect(1.2, anchor: .topLeading))
        #expect(html.contains("scale: 1.2"))
        #expect(html.contains("transform-origin: 0% 0%"))
    }

    @Test func rotationEffectNonCenterAnchorEmitsTransformOrigin() {
        let html = HTMLRenderer.render(Div().rotationEffect(45, anchor: .bottom))
        #expect(html.contains("rotate: 45deg"))
        #expect(html.contains("transform-origin: 50% 100%"))
    }

    // MARK: - Rename compiles both ways: `.cssTransition(String)` + `.transition(AnyTransition)`

    @Test func cssTransitionAndTransitionCoexist() {
        let html = HTMLRenderer.render(Div().cssTransition("opacity 0.2s"))
        #expect(html.contains("transition: opacity 0.2s"))

        struct Wrap: Tag {
            @State var show = true
            var body: some Tag {
                if show { Div(class: "gone").transition(.opacity) }
            }
        }
        _ = Wrap()   // compiles: `.transition(.opacity)` (AnyTransition) still resolves
    }

    // MARK: - Independent channels (anim spec §6.7)

    private struct TwoTransformBlock: Tag {
        @State var x: Double = 0
        @State var scale: Double = 1
        var body: some Tag {
            Div(class: "xform")
                .offset(x: x)
                .scaleEffect(scale)
            Button("+") { withAnimation(.linear(duration: 1)) { x = 100; scale = 2 } }
        }
    }

    @Test func offsetAndScaleEffectAreTwoIndependentStyleEntries() {
        let html = HTMLRenderer.render(TwoTransformBlock())
        #expect(html.contains("translate: 0px 0px"))
        #expect(html.contains("scale: 1"))
    }

    @Test func offsetAndScaleEffectAnimateOnSeparateChannels() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: TwoTransformBlock(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.animations.count == 2)   // one animate call per property — never merged
        let properties = Set(backend.animations.map { $0.request.property })
        #expect(properties == ["translate", "scale"])
    }
}
