/// Declaration collector shared by rules, Style bundles, and pseudo blocks.
/// Statement style: `s.padding(.px(8))`.
public struct StyleProxy {
    var declarations: [StyleDeclaration] = []
    var pseudoBlocks: [(pseudo: String, declarations: [StyleDeclaration])] = []
    var mediaBlocks: [(media: String, declarations: [StyleDeclaration])] = []

    mutating func _add(_ d: StyleDeclaration) { declarations.append(d) }

    public mutating func style(_ property: String, _ value: String) {
        guard CSSSanitize.isValidIdent(property), CSSSanitize.isSafeValue(value) else {
            assertionFailure("invalid style declaration: \(property): \(value)")
            return
        }
        _add(StyleDeclaration(property: property, value: value))
    }

    mutating func _pseudo(_ name: String, _ body: (inout StyleProxy) -> Void) {
        var sub = StyleProxy()
        body(&sub)
        assert(sub.pseudoBlocks.isEmpty, "nested pseudo blocks are not supported")
        assert(sub.mediaBlocks.isEmpty, "nested media blocks are not supported")
        guard !sub.declarations.isEmpty else { return }   // empty block → nothing to register
        pseudoBlocks.append((name, sub.declarations))
    }
    public mutating func hover(_ body: (inout StyleProxy) -> Void)  { _pseudo(":hover", body) }
    public mutating func focus(_ body: (inout StyleProxy) -> Void)  { _pseudo(":focus", body) }
    public mutating func active(_ body: (inout StyleProxy) -> Void) { _pseudo(":active", body) }

    /// Media block collector for `Style` bundles (spec §10 promises media in
    /// bundles). Same shape as `_pseudo`: a sub-proxy collects declarations,
    /// no nested pseudo/media blocks.
    public mutating func media(_ query: MediaQuery, _ body: (inout StyleProxy) -> Void) {
        var sub = StyleProxy()
        body(&sub)
        assert(sub.pseudoBlocks.isEmpty, "pseudo blocks inside a media block are not supported")
        assert(sub.mediaBlocks.isEmpty, "nested media blocks are not supported")
        guard !sub.declarations.isEmpty else { return }   // empty block → nothing to register
        mediaBlocks.append((query.condition, sub.declarations))
    }

    // Layout
    public mutating func display(_ v: Display) { _add(.display(v)) }
    public mutating func position(_ v: Position) { _add(.position(v)) }
    public mutating func top(_ v: CSSLength) { _add(.top(v)) }
    public mutating func right(_ v: CSSLength) { _add(.right(v)) }
    public mutating func bottom(_ v: CSSLength) { _add(.bottom(v)) }
    public mutating func left(_ v: CSSLength) { _add(.left(v)) }
    public mutating func width(_ v: CSSLength) { _add(.width(v)) }
    public mutating func height(_ v: CSSLength) { _add(.height(v)) }
    public mutating func minWidth(_ v: CSSLength) { _add(.minWidth(v)) }
    public mutating func minHeight(_ v: CSSLength) { _add(.minHeight(v)) }
    public mutating func maxWidth(_ v: CSSLength) { _add(.maxWidth(v)) }
    public mutating func maxHeight(_ v: CSSLength) { _add(.maxHeight(v)) }
    public mutating func margin(_ v: CSSLength) { _add(.margin(v)) }
    public mutating func margin(_ side: Side, _ v: CSSLength) { _add(.margin(side, v)) }
    public mutating func margin(vertical: CSSLength, horizontal: CSSLength) { _add(.margin(vertical: vertical, horizontal: horizontal)) }
    public mutating func padding(_ v: CSSLength) { _add(.padding(v)) }
    public mutating func padding(_ side: Side, _ v: CSSLength) { _add(.padding(side, v)) }
    public mutating func padding(vertical: CSSLength, horizontal: CSSLength) { _add(.padding(vertical: vertical, horizontal: horizontal)) }
    public mutating func gap(_ v: CSSLength) { _add(.gap(v)) }
    public mutating func overflow(_ v: Overflow) { _add(.overflow(v)) }
    public mutating func zIndex(_ v: Int) { _add(.zIndex(v)) }
    public mutating func boxSizing(_ v: BoxSizing) { _add(.boxSizing(v)) }
    // Flex / Grid
    public mutating func flexDirection(_ v: FlexDirection) { _add(.flexDirection(v)) }
    public mutating func justifyContent(_ v: JustifyContent) { _add(.justifyContent(v)) }
    public mutating func alignItems(_ v: AlignItems) { _add(.alignItems(v)) }
    public mutating func alignSelf(_ v: AlignItems) { _add(.alignSelf(v)) }
    public mutating func flexWrap(_ v: FlexWrap) { _add(.flexWrap(v)) }
    public mutating func flexGrow(_ v: Double) { _add(.flexGrow(v)) }
    public mutating func flexShrink(_ v: Double) { _add(.flexShrink(v)) }
    public mutating func flexBasis(_ v: CSSLength) { _add(.flexBasis(v)) }
    public mutating func gridTemplateColumns(_ v: String) { _add(.gridTemplateColumns(v)) }
    public mutating func gridTemplateRows(_ v: String) { _add(.gridTemplateRows(v)) }
    // Typography
    public mutating func fontSize(_ v: CSSLength) { _add(.fontSize(v)) }
    public mutating func fontWeight(_ v: FontWeight) { _add(.fontWeight(v)) }
    public mutating func fontFamily(_ v: String) { _add(.fontFamily(v)) }
    public mutating func lineHeight(_ v: Double) { _add(.lineHeight(v)) }
    public mutating func textAlign(_ v: TextAlign) { _add(.textAlign(v)) }
    public mutating func textDecoration(_ v: TextDecoration) { _add(.textDecoration(v)) }
    public mutating func letterSpacing(_ v: CSSLength) { _add(.letterSpacing(v)) }
    public mutating func color(_ v: CSSColor) { _add(.color(v)) }
    // Box
    public mutating func background(_ v: CSSColor) { _add(.background(v)) }
    public mutating func border(_ width: CSSLength, _ style: BorderStyle, _ color: CSSColor) { _add(.border(width, style, color)) }
    public mutating func borderColor(_ v: CSSColor) { _add(.borderColor(v)) }
    public mutating func borderRadius(_ v: CSSLength) { _add(.borderRadius(v)) }
    public mutating func boxShadow(_ v: String) { _add(.boxShadow(v)) }
    public mutating func opacity(_ v: Double) { _add(.opacity(v)) }
    public mutating func outline(_ v: Outline) { _add(.outline(v)) }
    // Misc
    public mutating func cursor(_ v: Cursor) { _add(.cursor(v)) }
    public mutating func transition(_ v: String) { _add(.transition(v)) }
    public mutating func listStyle(_ v: String) { _add(.listStyle(v)) }
}
