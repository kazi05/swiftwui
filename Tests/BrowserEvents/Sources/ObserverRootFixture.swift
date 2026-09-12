import SwiftWUI
import JavaScriptKit

enum RootProbe {
    static func record(_ name: String, _ value: Bool) {
        _ = JSObject.global.__rootProbe.object![name].object!.push!(value)
    }
}

struct ObserverRootFixture: Tag {
    @State private var margin = true
    @State private var innerMarked = true
    @State private var missing = false
    @State private var mounted = true
    @State private var exitingMounted = true

    var body: some Tag {
        Div {
            Button("Toggle margin") { margin.toggle() }.attribute("id", "root-margin-toggle")
            Button("Toggle marker") { innerMarked.toggle() }.attribute("id", "root-marker-toggle")
            Button("Toggle missing") { missing.toggle() }.attribute("id", "root-missing-toggle")
            Button("Toggle subtree") { mounted.toggle() }.attribute("id", "root-mount-toggle")
            Button("Exit") { withAnimation(.linear(duration: 10)) { exitingMounted = false } }
                .attribute("id", "root-exit")
        }
        Div(id: "configured-clip") {
            Div(id: "configured-target")
                .attribute("style", "width:100px;height:100px;transform:translateY(90px)")
                .onVisibilityChange(threshold: 0.5, root: .ancestor(id: "clip")) {
                    RootProbe.record("clipped", $0)
                }
        }
        .attribute("style", "position:fixed;left:400px;top:100px;width:100px;height:100px;overflow:hidden")
        .visibilityRoot(id: "clip")
        Div(id: "configured-margin")
            .attribute("style", "position:fixed;left:600px;top:550px;width:40px;height:40px")
            .onVisibilityChange(root: .viewport, rootMargin: margin ? .init(bottom: .px(-100)) : .zero) {
                RootProbe.record("margin", $0)
            }
        if mounted {
            Div(id: "scope-outer") {
                Div(id: "scope-inner") {
                    Div(id: "scope-target")
                        .attribute("style", "position:absolute;top:60px;width:20px;height:20px")
                        .onVisibilityChange(root: .ancestor(id: missing ? "absent" : "scope")) {
                            RootProbe.record("scoped", $0)
                        }
                }
                .attribute("style", "position:relative;width:100px;height:40px;overflow:visible")
                .visibilityRoot(id: innerMarked ? "scope" : "other")
            }
            .attribute("style", "position:fixed;left:520px;top:100px;width:100px;height:100px;overflow:hidden")
            .visibilityRoot(id: "scope")
        }
        Div(id: "offscreen-root") {
            Div(id: "offscreen-target").attribute("style", "width:20px;height:20px")
                .onVisibilityChange(root: .ancestor(id: "offscreen")) {
                    RootProbe.record("offscreenRoot", $0)
                }
                .onVisibilityChange { RootProbe.record("offscreenViewport", $0) }
        }
        .attribute("style", "position:fixed;left:400px;top:2000px;width:100px;height:100px;overflow:hidden")
        .visibilityRoot(id: "offscreen")
        Div {
            if exitingMounted {
                Div(id: "configured-exiting").attribute("style", "width:20px;height:20px")
                    .onVisibilityChange(root: .ancestor(id: "exit")) {
                        RootProbe.record("exiting", $0)
                    }
                    .transition(.opacity)
            }
        }
        .attribute("style", "position:fixed;left:650px;top:100px;width:100px;height:100px;overflow:hidden")
        .visibilityRoot(id: "exit")
    }
}
