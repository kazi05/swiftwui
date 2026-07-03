public struct Rule {
    enum SelectorBase {
        case cls(String), id(String), element(String)
        var css: String {
            switch self {
            case .cls(let n): return "." + n
            case .id(let n): return "#" + n
            case .element(let n): return n
            }
        }
    }
    let base: SelectorBase
    let media: MediaQuery?
    let proxy: StyleProxy

    static func validated(_ name: String, kind: String) -> String {
        guard CSSSanitize.isValidIdent(name) else {
            assertionFailure("Rule(\(kind):) requires a plain CSS ident, got: \(name)")
            return "swui-invalid"
        }
        return name
    }
    public init(class name: String, media: MediaQuery? = nil, _ build: (inout StyleProxy) -> Void) {
        var p = StyleProxy(); build(&p)
        self.base = .cls(Self.validated(name, kind: "class")); self.media = media; self.proxy = p
    }
    public init(id name: String, media: MediaQuery? = nil, _ build: (inout StyleProxy) -> Void) {
        var p = StyleProxy(); build(&p)
        self.base = .id(Self.validated(name, kind: "id")); self.media = media; self.proxy = p
    }
    public init(element name: String, media: MediaQuery? = nil, _ build: (inout StyleProxy) -> Void) {
        var p = StyleProxy(); build(&p)
        self.base = .element(Self.validated(name, kind: "element")); self.media = media; self.proxy = p
    }

    /// Registers this rule (plus its pseudo blocks) under an optional scope marker.
    @MainActor func register(into registry: StyleRegistry, scope: String?) {
        if !proxy.declarations.isEmpty {
            registry.registerSelector(base: base.css, scope: scope, pseudo: nil,
                                      media: media?.condition, declarations: proxy.declarations)
        }
        for block in proxy.pseudoBlocks {
            registry.registerSelector(base: base.css, scope: scope, pseudo: block.pseudo,
                                      media: media?.condition, declarations: block.declarations)
        }
    }
}

@resultBuilder
public enum RulesBuilder {
    // NOTE: variadic buildBlock alone also covers the empty block (zero args →
    // []). Do NOT add a separate zero-arg overload — it creates an ambiguity.
    public static func buildBlock(_ parts: [Rule]...) -> [Rule] { parts.flatMap { $0 } }
    public static func buildExpression(_ r: Rule) -> [Rule] { [r] }
    public static func buildOptional(_ r: [Rule]?) -> [Rule] { r ?? [] }
    public static func buildEither(first: [Rule]) -> [Rule] { first }
    public static func buildEither(second: [Rule]) -> [Rule] { second }
    public static func buildArray(_ parts: [[Rule]]) -> [Rule] { parts.flatMap { $0 } }
}
