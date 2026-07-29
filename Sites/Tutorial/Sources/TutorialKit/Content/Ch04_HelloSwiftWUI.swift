/// Chapter 4 — Hello, SwiftWUI (Figma 1:2).
public enum Ch04 {
    static let counterCode = #"""
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
"""#

    static let helloCode = #"""
struct Hello: Tag {
    var body: some Tag {
        Div(class: "card") {
            H1("Hello, SwiftWUI")
            P { "Swift on the web —" }
            P { "no JavaScript required." }
            A(href: "/docs") { "Read the docs" }
        }
    }
}
"""#

    public static let chapter = Chapter(
        slug: "hello-swiftwui", track: .explore, kicker: "GETTING STARTED",
        title: "Hello, SwiftWUI",
        tagline: "Build the web in pure Swift.",
        body: "You’ll build Counter — an interactive page written entirely in Swift, compiled to WebAssembly, and rendered through a SwiftUI-style declarative API. No JavaScript required.",
        minutes: 25, kind: .chapter,
        heroPanel: .code(CodePanel(file: "Counter.swift", code: counterCode,
                                   origin: .sample(path: "Examples/Counter/Sources/CounterApp.swift",
                                                   marker: "counter"))),
        sections: [
            Section(anchor: "toolchain", kicker: "01 · TOOLCHAIN",
                    title: "Scaffold a project in seconds",
                    intro: "The swiftwui CLI carries a project from first file to production build: init, dev, build, ssg, serve.",
                    steps: [
                        Step("Install the SwiftWUI toolchain and the matching Swift WASM SDK."),
                        Step("Run swiftwui init counter and pick a template: basic, mvvm, or tca-style."),
                        Step("swiftwui dev compiles the app and serves it locally."),
                        Step("Edit any file — hot reload updates the page and keeps your @State."),
                    ],
                    panel: .terminal(title: "zsh — counter", lines: [
                        TermLine(.command, "swiftwui init counter"),
                        TermLine(.output, "  created counter/Package.swift"),
                        TermLine(.output, "  created counter/Sources/Entry.swift"),
                        TermLine(.output, "  created counter/Dockerfile"),
                        TermLine(.command, "cd counter"),
                        TermLine(.command, "swiftwui dev"),
                        TermLine(.note, "> dev server on http://localhost:8080"),
                        TermLine(.note, "> watching sources — hot reload on"),
                    ])),
            Section(anchor: "core-api", kicker: "02 · CORE API",
                    title: "Declare your interface with Tags",
                    intro: "Tag is SwiftWUI’s View: plain structs with a @TagBuilder body. Uppercase tags mirror HTML, and attributes are typed init parameters.",
                    steps: [
                        Step("Conform a struct to Tag and return markup from body."),
                        Step("Compose Div, H1, P, A, Button — the nesting reads like the DOM it renders."),
                        Step("Pass attributes as typed parameters: Div(class: \"card\"), A(href: \"/docs\")."),
                        Step("No classes, no inheritance — value-semantic structs all the way down."),
                    ],
                    panel: .code(CodePanel(file: "Hello.swift", code: helloCode,
                                           origin: .sample(path: "Examples/Counter/Sources/Hello.swift",
                                                           marker: "hello")))),
            Section(anchor: "state", kicker: "03 · STATE",
                    title: "Add state, get reactivity",
                    intro: "@State works the way you know from SwiftUI: assign a new value and the framework re-renders exactly what changed — nothing more.",
                    steps: [
                        Step("Declare @State var count = 0 inside your Tag.",
                             panel: .code(CodePanel(file: "Counter.swift", code: counterCode,
                                                    origin: .sample(path: "Examples/Counter/Sources/CounterApp.swift",
                                                                    marker: "counter")))),
                        Step("Mutate it from an event closure: Button(\"+\") { count += 1 }."),
                        Step("Writes coalesce — many mutations, one DOM flush per microtask."),
                        Step("Structural identity keeps state stable across re-renders and list reorders."),
                    ],
                    panel: .browser(url: "localhost:8080", screenshot: "screens/counter-3.png")),
        ],
        quiz: Quiz(questions: [
            Question(prompt: "Which property wrapper drives re-rendering in SwiftWUI?",
                     options: ["@Environment", "@State", "@Binding"], correctIndex: 1,
                     explanation: "Assigning a new value to @State invalidates the owning component; the runtime re-renders and patches only that subtree."),
            Question(prompt: "What happens when you save a file while swiftwui dev is running?",
                     options: ["The page fully reloads and loses state",
                               "The wasm rebuilds and hot reload preserves your @State",
                               "Nothing until you refresh manually"], correctIndex: 1,
                     explanation: "The dev server rebuilds, snapshots live @State, and the new bundle adopts it."),
            Question(prompt: "How are Tag bodies written?",
                     options: ["HTML template strings", "A @TagBuilder result builder", "JSX"],
                     correctIndex: 1,
                     explanation: "@TagBuilder is a Swift result builder — the same mechanism as SwiftUI’s ViewBuilder."),
        ]))
}
