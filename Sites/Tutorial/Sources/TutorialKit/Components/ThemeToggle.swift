import SwiftWUI

/// Three-state theme control (identity §1): auto → light → dark.
///
/// The prerendered label is `auto` because `@AppStorage` has no store during
/// SSG. On the client the box hydrates from localStorage before the first
/// render, so hydration re-labels one fixed-width button and `onAppear` writes
/// the single `[data-theme]` attribute — no layout shift, no flash.
public struct ThemeToggle: Tag {
    @Environment(\.setTheme) private var setTheme
    @AppStorage("theme") private var stored: String? = nil

    public init() {}

    public var body: some Tag {
        let mode = stored ?? "auto"
        let next = Self.next(after: stored)
        return Button(type: .button, class: "tut-theme-toggle",
                      onClick: { cycle(to: next) }) {
            Text(mode)
        }
        .attribute("aria-label", "Theme: \(mode). Switch to \(next ?? "auto").")
        .onAppear { if let stored { setTheme(stored) } }
    }

    private func cycle(to theme: String?) {
        stored = theme          // nil removes the key — "auto" is the absence of a choice
        setTheme(theme)
    }

    private static func next(after theme: String?) -> String? {
        switch theme {
        case nil: "light"
        case "light": "dark"
        default: nil
        }
    }
}
