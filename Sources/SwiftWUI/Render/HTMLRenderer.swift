/// Pure Node → String fold. Escaping happens ONLY here (spec §8.2, decision 7).
/// Compact output — its parsed DOM must equal what DOMBackend builds (trap T8).
public enum HTMLRenderer {
    /// Public entry: resolves with throwaway state (initial values, decision 17).
    @MainActor public static func render(_ tag: some Tag) -> String {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                                 invalidate: { _ in })
        return render(coalesceText(resolve(tag, path: .root, ctx: &ctx)))
    }

    /// Phase-5 SSG seam: same render, plus the generated stylesheet text.
    @MainActor public static func renderWithStylesheet(_ tag: some Tag) -> (html: String, css: String) {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                                 invalidate: { _ in })
        let html = render(coalesceText(resolve(tag, path: .root, ctx: &ctx)))
        return (html, ctx.registry.text)
    }

    static func render(_ nodes: [Node]) -> String {
        nodes.map { render($0) }.joined()
    }

    /// SPI (spec §5): SwiftWUIStatic's SSG driver folds an already-resolved
    /// tree (from a live `Runtime`) — not a fresh throwaway resolve. Not API.
    public static func _render(_ nodes: [Node]) -> String { render(nodes) }

    static func render(_ node: Node) -> String {
        switch node {
        case .text(let s):
            return HTMLEscaping.text(s)
        case .component(let c):
            return render(c.children)                        // transparent boundary
        case .element(let el):
            var out = "<" + el.tag
            var names = Array(el.attributes.keys)
            if !el.style.isEmpty { names.append("style") }
            for name in names.sorted() {                      // deterministic goldens
                if name == "style" {
                    out += " style=\"" + HTMLEscaping.text(el.style.cssText) + "\""
                    continue
                }
                let value = el.attributes[name]!
                out += value.isEmpty
                    ? " " + name                              // boolean attribute
                    : " " + name + "=\"" + HTMLEscaping.text(value) + "\""
            }
            var textareaValue: String? = nil
            for name in el.properties.keys.sorted() {
                if name.hasPrefix("swui:cmd:") { continue }   // command channel, never serialized
                if el.tag == "textarea", name == "value",
                   case .string(let s) = el.properties[name]! {
                    textareaValue = s                      // real HTML: child text, not attr
                    continue
                }
                switch el.properties[name]! {
                case .string(let s): out += " " + name + "=\"" + HTMLEscaping.text(s) + "\""
                case .bool(true):    out += " " + name
                case .bool(false):   break
                }
            }
            out += ">"
            if voidElements.contains(el.tag) {
                assert(el.children.isEmpty, "void element <\(el.tag)> cannot have children")
                return out
            }
            return out + (textareaValue.map { HTMLEscaping.text($0) } ?? "")
                + render(el.children) + "</" + el.tag + ">"
        }
    }

    static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    ]
}
