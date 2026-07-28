/// The application entry protocol. `main()` is provided by SwiftWUIDOM as an
/// extension — NEVER a protocol requirement (spec §3.5): native builds of the
/// core must not link the DOM runtime.
public protocol App {
    associatedtype Content: Tag
    init()
    @TagBuilder var body: Content { get }
    /// Document-level rules (resets, body styles). Unscoped, registered once at mount.
    @RulesBuilder static var globalStyles: [Rule] { get }
    /// Theme definitions: first-registered default theme emits :root.
    static var themes: [ThemeDefinition] { get }
    /// `@font-face` declarations, registered app-wide once at mount.
    static var fontFaces: [FontFace] { get }
    /// Site-wide prerender default for routes that declare none (spec §4.3).
    /// nil = "said nothing" — resolution falls through to
    /// `StaticSiteConfig.defaultPrerender`, then to phase-5 behaviour.
    static var prerender: Prerender? { get }
    /// Declared by localized apps: `Localization(catalog: L10n.self, default: .ru)`.
    /// nil (the default) keeps every localization branch inert.
    static var localization: Localization? { get }
}

extension App {
    public static var globalStyles: [Rule] { [] }
    public static var themes: [ThemeDefinition] { [] }
    public static var fontFaces: [FontFace] { [] }
    public static var prerender: Prerender? { nil }
    public static var localization: Localization? { nil }
}
