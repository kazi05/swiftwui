import JavaScriptKit
import SwiftWUI
import SwiftWUIDOM

/// Keep the probe outside reactive state so recording a callback cannot
/// schedule another render or change the geometry under observation.
enum BrowserProbe {
    static func record(_ name: String, _ value: Bool) {
        let probe = JSObject.global.__browserEvents.object!
        _ = probe[name].object!.push!(value)
    }
}

struct VisibilityFixture: Tag {
    @State private var mounted = true
    var body: some Tag {
        Div(id: "fixtures") {
            Button("Unmount observed elements") { mounted = false }
                .attribute("id", "unmount")
            if mounted {
                Div(id: "clip") {
                    Div(id: "target")
                        .attribute("style", "width:100px;height:100px;transform:translateY(90px)")
                        .onVisibilityChange { BrowserProbe.record("zero", $0) }
                        .onVisibilityChange(threshold: 0.5) { BrowserProbe.record("half", $0) }
                        .onVisibilityChange(threshold: 1) { BrowserProbe.record("full", $0) }
                }
                .attribute("style", "width:100px;height:100px;overflow:hidden")
                Div(id: "zero-size")
                    .attribute("style", "width:0;height:0")
                    .onVisibilityChange(threshold: 1) { BrowserProbe.record("zeroSize", $0) }
            }
        }
    }
}

struct KeyboardFixture: Tag {
    @State private var draft = ""
    @State private var sent = 0
    @State private var enabled = true

    var body: some Tag {
        Div {
            Textarea(text: $draft, id: "composer")
                .onKeyDown { event in
                    BrowserProbe.record("composition", event.isComposing)
                    guard event.key == "Enter", !event.shiftKey, !event.isComposing else { return }
                    let copy = event
                    copy.preventDefault()
                    guard enabled, !draft.isEmpty, !event.repeated else { return }
                    sent += 1
                }
                .onKeyUp { event in
                    BrowserProbe.record("keyUpComposition", event.isComposing)
                    if event.key == "Escape" { event.preventDefault() }
                }
            Span(id: "sent") { Text("\(sent)") }
            Button("Toggle sending") { enabled.toggle() }
                .attribute("id", "toggle-sending")
            Textarea(id: "late") {}
                .onKeyDown { event in
                    guard event.key == "Enter" else { return }
                    Task { @MainActor in
                        event.preventDefault()
                        BrowserProbe.record("late", true)
                    }
                }
        }
    }
}

@main
struct BrowserEventsApp: App {
    init() {
        #if DEBUG
        if JSObject.global.location.search.string == "?diagnostics" {
            DOMRuntime.enableDevTools(limit: 32)
        }
        #endif
    }
    var body: some Tag {
        if JSObject.global.location.pathname.string?.hasPrefix("/modern") == true {
            ModernWebFixture()
        } else if JSObject.global.location.search.string == "?scroll" {
            ScrollFixture()
        } else {
            VisibilityFixture()
            ObserverRootFixture()
            KeyboardFixture()
            BlobFixture()
            ViewportFixture(startMounted: JSObject.global.location.search.string != "?viewport-animation-first")
        }
    }
}
