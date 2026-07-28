/// Chapter 17 — Keyframes and view transitions. Pinned to Samples/Tour.
public enum Ch17 {
    static let keyframesCode = #"""
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
"""#

    static let heroCode = #"""
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
"""#

    static let tabsCode = #"""
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
"""#

    public static let chapter = Chapter(
        slug: "keyframes-and-transitions", track: .motion, kicker: "CHAPTER · MOTION",
        title: "Keyframes and view transitions",
        tagline: "Looping CSS animation as a value, and navigation the browser animates for you.",
        minutes: 20, kind: .chapter,
        sections: [
            Section(anchor: "kf-value", kicker: "01 · KEYFRAMES",
                    title: "A keyframes block is a value",
                    intro: "The previous chapter's springs animate a change: state moved, and the engine interpolates towards the new value. A loading bar has no change to interpolate — it repeats until the data lands, which is what a CSS @keyframes block is for.",
                    steps: [
                        Step("Build a Keyframes value with from, at(_:) and to.",
                             detail: "Each stop hands you the same StyleProxy the .style { } modifier does."),
                        Step("Attach it at the use site with .animation(_:duration:timingFunction:iterations:).",
                             detail: "The value emits no CSS on its own; nothing reaches the stylesheet until a call site references it."),
                        Step("Reach for a keyframe when nothing in your state changed.",
                             detail: "Loading bars, ambient loops, attention pulses — .infinite is honest here in a way it never is for a spring."),
                        Step("Reach for withAnimation or .animation(_:value:) when a value did change.",
                             detail: "That engine interpolates between two states and stays interruptible; a keyframe replays a fixed script."),
                        Step("Keep one CSS property to one engine per element.",
                             detail: "A running CSS animation outranks the inline declaration the state-driven engine writes, so that value never lands while the loop plays."),
                    ],
                    panel: .code(CodePanel(file: "Motion.swift", code: keyframesCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/Motion.swift",
                                                           marker: "tour-motion2-keyframes")))),
            Section(anchor: "kf-registration", kicker: "02 · REGISTRATION",
                    title: "What reaches the stylesheet",
                    intro: "The block you wrote is not quite the block the browser sees. The name gains a hash, and the rule that applies it gains a media query.",
                    steps: [
                        Step("Expect a hash suffix on the emitted name.",
                             detail: "@keyframes is last-wins by name, so two values sharing one name would fight; the hash covers the stops, which also collapses two identical bodies into a single rule."),
                        Step("Pass a name for readability in devtools, not for identity.",
                             detail: "An invalid identifier is dropped at init and the value falls back to the framework's swui-kf- prefix rather than breaking out of the style prelude."),
                        Step("Look for the applying rule inside @media (prefers-reduced-motion: no-preference).",
                             detail: "The @keyframes block itself is never wrapped — a definition nothing references is inert."),
                        Step("Make the element read correctly standing still.",
                             detail: "Under reduce the rule never applies, so a bar that only says \"loading\" by moving says nothing at all."),
                        Step("Pass respectsReducedMotion: false only when the motion carries information.",
                             detail: "And never rely on fillMode: .forwards for a visible end state — the gate suppresses the whole rule, fill included."),
                    ],
                    panel: .terminal(title: "zsh — tour", lines: [
                        TermLine(.command, "swiftwui ssg --out dist"),
                        TermLine(.note, "> generated 7 pages, 1 sitemap file(s)"),
                        TermLine(.command, "grep -o '@keyframes tour-sweep-[a-z0-9]*' dist/styles.css"),
                        TermLine(.note, "> @keyframes tour-sweep-1qk3vf"),
                        TermLine(.command, "grep -c 'prefers-reduced-motion: no-preference' dist/styles.css"),
                        TermLine(.note, "> 1"),
                    ])),
            Section(anchor: "vt-navigation", kicker: "03 · NAVIGATION",
                    title: "Transitions the browser runs for you",
                    intro: "A route change swaps the whole page, and the browser will animate that swap itself once you name a transition. Four presets, three tuning methods, one precedence chain.",
                    steps: [
                        Step("Set the app-wide default with .pageTransition on the Router.",
                             detail: "The tour declares .fade there; every Link click inherits it."),
                        Step("Override per destination on a Link, or on the route with Route(transition:).",
                             detail: "Route(transition:) applies when that route is the destination — never when it is the page being left."),
                        Step("Pass transition: at the call site to beat both.",
                             detail: "Precedence: the navigate(to:transition:) argument, then the destination route's transition, then the nearest ambient .pageTransition."),
                        Step("Disable inheritance with .pageTransition(nil).",
                             detail: "Explicitly nil and never set are the same state end to end, so an outer default cannot leak back in."),
                        Step("Expect a redirect to stay still.",
                             detail: "navigate(_:replace: true) never arms a transition on its own; pass transition: at that call if a replace should animate."),
                    ],
                    panel: .code(CodePanel(file: "Motion.swift", code: tabsCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/Motion.swift",
                                                           marker: "tour-motion2-tabs")))),
            Section(anchor: "vt-matched", kicker: "04 · MATCHED",
                    title: "One element that survives the swap",
                    intro: "Give an element the same name on both sides of a navigation and the browser interpolates one rect into the other instead of cross-fading two pages.",
                    steps: [
                        Step("Mark both sides with .matchedTransition(id:).",
                             detail: "The ids have to match exactly; two different ids animate as two unrelated elements."),
                        Step("Keep every name unique in the document at any one moment.",
                             detail: "Two rendered elements sharing a name make the browser reject the transition outright — a debug build warns after the render that caused it."),
                        Step("Tune a single group with duration: and timingFunction:.",
                             detail: "Setting animation-name on ::view-transition-group() by hand deletes the UA's measured morph; these two parameters exist so you never reach for it."),
                        Step("Spell contentFit as TransitionContentFit.none when you mean the case.",
                             detail: "A bare .none binds to Optional.none, which means \"leave the UA behaviour alone\" — the opposite of what it reads as."),
                        Step("Avoid root and any -ua- prefixed name.",
                             detail: "Both are reserved; the declaration is dropped rather than emitting a colliding rule."),
                    ],
                    panel: .code(CodePanel(file: "Motion.swift", code: heroCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/Motion.swift",
                                                           marker: "tour-motion2-hero")))),
            Section(anchor: "vt-in-page", kicker: "05 · IN-PAGE",
                    title: "Transitions without a navigation",
                    intro: "A tab switch, a filter, a sort: no route changes, but the same machinery applies. Wrap the state write instead of the navigation.",
                    steps: [
                        Step("Wrap the writes in withViewTransition(_:) inside an event handler.",
                             detail: "Every state write the closure makes commits inside one browser transition; calling it during body evaluation is illegal, like any state write."),
                        Step("Expect nothing to animate when nothing is written.",
                             detail: "A closure that writes no state arms no transition."),
                        Step("Reuse one matchedTransition id for the element that moves.",
                             detail: "Only one underline exists at a time, so the same name on the next tab's underline slides that rect across instead of cross-fading two bars."),
                        Step("Nest calls freely — each one saves and restores the active transition."),
                    ],
                    panel: .code(CodePanel(file: "Motion.swift", code: tabsCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/Motion.swift",
                                                           marker: "tour-motion2-tabs")))),
            Section(anchor: "vt-flip-fallback", kicker: "06 · FALLBACK",
                    title: "The FLIP fallback and what it gives up",
                    intro: "Browsers without document.startViewTransition get a bounded FLIP animation rather than nothing. It is deliberately partial, and the list of what it drops is short enough to read once.",
                    steps: [
                        Step("Force the fallback with ?swui-vt=flip while developing.",
                             detail: "It is the only practical way to exercise that path in a browser that supports the native API."),
                        Step("Expect only named elements to travel.",
                             detail: "The outgoing page disappears at once — there is no old frame to fade out."),
                        Step("Expect clipping and distortion.",
                             detail: "A traveling element stays in normal flow, so an ancestor overflow: hidden still clips it, and size changes are faked with scale, which distorts text, borders and shadows."),
                        Step("Expect .custom(old:new:) and .zoom(sourceID:) to degrade to a plain FLIP.",
                             detail: "There are no ::view-transition-* pseudo-elements in the fallback to attach keyframes to."),
                        Step("Leave translate and scale to the fallback for the duration.",
                             detail: "Both are reserved while it plays; an animation that has to survive one belongs on transform."),
                    ],
                    panel: .terminal(title: "zsh — tour", lines: [
                        TermLine(.command, "swiftwui dev"),
                        TermLine(.note, "> serving http://127.0.0.1:8080 — watching Sources/ (Ctrl-C to stop)"),
                        TermLine(.note, "> open /motion?swui-vt=flip to force the FLIP path"),
                        TermLine(.command, "swiftwui build --out dist"),
                        TermLine(.note, "> builds disable view transitions outright — view-transition-name still ships as an inline style"),
                    ])),
        ],
        quiz: Quiz(questions: [
            Question(prompt: "A badge animates with .animation(pulse, duration: .s(1), fillMode: .forwards) and its last stop shrinks it. A visitor has prefers-reduced-motion: reduce. What do they see?",
                     options: ["The badge at the end state, applied instantly",
                               "One pass at duration 0 that holds the end state",
                               "The badge at its authored size — the rule that applies the animation is suppressed, fill included",
                               "The animation as authored — the gate covers only spring animations"],
                     correctIndex: 2,
                     explanation: "The animation lands in a rule wrapped in @media (prefers-reduced-motion: no-preference). Under reduce that rule never matches, so nothing applies — including the forwards fill. An end state that matters belongs in the element's own styles."),
            Question(prompt: "Two cards are rendered at the same time and both carry .matchedTransition(id: \"card\"). A navigation starts. What happens?",
                     options: ["The first element in DOM order wins and morphs",
                               "The browser rejects the whole transition — the page still updates, it just does not animate",
                               "Both morph towards the same destination rect",
                               "The framework renames the second one automatically"],
                     correctIndex: 1,
                     explanation: "A view-transition-name has to be unique in the document at any one moment. A duplicate aborts the entire transition with no app-visible error; a debug build prints a warning after the render that introduced it."),
            Question(prompt: "A route guard redirects with navigate(to: \"/login\", replace: true). The Router declares .pageTransition(.fade) and the /login route declares nothing. What animates?",
                     options: ["Nothing — a replace navigation never arms a transition on its own",
                               "The Router's fade, inherited as the ambient default",
                               "The browser's default cross-fade",
                               "Nothing, because ambient transitions apply to Link clicks only"],
                     correctIndex: 0,
                     explanation: "The resolved transition is the explicit transition: argument, or — for a non-replace navigation only — the destination route's transition, then the ambient one. replace: true short-circuits that chain, so a redirect animates only when the call passes transition: itself."),
        ]))
}
