/// Chapter 3 — Create your first project.
public enum Ch03 {
    public static let chapter = Chapter(
        slug: "create-your-first-project", track: .welcome, kicker: "CHAPTER · WELCOME",
        title: "Create your first project",
        tagline: "Scaffold with swiftwui init and iterate with hot reload.",
        minutes: 10, kind: .chapter,
        sections: [
            Section(anchor: "scaffold", kicker: "01 · SCAFFOLD",
                    title: "Scaffold with swiftwui init",
                    intro: "One command creates a complete, buildable SwiftWUI app.",
                    steps: [
                        Step("Run swiftwui init HelloWUI and pick a template with --template: basic, mvvm, or tca."),
                        Step("The generated Package.swift depends on the released SwiftWUI package.",
                             detail: "Pass --swiftwui-path to point the scaffold at a local checkout instead — useful when you are working on the framework itself."),
                        Step("The scaffold ships Package.swift, index.html, a Counter component, a Dockerfile, and an English catalog at Sources/Locales/en.json."),
                        Step("Add --pwa to also scaffold a manifest, icons and a service worker you own.",
                             detail: "You can add it later with swiftwui pwa init."),
                        Step("Add a public/ directory for static assets — fonts, images, a favicon — and swiftwui dev, build, and ssg all serve or copy it."),
                        Step("Everything builds natively too — swift build works without a browser."),
                    ],
                    panel: .terminal(title: "zsh", lines: [
                        TermLine(.command, "swiftwui init HelloWUI"),
                        TermLine(.output, "  created HelloWUI/Package.swift"),
                        TermLine(.output, "  created HelloWUI/Sources/Entry.swift"),
                        TermLine(.output, "  created HelloWUI/Sources/Locales/en.json"),
                        TermLine(.output, "  created HelloWUI/index.html"),
                        TermLine(.output, "  created HelloWUI/Dockerfile"),
                        TermLine(.command, "cd HelloWUI"),
                    ])),
            Section(anchor: "dev-loop", kicker: "02 · DEV LOOP",
                    title: "Iterate with hot reload",
                    intro: "swiftwui dev rebuilds on save and keeps your app state alive.",
                    steps: [
                        Step("swiftwui dev builds the wasm bundle and serves it locally."),
                        Step("Save any Swift file — the page hot-reloads and keeps your @State.",
                             detail: "Live state is snapshotted before the swap and adopted by the new bundle."),
                        Step("This is the freshly scaffolded app in the browser — a working counter out of the box."),
                    ],
                    panel: .browser(url: "localhost:8080", screenshot: "screens/first-project.png")),
        ])
}
