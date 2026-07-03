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
    static func isExternal(_ url: String) -> Bool {
        if url.hasPrefix("//") { return true }
        for ch in url {
            if ch == ":" { return true }
            if ch == "/" || ch == "?" || ch == "#" { return false }
        }
        return false
    }

    public var body: some Tag {
        let dest = destination
        let nav = navigate
        if Self.isExternal(dest) || target != nil {
            A(href: dest, target: target) { content }
        } else {
            A(href: dest) { content }
                .attribute("data-swui-link", "")
                .onClickEvent { e in
                    guard e?.isModified != true else { return }   // browser: new tab etc.
                    nav(dest)
                }
        }
    }
}
