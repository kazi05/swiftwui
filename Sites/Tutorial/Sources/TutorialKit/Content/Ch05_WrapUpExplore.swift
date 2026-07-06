/// Chapter 5 — Wrap-up: Explore SwiftWUI.
public enum Ch05 {
    public static let chapter = Chapter(
        slug: "wrap-up-explore", track: .explore, kicker: "WRAP-UP · EXPLORE SWIFTWUI",
        title: "Wrap-up: Explore SwiftWUI",
        tagline: "What you learned building your first SwiftWUI page.",
        minutes: 5, kind: .wrapUp,
        recap: [
            "Tag is SwiftWUI’s View: a value-semantic struct with a @TagBuilder body.",
            "Uppercase tags mirror HTML; attributes are typed init parameters.",
            "@State plus event closures give reactivity with zero JavaScript.",
            "swiftwui init / dev / build / ssg / serve carries a project from scaffold to production.",
        ],
        quiz: Quiz(questions: [
            Question(prompt: "Which target does SwiftWUI compile to for the browser?",
                     options: ["x86_64 native", "WebAssembly via the swift-6.3.3-RELEASE_wasm SDK", "The JVM"],
                     correctIndex: 1,
                     explanation: "The app compiles to wasm; JavaScriptKit bridges it to the DOM."),
            Question(prompt: "What happens to sibling DOM nodes when one @State value changes?",
                     options: ["The whole page re-creates", "Only the changed nodes are patched", "Nothing until reload"],
                     correctIndex: 1,
                     explanation: "The reconciler diffs the resolved trees and applies a minimal patch set."),
            Question(prompt: "Where do Button event closures run?",
                     options: ["In generated JavaScript", "In Swift, compiled to wasm", "On a server"],
                     correctIndex: 1,
                     explanation: "Listeners do a fire-time lookup into the Swift-side listener registry."),
        ]))
}
