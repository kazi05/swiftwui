/// Pure Node → String fold. Escaping happens ONLY here (spec §8.2, decision 7).
/// Compact output — its parsed DOM must equal what DOMBackend builds (trap T8).
public enum HTMLRenderer {
    /// Public entry: resolves with throwaway state (initial values, decision 17).
    @MainActor public static func render(_ tag: some Tag) -> String {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                                 invalidate: { _ in })
        return render(coalesceText(resolve(tag, path: .root, ctx: &ctx)))
    }

    static func render(_ nodes: [Node]) -> String {
        nodes.map { render($0) }.joined()
    }

    static func render(_ node: Node) -> String {
        switch node {
        case .text(let s):
            return HTMLEscaping.text(s)
        case .component(let c):
            return render(c.children)                        // transparent boundary
        case .element(let el):
            var out = "<" + el.tag
            for name in el.attributes.keys.sorted() {        // deterministic goldens
                let value = el.attributes[name]!
                out += value.isEmpty
                    ? " " + name                              // boolean attribute
                    : " " + name + "=\"" + HTMLEscaping.text(value) + "\""
            }
            out += ">"
            if voidElements.contains(el.tag) {
                assert(el.children.isEmpty, "void element <\(el.tag)> cannot have children")
                return out
            }
            return out + render(el.children) + "</" + el.tag + ">"
        }
    }

    static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "source", "track", "wbr",
    ]
}
