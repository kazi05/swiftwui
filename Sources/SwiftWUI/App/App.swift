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
}

extension App {
    public static var globalStyles: [Rule] { [] }
    public static var themes: [ThemeDefinition] { [] }
}
