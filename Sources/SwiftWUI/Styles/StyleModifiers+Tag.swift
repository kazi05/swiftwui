extension Tag {
    func _styled(_ d: StyleDeclaration) -> _StyledTag<Self> {
        _StyledTag(content: self, declarations: [d], rules: [])
    }
    func _styledRule(pseudo: String?, media: String?, _ body: (inout StyleProxy) -> Void) -> _StyledTag<Self> {
        var proxy = StyleProxy(); body(&proxy)
        assert(proxy.pseudoBlocks.isEmpty, "pseudo blocks inside a rule modifier are not supported")
        return _StyledTag(content: self, declarations: [],
                          rules: [PendingStyleRule(pseudo: pseudo, media: media,
                                                   declarations: proxy.declarations)])
    }

    public func style(_ property: String, _ value: String) -> _StyledTag<Self> {
        guard CSSSanitize.isValidIdent(property), CSSSanitize.isSafeValue(value) else {
            assertionFailure("invalid style declaration: \(property): \(value)")
            return _StyledTag(content: self, declarations: [], rules: [])
        }
        return _styled(StyleDeclaration(property: property, value: value))
    }
    public func hover(_ body: (inout StyleProxy) -> Void) -> _StyledTag<Self>  { _styledRule(pseudo: ":hover", media: nil, body) }
    public func focus(_ body: (inout StyleProxy) -> Void) -> _StyledTag<Self>  { _styledRule(pseudo: ":focus", media: nil, body) }
    public func active(_ body: (inout StyleProxy) -> Void) -> _StyledTag<Self> { _styledRule(pseudo: ":active", media: nil, body) }
    public func media(_ query: MediaQuery, _ body: (inout StyleProxy) -> Void) -> _StyledTag<Self> {
        _styledRule(pseudo: nil, media: query.condition, body)
    }

    // The full §4 surface — every line delegates to a Task-3 factory:
    public func display(_ v: Display) -> _StyledTag<Self> { _styled(.display(v)) }
    public func position(_ v: Position) -> _StyledTag<Self> { _styled(.position(v)) }
    public func top(_ v: CSSLength) -> _StyledTag<Self> { _styled(.top(v)) }
    public func right(_ v: CSSLength) -> _StyledTag<Self> { _styled(.right(v)) }
    public func bottom(_ v: CSSLength) -> _StyledTag<Self> { _styled(.bottom(v)) }
    public func left(_ v: CSSLength) -> _StyledTag<Self> { _styled(.left(v)) }
    public func width(_ v: CSSLength) -> _StyledTag<Self> { _styled(.width(v)) }
    public func height(_ v: CSSLength) -> _StyledTag<Self> { _styled(.height(v)) }
    public func minWidth(_ v: CSSLength) -> _StyledTag<Self> { _styled(.minWidth(v)) }
    public func minHeight(_ v: CSSLength) -> _StyledTag<Self> { _styled(.minHeight(v)) }
    public func maxWidth(_ v: CSSLength) -> _StyledTag<Self> { _styled(.maxWidth(v)) }
    public func maxHeight(_ v: CSSLength) -> _StyledTag<Self> { _styled(.maxHeight(v)) }
    public func margin(_ v: CSSLength) -> _StyledTag<Self> { _styled(.margin(v)) }
    public func margin(_ side: Side, _ v: CSSLength) -> _StyledTag<Self> { _styled(.margin(side, v)) }
    public func margin(vertical: CSSLength, horizontal: CSSLength) -> _StyledTag<Self> { _styled(.margin(vertical: vertical, horizontal: horizontal)) }
    public func padding(_ v: CSSLength) -> _StyledTag<Self> { _styled(.padding(v)) }
    public func padding(_ side: Side, _ v: CSSLength) -> _StyledTag<Self> { _styled(.padding(side, v)) }
    public func padding(vertical: CSSLength, horizontal: CSSLength) -> _StyledTag<Self> { _styled(.padding(vertical: vertical, horizontal: horizontal)) }
    public func gap(_ v: CSSLength) -> _StyledTag<Self> { _styled(.gap(v)) }
    public func overflow(_ v: Overflow) -> _StyledTag<Self> { _styled(.overflow(v)) }
    public func zIndex(_ v: Int) -> _StyledTag<Self> { _styled(.zIndex(v)) }
    public func boxSizing(_ v: BoxSizing) -> _StyledTag<Self> { _styled(.boxSizing(v)) }
    public func flexDirection(_ v: FlexDirection) -> _StyledTag<Self> { _styled(.flexDirection(v)) }
    public func justifyContent(_ v: JustifyContent) -> _StyledTag<Self> { _styled(.justifyContent(v)) }
    public func alignItems(_ v: AlignItems) -> _StyledTag<Self> { _styled(.alignItems(v)) }
    public func alignSelf(_ v: AlignItems) -> _StyledTag<Self> { _styled(.alignSelf(v)) }
    public func flexWrap(_ v: FlexWrap) -> _StyledTag<Self> { _styled(.flexWrap(v)) }
    public func flexGrow(_ v: Double) -> _StyledTag<Self> { _styled(.flexGrow(v)) }
    public func flexShrink(_ v: Double) -> _StyledTag<Self> { _styled(.flexShrink(v)) }
    public func flexBasis(_ v: CSSLength) -> _StyledTag<Self> { _styled(.flexBasis(v)) }
    public func gridTemplateColumns(_ v: String) -> _StyledTag<Self> { _styled(.gridTemplateColumns(v)) }
    public func gridTemplateRows(_ v: String) -> _StyledTag<Self> { _styled(.gridTemplateRows(v)) }
    public func fontSize(_ v: CSSLength) -> _StyledTag<Self> { _styled(.fontSize(v)) }
    public func fontWeight(_ v: FontWeight) -> _StyledTag<Self> { _styled(.fontWeight(v)) }
    public func fontFamily(_ v: String) -> _StyledTag<Self> { _styled(.fontFamily(v)) }
    public func lineHeight(_ v: Double) -> _StyledTag<Self> { _styled(.lineHeight(v)) }
    public func textAlign(_ v: TextAlign) -> _StyledTag<Self> { _styled(.textAlign(v)) }
    public func textDecoration(_ v: TextDecoration) -> _StyledTag<Self> { _styled(.textDecoration(v)) }
    public func letterSpacing(_ v: CSSLength) -> _StyledTag<Self> { _styled(.letterSpacing(v)) }
    public func color(_ v: CSSColor) -> _StyledTag<Self> { _styled(.color(v)) }
    public func background(_ v: CSSColor) -> _StyledTag<Self> { _styled(.background(v)) }
    public func border(_ width: CSSLength, _ style: BorderStyle, _ color: CSSColor) -> _StyledTag<Self> { _styled(.border(width, style, color)) }
    public func borderColor(_ v: CSSColor) -> _StyledTag<Self> { _styled(.borderColor(v)) }
    public func borderRadius(_ v: CSSLength) -> _StyledTag<Self> { _styled(.borderRadius(v)) }
    public func boxShadow(_ v: String) -> _StyledTag<Self> { _styled(.boxShadow(v)) }
    public func opacity(_ v: Double) -> _StyledTag<Self> { _styled(.opacity(v)) }
    public func outline(_ v: Outline) -> _StyledTag<Self> { _styled(.outline(v)) }
    public func cursor(_ v: Cursor) -> _StyledTag<Self> { _styled(.cursor(v)) }
    public func transition(_ v: String) -> _StyledTag<Self> { _styled(.transition(v)) }
    public func listStyle(_ v: String) -> _StyledTag<Self> { _styled(.listStyle(v)) }
}

extension _StyledTag {
    // Collapse: consecutive style modifiers append to the SAME wrapper.
    func _styled(_ d: StyleDeclaration) -> Self {
        var copy = self; copy.declarations.append(d); return copy
    }
    func _styledRule(pseudo: String?, media: String?, _ body: (inout StyleProxy) -> Void) -> Self {
        var proxy = StyleProxy(); body(&proxy)
        var copy = self
        copy.rules.append(PendingStyleRule(pseudo: pseudo, media: media,
                                           declarations: proxy.declarations))
        return copy
    }
    public func style(_ property: String, _ value: String) -> Self {
        guard CSSSanitize.isValidIdent(property), CSSSanitize.isSafeValue(value) else {
            assertionFailure("invalid style declaration: \(property): \(value)")
            return self
        }
        return _styled(StyleDeclaration(property: property, value: value))
    }
    public func hover(_ body: (inout StyleProxy) -> Void) -> Self  { _styledRule(pseudo: ":hover", media: nil, body) }
    public func focus(_ body: (inout StyleProxy) -> Void) -> Self  { _styledRule(pseudo: ":focus", media: nil, body) }
    public func active(_ body: (inout StyleProxy) -> Void) -> Self { _styledRule(pseudo: ":active", media: nil, body) }
    public func media(_ query: MediaQuery, _ body: (inout StyleProxy) -> Void) -> Self {
        _styledRule(pseudo: nil, media: query.condition, body)
    }
    // Collapse variants of the full surface — every line appends to self:
    public func display(_ v: Display) -> Self { _styled(.display(v)) }
    public func position(_ v: Position) -> Self { _styled(.position(v)) }
    public func top(_ v: CSSLength) -> Self { _styled(.top(v)) }
    public func right(_ v: CSSLength) -> Self { _styled(.right(v)) }
    public func bottom(_ v: CSSLength) -> Self { _styled(.bottom(v)) }
    public func left(_ v: CSSLength) -> Self { _styled(.left(v)) }
    public func width(_ v: CSSLength) -> Self { _styled(.width(v)) }
    public func height(_ v: CSSLength) -> Self { _styled(.height(v)) }
    public func minWidth(_ v: CSSLength) -> Self { _styled(.minWidth(v)) }
    public func minHeight(_ v: CSSLength) -> Self { _styled(.minHeight(v)) }
    public func maxWidth(_ v: CSSLength) -> Self { _styled(.maxWidth(v)) }
    public func maxHeight(_ v: CSSLength) -> Self { _styled(.maxHeight(v)) }
    public func margin(_ v: CSSLength) -> Self { _styled(.margin(v)) }
    public func margin(_ side: Side, _ v: CSSLength) -> Self { _styled(.margin(side, v)) }
    public func margin(vertical: CSSLength, horizontal: CSSLength) -> Self { _styled(.margin(vertical: vertical, horizontal: horizontal)) }
    public func padding(_ v: CSSLength) -> Self { _styled(.padding(v)) }
    public func padding(_ side: Side, _ v: CSSLength) -> Self { _styled(.padding(side, v)) }
    public func padding(vertical: CSSLength, horizontal: CSSLength) -> Self { _styled(.padding(vertical: vertical, horizontal: horizontal)) }
    public func gap(_ v: CSSLength) -> Self { _styled(.gap(v)) }
    public func overflow(_ v: Overflow) -> Self { _styled(.overflow(v)) }
    public func zIndex(_ v: Int) -> Self { _styled(.zIndex(v)) }
    public func boxSizing(_ v: BoxSizing) -> Self { _styled(.boxSizing(v)) }
    public func flexDirection(_ v: FlexDirection) -> Self { _styled(.flexDirection(v)) }
    public func justifyContent(_ v: JustifyContent) -> Self { _styled(.justifyContent(v)) }
    public func alignItems(_ v: AlignItems) -> Self { _styled(.alignItems(v)) }
    public func alignSelf(_ v: AlignItems) -> Self { _styled(.alignSelf(v)) }
    public func flexWrap(_ v: FlexWrap) -> Self { _styled(.flexWrap(v)) }
    public func flexGrow(_ v: Double) -> Self { _styled(.flexGrow(v)) }
    public func flexShrink(_ v: Double) -> Self { _styled(.flexShrink(v)) }
    public func flexBasis(_ v: CSSLength) -> Self { _styled(.flexBasis(v)) }
    public func gridTemplateColumns(_ v: String) -> Self { _styled(.gridTemplateColumns(v)) }
    public func gridTemplateRows(_ v: String) -> Self { _styled(.gridTemplateRows(v)) }
    public func fontSize(_ v: CSSLength) -> Self { _styled(.fontSize(v)) }
    public func fontWeight(_ v: FontWeight) -> Self { _styled(.fontWeight(v)) }
    public func fontFamily(_ v: String) -> Self { _styled(.fontFamily(v)) }
    public func lineHeight(_ v: Double) -> Self { _styled(.lineHeight(v)) }
    public func textAlign(_ v: TextAlign) -> Self { _styled(.textAlign(v)) }
    public func textDecoration(_ v: TextDecoration) -> Self { _styled(.textDecoration(v)) }
    public func letterSpacing(_ v: CSSLength) -> Self { _styled(.letterSpacing(v)) }
    public func color(_ v: CSSColor) -> Self { _styled(.color(v)) }
    public func background(_ v: CSSColor) -> Self { _styled(.background(v)) }
    public func border(_ width: CSSLength, _ style: BorderStyle, _ color: CSSColor) -> Self { _styled(.border(width, style, color)) }
    public func borderColor(_ v: CSSColor) -> Self { _styled(.borderColor(v)) }
    public func borderRadius(_ v: CSSLength) -> Self { _styled(.borderRadius(v)) }
    public func boxShadow(_ v: String) -> Self { _styled(.boxShadow(v)) }
    public func opacity(_ v: Double) -> Self { _styled(.opacity(v)) }
    public func outline(_ v: Outline) -> Self { _styled(.outline(v)) }
    public func cursor(_ v: Cursor) -> Self { _styled(.cursor(v)) }
    public func transition(_ v: String) -> Self { _styled(.transition(v)) }
    public func listStyle(_ v: String) -> Self { _styled(.listStyle(v)) }
}
