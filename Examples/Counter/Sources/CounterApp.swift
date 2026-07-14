import SwiftWUI
import SwiftWUIDOM

// tutorial:begin counter
struct Counter: Tag {
    @State private var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("−") { count -= 1 }
            Button("+") { count += 1 }
            if count >= 10 { P { "Double digits." } }
        }
    }
}
// tutorial:end counter

struct BrowserAPIDemo: Tag {
    @Environment(\.colorScheme) var scheme
    @Environment(\.webSession) var session
    @AppStorage("demo.count") var count = 0
    @State var items: [String] = []
    @State var preview = ""

    struct Payload: Decodable { let items: [String] }

    var body: some Tag {
        Div {
            H2("Browser APIs (phase 8a)")
            P { "System scheme: \(scheme == .dark ? "dark" : "light")" }
            Button("Persisted count: \(count)") { count += 1 }
            Button("Load items") {
                Task {
                    if let p: Payload = try? await session.json(from: "/data.json") {
                        items = p.items
                    }
                }
            }
            Ul { ForEach(items, id: \.self) { item in Li { Text(item) } } }
            Input(type: .file, accept: ".txt,text/plain")
                .onFileSelection { files in
                    guard let f = files.first, f.size < 1_000_000 else { return }
                    Task { preview = (try? await f.text()) ?? "" }
                }
            Pre { Text(preview) }
        }
    }
}

// Task 14 manual smoke: one property animation (opacity/scale toggle under
// withAnimation(.spring…)) driving DOMBackend.animate, plus one enter/exit
// transition branch driving the same WAAPI path via insert/remove.
struct AnimationDemo: Tag {
    @State private var pulsed = false
    @State private var showBanner = false
    var body: some Tag {
        Div {
            H2("Animations (task 14 smoke)")
// tutorial:begin anim-value
            Div { "●" }
                .opacity(pulsed ? 1 : 0.3)
                .scaleEffect(pulsed ? 1.2 : 1.0)
                .animation(.spring(duration: 0.4, bounce: 0.3), value: pulsed)
// tutorial:end anim-value
// tutorial:begin anim-spring
            Button(pulsed ? "Shrink" : "Grow") {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { pulsed.toggle() }
            }
// tutorial:end anim-spring
            Button(showBanner ? "Hide banner" : "Show banner") { showBanner.toggle() }
// tutorial:begin anim-transition
            if showBanner {
                P { "Hello from a transitioning banner." }
                    .transition(.opacity.combined(with: .offset(y: 12)))
            }
// tutorial:end anim-transition
        }
    }
}

// tutorial:begin anim-transform
struct SpinAndSlide: Tag {
    @State private var active = false
    var body: some Tag {
        Div {
            Div { "▲" }
                .offset(x: active ? 40 : 0)
                .rotationEffect(active ? 45 : 0)
                .scaleEffect(active ? 1.3 : 1.0)
                .animation(.snappy, value: active)
            Button(active ? "Reset" : "Animate") { active.toggle() }
        }
    }
}
// tutorial:end anim-transform

// tutorial:begin anim-completion
struct SaveButton: Tag {
    @State private var saved = false
    var body: some Tag {
        Div {
            Span { saved ? "✓ Saved" : "" }
                .opacity(saved ? 1 : 0)
                .animation(.smooth, value: saved)
            Button("Save") {
                withAnimation(.smooth, completion: { saved = false }) {
                    saved = true
                }
            }
        }
    }
}
// tutorial:end anim-completion

// tutorial:begin anim-reduced-motion
struct MotionStatus: Tag {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var body: some Tag {
        P { reduceMotion ? "Reduced motion: ON — animations play instantly." : "Reduced motion: OFF." }
    }
}
// tutorial:end anim-reduced-motion

@main
struct CounterApp: App {
    var body: some Tag {
        Div {
            Counter()
            BrowserAPIDemo()
            AnimationDemo()
            SpinAndSlide()
            SaveButton()
            MotionStatus()
        }
    }
}
