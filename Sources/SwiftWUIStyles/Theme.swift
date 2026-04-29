// Theme.swift - Theme tokens for light / dark mode and arbitrary palettes.
//
// SwiftWUI themes are token bags emitted as CSS custom properties. The
// app declares a `Theme` (typically two — light + dark) and injects the
// produced CSS into its document head via the standard `index.html`
// template, the build pipeline, or the dev server. Components consume
// tokens via `CSSColor.token("name")`, which expands to `var(--name)`
// at paint time.

/// A typed bag of CSS custom property values forming a coherent visual
/// palette. The dictionary keys are the property names (without the
/// `--` prefix) and the values are CSS values (`#fff`, `rgb(0,0,0)`,
/// `12px`, etc.).
///
/// Conform a struct to `Theme` to define your application's palette:
///
/// ```swift
/// struct AppTheme: Theme {
///     static let light = AppTheme(tokens: [
///         "background": "#ffffff",
///         "foreground": "#111111",
///         "accent": "#0066ff",
///     ])
///     static let dark = AppTheme(tokens: [
///         "background": "#0a0a0a",
///         "foreground": "#f5f5f5",
///         "accent": "#3b82f6",
///     ])
///
///     let tokens: [String: String]
/// }
/// ```
public protocol Theme: Sendable {
    /// Map of token name → CSS value. Names are emitted as
    /// `--<name>: <value>;` inside the resulting `:root` rule.
    var tokens: [String: String] { get }
}

extension Theme {
    /// Produce the CSS rule body for this theme — a series of
    /// `--<name>: <value>;` declarations sorted by name for deterministic
    /// output. The caller wraps this in `:root { … }` or a
    /// `[data-theme="…"] { … }` selector.
    public var cssDeclarations: String {
        tokens
            .sorted { $0.key < $1.key }
            .map { "--\($0.key): \($0.value);" }
            .joined(separator: " ")
    }
}

/// Helpers for emitting a complete light + dark palette as CSS.
///
/// The shipped form is:
/// ```css
/// :root { --background: #fff; … }
/// @media (prefers-color-scheme: dark) {
///     :root { --background: #0a0a0a; … }
/// }
/// [data-theme="light"] { --background: #fff; … }
/// [data-theme="dark"] { --background: #0a0a0a; … }
/// ```
///
/// The first two blocks make the system-preference path "just work";
/// the explicit `[data-theme=…]` selectors let an app force a theme via
/// JavaScript / `@AppStorage` regardless of the OS setting.
public enum ThemeCSS {
    /// Render the full CSS for a paired light/dark theme.
    public static func definitions(light: any Theme, dark: any Theme) -> String {
        let lightDecls = light.cssDeclarations
        let darkDecls = dark.cssDeclarations
        return [
            ":root { \(lightDecls) }",
            "@media (prefers-color-scheme: dark) { :root { \(darkDecls) } }",
            "[data-theme=\"light\"] { \(lightDecls) }",
            "[data-theme=\"dark\"] { \(darkDecls) }",
        ].joined(separator: "\n")
    }

    /// Render CSS for a single (non-paired) theme. Useful for apps that
    /// either do not support dark mode or want to register additional
    /// named palettes (high-contrast, sepia, etc.) keyed off
    /// `[data-theme="custom"]`.
    public static func definitions(named name: String, theme: any Theme) -> String {
        "[data-theme=\"\(name)\"] { \(theme.cssDeclarations) }"
    }
}
