/// Chapter 2 — Install the toolchain.
public enum Ch02 {
    public static let chapter = Chapter(
        slug: "install-the-toolchain", track: .welcome, kicker: "CHAPTER · WELCOME",
        title: "Install the toolchain",
        tagline: "Swift 6.3.3, the matching WASM SDK, and the swiftwui CLI.",
        minutes: 10, kind: .chapter,
        sections: [
            Section(anchor: "swift-toolchain", kicker: "01 · SWIFT",
                    title: "Install Swift with swiftly",
                    intro: "swiftly manages Swift toolchains the way rustup manages Rust.",
                    steps: [
                        Step("Install swiftly, the Swift toolchain manager, from swift.org.",
                             detail: "macOS and Linux installers live at swift.org/install."),
                        Step("Install and select Swift 6.3.3: swiftly install 6.3.3, then swiftly use 6.3.3."),
                        Step("Verify: swift --version should print swift-6.3.3-RELEASE."),
                    ],
                    panel: .terminal(title: "zsh", lines: [
                        TermLine(.command, "swiftly install 6.3.3"),
                        TermLine(.command, "swiftly use 6.3.3"),
                        TermLine(.command, "swift --version"),
                        TermLine(.note, "> Swift version 6.3.3 (swift-6.3.3-RELEASE)"),
                    ])),
            Section(anchor: "wasm-sdk", kicker: "02 · WASM SDK",
                    title: "Add the WebAssembly SDK",
                    intro: "SwiftWUI compiles your app to wasm with the official Swift.org SDK.",
                    steps: [
                        Step("Install the SDK bundle: swift sdk install with the swift-6.3.3-RELEASE_wasm URL from swift.org/download."),
                        Step("Host toolchain and SDK versions must match exactly — 6.3.3 with 6.3.3.",
                             detail: "A mismatched pair fails at link time with confusing errors."),
                        Step("Verify with swift sdk list — the wasm SDK should be listed."),
                    ],
                    panel: .terminal(title: "zsh", lines: [
                        TermLine(.command, "swift sdk install <swift-6.3.3-RELEASE_wasm bundle URL>"),
                        TermLine(.command, "swift sdk list"),
                        TermLine(.note, "> swift-6.3.3-RELEASE_wasm"),
                    ])),
            Section(anchor: "cli", kicker: "03 · CLI",
                    title: "Install the swiftwui CLI",
                    intro: "The CLI carries a project from first file to production build.",
                    steps: [
                        Step("brew tap, brew trust, brew install swiftwui — three commands install the CLI.",
                             detail: "Homebrew builds it from the tagged source release."),
                        Step("Building from a checkout works too: swift build -c release --product swiftwui.",
                             detail: "Or run it in place: swift run swiftwui <command>."),
                        Step("Verify with swiftwui --version."),
                    ],
                    panel: .terminal(title: "zsh", lines: [
                        TermLine(.command, "brew tap kazi05/swiftwui"),
                        TermLine(.command, "brew trust kazi05/swiftwui"),
                        TermLine(.command, "brew install swiftwui"),
                        TermLine(.command, "swiftwui --version"),
                        TermLine(.note, "> 0.9.1"),
                    ])),
        ])
}
