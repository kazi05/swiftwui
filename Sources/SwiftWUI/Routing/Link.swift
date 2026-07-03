/// SPA link (spec §8). Internal destination → <a data-swui-link> whose click
/// is intercepted into `\.navigate`; external destination (scheme or "//")
/// or an explicit `target` → plain <a>, the browser handles it. href is
/// scheme-sanitized by `A` itself.
public struct Link<Content: Tag>: Tag {
    @Environment(\.navigate) private var navigate
    let destination: String
    let target: LinkTarget?
    let content: Content

    public init(_ destination: String, target: LinkTarget? = nil,
                @TagBuilder content: () -> Content) {
        self.destination = destination
        self.target = target
        self.content = content()
    }

    /// "https://…", "mailto:…", "//host/…" — anything that leaves the app.
    static func isExternal(_ url: String) -> Bool { RouteURL.isExternal(url) }

    public var body: some Tag {
        let dest = destination
        let nav = navigate
        if Self.isExternal(dest) || target != nil || dest.hasPrefix("#") {
            A(href: dest, target: target) { content }          // browser handles: external, targeted, or #anchor
        } else {
            let _ = assert(dest.hasPrefix("/"),
                           "Link destination must be root-relative ('/docs/intro'), got '\(dest)' — relative paths resolve against the SSG file location, not the route")
            A(href: dest) { content }
                .attribute("data-swui-link", "")
                .onClickEvent { e in
                    guard e?.isModified != true else { return }   // browser: new tab etc.
                    nav(dest)
                }
        }
    }
}
