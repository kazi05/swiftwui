import SwiftWUI

/// Chapter: "Motion". Three moving parts — a looping `@keyframes` animation, an
/// in-page view transition, and a shared element that morphs across a
/// navigation. The app-wide navigation default, `.pageTransition(.fade)` on the
/// `Router`, lives in TourApp.swift's `tour-routes` region.

// tutorial:begin tour-motion2-keyframes
enum LoadingMotion {
    /// A `Keyframes` value emits nothing on its own: the block reaches the
    /// stylesheet only when `.animation` attaches it, under a hash-suffixed
    /// name, so two identical values collapse into one `@keyframes` rule.
    static let sweep = Keyframes("tour-sweep") { k in
        k.from { $0.style("translate", "-120% 0"); $0.opacity(0.4) }
        k.at(50) { $0.opacity(1) }
        k.to { $0.style("translate", "340% 0"); $0.opacity(0.4) }
    }
}

struct IndeterminateBar: Tag {
    var body: some Tag {
        Div {
            Div()
                .width(.percent(30)).height(.percent(100))
                .background(.hex("#1c1917")).borderRadius(.px(999))
                // The rule lands inside `@media (prefers-reduced-motion:
                // no-preference)`, so under `reduce` the fill never moves. It
                // has to read as "loading" while standing still.
                .animation(LoadingMotion.sweep, duration: .ms(1400),
                           timingFunction: .easeInOut, iterations: .infinite)
        }
        .width(.percent(100)).maxWidth(.px(320)).height(.px(8))
        .background(.hex("#eceae6")).borderRadius(.px(999)).overflow(.hidden)
    }
}
// tutorial:end tour-motion2-keyframes

// tutorial:begin tour-motion2-hero
struct TourHero: Tag {
    let title: String

    var body: some Tag {
        H1(title)
            .fontSize(.rem(1.6))
            // Both routes must name the element identically for the browser to
            // interpolate one rect into the other, and a `view-transition-name`
            // must be unique in the document at any one moment — a duplicate
            // aborts the whole transition. `duration`/`timingFunction` tune this
            // one group through the two timing longhands; setting
            // `animation-name` on `::view-transition-group()` by hand instead
            // would delete the UA's measured morph.
            .matchedTransition(id: "tour-hero", duration: .ms(320),
                               timingFunction: .easeInOut)
    }
}
// tutorial:end tour-motion2-hero

// tutorial:begin tour-motion2-tabs
struct MotionDemo: Tag {
    @State private var tab = "Keyframes"
    private let tabs = ["Keyframes", "Transitions", "Morphs"]

    var body: some Tag {
        Main(class: "tour") {
            TourHero(title: "Motion")
            Div {
                ForEach(tabs, id: \.self) { name in
                    Div {
                        Button(name) {
                            // Every state write the body makes commits inside one
                            // browser view transition. Calling this during body
                            // evaluation is illegal — an event handler is the
                            // only place a write belongs.
                            withViewTransition(.fade.duration(.ms(200))) { tab = name }
                        }
                        .style("border", "none").background(.transparent)
                        .cursor(.pointer).fontSize(.rem(1))
                        .padding(vertical: .px(6), horizontal: .zero)
                        if name == tab {
                            // One underline exists at a time, so reusing the name
                            // on the next tab's underline slides this rect across
                            // instead of cross-fading two separate bars.
                            Div()
                                .height(.px(2)).background(.hex("#1c1917"))
                                .matchedTransition(id: "tour-tab-underline")
                        }
                    }
                }
            }
            .display(.flex).gap(.px(20))

            if tab == "Keyframes" {
                P { "One looping animation, registered once and deduped by hash." }
                IndeterminateBar()
            } else if tab == "Transitions" {
                P { "Switching tabs is a single state write wrapped in withViewTransition." }
            } else {
                P { "The page title is a shared element: give another route the same id and it morphs on navigation." }
            }

            Link("/") { Span { "Back to the tour" } }
                // Per-destination override of the Router's app-wide fade.
                .pageTransition(.slide(edge: .trailing))
        }
    }
}
// tutorial:end tour-motion2-tabs
