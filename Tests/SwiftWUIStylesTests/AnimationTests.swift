import Testing
@testable import SwiftWUIStyles

@Suite("Animation")
struct AnimationTests {
    @Test("Default animation")
    func defaultAnimation() {
        let anim = Animation.default
        #expect(anim.duration == 0.3)
        #expect(anim.timingFunction == .easeInOut)
        #expect(anim.delay == 0)
    }

    @Test("EaseInOut animation")
    func easeInOutAnimation() {
        let anim = Animation.easeInOut(duration: 0.5)
        #expect(anim.duration == 0.5)
        #expect(anim.timingFunction == .easeInOut)
    }

    @Test("Linear animation")
    func linearAnimation() {
        let anim = Animation.linear(duration: 1.0)
        #expect(anim.timingFunction == .linear)
    }

    @Test("Spring animation")
    func springAnimation() {
        let anim = Animation.spring
        #expect(anim.duration == 0.5)
        if case .cubicBezier(let x1, _, _, _) = anim.timingFunction {
            #expect(x1 == 0.175)
        } else {
            Issue.record("Expected cubicBezier timing function")
        }
    }

    @Test("Animation with delay")
    func animationWithDelay() {
        let anim = Animation.default.delay(0.2)
        #expect(anim.delay == 0.2)
        #expect(anim.duration == 0.3) // Original duration preserved
    }

    @Test("Animation speed modifier")
    func animationSpeed() {
        let anim = Animation.default.speed(2.0)
        #expect(anim.duration == 0.15) // 0.3 / 2.0
    }

    @Test("CSS transition all")
    func cssTransitionAll() {
        let anim = Animation.easeInOut(duration: 0.3)
        let css = anim.cssTransitionAll
        #expect(css.contains("all"))
        #expect(css.contains("0.3s"))
        #expect(css.contains("ease-in-out"))
    }

    @Test("CSS transition for specific properties")
    func cssTransitionForProperties() {
        let anim = Animation.easeIn(duration: 0.5)
        let css = anim.cssTransitionValue(for: ["opacity", "transform"])
        #expect(css.contains("opacity"))
        #expect(css.contains("transform"))
        #expect(css.contains("ease-in"))
    }

    @Test("CSS transition with delay")
    func cssTransitionWithDelay() {
        let anim = Animation.default.delay(0.1)
        let css = anim.cssTransitionAll
        #expect(css.contains("0.1s"))
    }
}

@Suite("TimingFunction")
struct TimingFunctionTests {
    @Test("Linear CSS value")
    func linearCss() {
        #expect(TimingFunction.linear.cssValue == "linear")
    }

    @Test("Ease CSS value")
    func easeCss() {
        #expect(TimingFunction.ease.cssValue == "ease")
    }

    @Test("EaseIn CSS value")
    func easeInCss() {
        #expect(TimingFunction.easeIn.cssValue == "ease-in")
    }

    @Test("EaseOut CSS value")
    func easeOutCss() {
        #expect(TimingFunction.easeOut.cssValue == "ease-out")
    }

    @Test("EaseInOut CSS value")
    func easeInOutCss() {
        #expect(TimingFunction.easeInOut.cssValue == "ease-in-out")
    }

    @Test("CubicBezier CSS value")
    func cubicBezierCss() {
        let tf = TimingFunction.cubicBezier(0.25, 0.1, 0.25, 1.0)
        #expect(tf.cssValue == "cubic-bezier(0.25, 0.1, 0.25, 1.0)")
    }

    @Test("Steps CSS value")
    func stepsCss() {
        let tf = TimingFunction.steps(4, .end)
        #expect(tf.cssValue == "steps(4, end)")
    }
}

@Suite("TagTransition")
struct TagTransitionTests {
    @Test("Opacity transition")
    func opacityTransition() {
        let t = TagTransition.opacity
        #expect(t.enterFrom["opacity"] == "0")
        #expect(t.exitTo["opacity"] == "0")
    }

    @Test("Scale transition")
    func scaleTransition() {
        let t = TagTransition.scale
        #expect(t.enterFrom["transform"] != nil)
        #expect(t.enterFrom["opacity"] == "0")
    }

    @Test("Slide transition")
    func slideTransition() {
        let t = TagTransition.slide
        #expect(t.enterFrom["transform"]?.contains("translateX") == true)
    }

    @Test("Combined transitions")
    func combinedTransitions() {
        let combined = TagTransition.opacity.combined(with: TagTransition.scale)
        #expect(combined.enterFrom["opacity"] == "0")
        #expect(combined.enterFrom["transform"] != nil)
    }

    @Test("Transition with custom animation")
    func transitionCustomAnimation() {
        let t = TagTransition.opacity.animation(.spring)
        #expect(t.animation.duration == 0.5)
    }
}

@Suite("AnimationContext", .serialized)
struct AnimationContextTests {
    @Test("AnimationContext initially nil")
    func initiallyNil() {
        AnimationContext.current = nil
        #expect(AnimationContext.current == nil)
    }

    @Test("withAnimation sets context")
    func withAnimationSetsContext() {
        AnimationContext.current = nil
        withAnimation(.easeInOut(duration: 0.5)) {
            // Context should be set during body execution
            #expect(AnimationContext.current != nil)
            #expect(AnimationContext.current?.duration == 0.5)
        }
        // Context remains set (cleared by render cycle, not by withAnimation)
        #expect(AnimationContext.current != nil)
        AnimationContext.current = nil // Clean up
    }

    @Test("withAnimation with default animation")
    func withAnimationDefault() {
        AnimationContext.current = nil
        withAnimation {
            #expect(AnimationContext.current?.duration == 0.3)
        }
        AnimationContext.current = nil // Clean up
    }
}
