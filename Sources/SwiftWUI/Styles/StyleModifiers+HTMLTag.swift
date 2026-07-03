extension HTMLTag {
    func _style(_ d: StyleDeclaration) -> Self {
        var copy = self; copy._attributes.addStyle(d); return copy
    }

    /// String escape hatch (spec §12): property name must be a CSS ident and
    /// the value must be rule-safe; invalid input asserts in debug, no-ops in release.
    public func style(_ property: String, _ value: String) -> Self {
        guard CSSSanitize.isValidIdent(property), CSSSanitize.isSafeValue(value) else {
            assertionFailure("invalid style declaration: \(property): \(value)")
            return self
        }
        return _style(StyleDeclaration(property: property, value: value))
    }

    // Layout
    public func display(_ v: Display) -> Self { _style(.display(v)) }
    public func position(_ v: Position) -> Self { _style(.position(v)) }
    public func top(_ v: CSSLength) -> Self { _style(.top(v)) }
    public func right(_ v: CSSLength) -> Self { _style(.right(v)) }
    public func bottom(_ v: CSSLength) -> Self { _style(.bottom(v)) }
    public func left(_ v: CSSLength) -> Self { _style(.left(v)) }
    public func width(_ v: CSSLength) -> Self { _style(.width(v)) }
    public func height(_ v: CSSLength) -> Self { _style(.height(v)) }
    public func minWidth(_ v: CSSLength) -> Self { _style(.minWidth(v)) }
    public func minHeight(_ v: CSSLength) -> Self { _style(.minHeight(v)) }
    public func maxWidth(_ v: CSSLength) -> Self { _style(.maxWidth(v)) }
    public func maxHeight(_ v: CSSLength) -> Self { _style(.maxHeight(v)) }
    public func margin(_ v: CSSLength) -> Self { _style(.margin(v)) }
    public func margin(_ side: Side, _ v: CSSLength) -> Self { _style(.margin(side, v)) }
    public func margin(vertical: CSSLength, horizontal: CSSLength) -> Self { _style(.margin(vertical: vertical, horizontal: horizontal)) }
    public func padding(_ v: CSSLength) -> Self { _style(.padding(v)) }
    public func padding(_ side: Side, _ v: CSSLength) -> Self { _style(.padding(side, v)) }
    public func padding(vertical: CSSLength, horizontal: CSSLength) -> Self { _style(.padding(vertical: vertical, horizontal: horizontal)) }
    public func gap(_ v: CSSLength) -> Self { _style(.gap(v)) }
    public func overflow(_ v: Overflow) -> Self { _style(.overflow(v)) }
    public func zIndex(_ v: Int) -> Self { _style(.zIndex(v)) }
    public func boxSizing(_ v: BoxSizing) -> Self { _style(.boxSizing(v)) }
    // Flex / Grid
    public func flexDirection(_ v: FlexDirection) -> Self { _style(.flexDirection(v)) }
    public func justifyContent(_ v: JustifyContent) -> Self { _style(.justifyContent(v)) }
    public func alignItems(_ v: AlignItems) -> Self { _style(.alignItems(v)) }
    public func alignSelf(_ v: AlignItems) -> Self { _style(.alignSelf(v)) }
    public func flexWrap(_ v: FlexWrap) -> Self { _style(.flexWrap(v)) }
    public func flexGrow(_ v: Double) -> Self { _style(.flexGrow(v)) }
    public func flexShrink(_ v: Double) -> Self { _style(.flexShrink(v)) }
    public func flexBasis(_ v: CSSLength) -> Self { _style(.flexBasis(v)) }
    public func gridTemplateColumns(_ v: String) -> Self { _style(.gridTemplateColumns(v)) }
    public func gridTemplateRows(_ v: String) -> Self { _style(.gridTemplateRows(v)) }
    // Typography
    public func fontSize(_ v: CSSLength) -> Self { _style(.fontSize(v)) }
    public func fontWeight(_ v: FontWeight) -> Self { _style(.fontWeight(v)) }
    public func fontFamily(_ v: String) -> Self { _style(.fontFamily(v)) }
    public func lineHeight(_ v: Double) -> Self { _style(.lineHeight(v)) }
    public func textAlign(_ v: TextAlign) -> Self { _style(.textAlign(v)) }
    public func textDecoration(_ v: TextDecoration) -> Self { _style(.textDecoration(v)) }
    public func letterSpacing(_ v: CSSLength) -> Self { _style(.letterSpacing(v)) }
    public func color(_ v: CSSColor) -> Self { _style(.color(v)) }
    // Box
    public func background(_ v: CSSColor) -> Self { _style(.background(v)) }
    public func border(_ width: CSSLength, _ style: BorderStyle, _ color: CSSColor) -> Self { _style(.border(width, style, color)) }
    public func borderColor(_ v: CSSColor) -> Self { _style(.borderColor(v)) }
    public func borderRadius(_ v: CSSLength) -> Self { _style(.borderRadius(v)) }
    public func boxShadow(_ v: String) -> Self { _style(.boxShadow(v)) }
    public func opacity(_ v: Double) -> Self { _style(.opacity(v)) }
    public func outline(_ v: Outline) -> Self { _style(.outline(v)) }
    // Misc
    public func cursor(_ v: Cursor) -> Self { _style(.cursor(v)) }
    public func transition(_ v: String) -> Self { _style(.transition(v)) }
    public func listStyle(_ v: String) -> Self { _style(.listStyle(v)) }
}
