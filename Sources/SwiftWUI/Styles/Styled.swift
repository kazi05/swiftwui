/// Component-scoped selector rules (spec §8). Adopt alongside Tag:
///
///     struct SearchForm: Tag, Styled {
///         @RulesBuilder var styles: [Rule] { Rule(class: "field") { $0.padding(.px(8)) } }
///         var body: some Tag { … }
///     }
///
/// Every element resolved in this component's body gets a per-type marker
/// class; selectors compile with the marker attached (Vue-style scoping).
/// Rules do not leak into child components or outward.
public protocol Styled {
    @RulesBuilder var styles: [Rule] { get }
}

/// Marker derived from the fully-qualified type name — stable across
/// instances and passes (scoped ≡ full byte-identical).
func scopeMarker(forTypeName name: String) -> String {
    "swui-s" + String(StyleRegistry.fnv1a(name), radix: 36)
}
