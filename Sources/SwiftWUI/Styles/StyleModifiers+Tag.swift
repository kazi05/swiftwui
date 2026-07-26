public enum ContainerType: String { case inlineSize = "inline-size", size, normal }

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
    func _styledContainer(_ query: MediaQuery, name: String?,
                          _ body: (inout StyleProxy) -> Void) -> _StyledTag<Self> {
        var proxy = StyleProxy(); body(&proxy)
        let safeName = name.flatMap { CSSSanitize.isValidIdent($0) ? $0 : nil }
        let container = (safeName.map { "\($0) " } ?? "") + query.condition
        // safeName drops an invalid ident: the @container prelude is emitted raw into
        // CSS with no downstream sanitize sink, so validating-and-dropping here is the
        // injection guard (must hold in release; no assert, which would also break the
        // regression test under debug).
        return _StyledTag(content: self, declarations: [],
                          rules: [PendingStyleRule(pseudo: nil, media: nil, container: container,
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
    public func container(_ query: MediaQuery, name: String? = nil,
                          _ body: (inout StyleProxy) -> Void) -> _StyledTag<Self> {
        _styledContainer(query, name: name, body)
    }
    public func containerType(_ type: ContainerType = .inlineSize, name: String? = nil) -> _StyledTag<Self> {
        var t = _styled(StyleDeclaration(property: "container-type", value: type.rawValue))
        if let name, CSSSanitize.isValidIdent(name) {
            t = t._styled(StyleDeclaration(property: "container-name", value: name))
        } else if name != nil {
            assertionFailure("invalid container-name ident")
        }
        return t
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
    public func cssTransition(_ v: String) -> _StyledTag<Self> { _styled(.transition(v)) }
    public func listStyle(_ v: String) -> _StyledTag<Self> { _styled(.listStyle(v)) }

    public func overflowX(_ v: Overflow) -> _StyledTag<Self> { _styled(.overflowX(v)) }
    public func overflowY(_ v: Overflow) -> _StyledTag<Self> { _styled(.overflowY(v)) }
    public func objectFit(_ v: ObjectFit) -> _StyledTag<Self> { _styled(.objectFit(v)) }
    public func objectPosition(_ v: ObjectPosition) -> _StyledTag<Self> { _styled(.objectPosition(v)) }
    public func aspectRatio(_ v: AspectRatio) -> _StyledTag<Self> { _styled(.aspectRatio(v)) }
    public func aspectRatio(_ w: Double, _ h: Double) -> _StyledTag<Self> { _styled(.aspectRatio(.ratio(w, h))) }
    public func visibility(_ v: Visibility) -> _StyledTag<Self> { _styled(.visibility(v)) }
    public func whiteSpace(_ v: WhiteSpace) -> _StyledTag<Self> { _styled(.whiteSpace(v)) }
    public func textTransform(_ v: TextTransform) -> _StyledTag<Self> { _styled(.textTransform(v)) }
    public func textOverflow(_ v: TextOverflow) -> _StyledTag<Self> { _styled(.textOverflow(v)) }
    /// Bundled: appends all 5 line-clamp declarations onto one wrapper.
    public func lineClamp(_ lines: Int) -> _StyledTag<Self> {
        let decls = StyleDeclaration.lineClamp(lines)
        var t = _styled(decls[0])
        for d in decls.dropFirst() { t = t._styled(d) }
        return t
    }
    public func backgroundColor(_ v: CSSColor) -> _StyledTag<Self> { _styled(.backgroundColor(v)) }
    public func backgroundImage(_ v: CSSBackgroundImage) -> _StyledTag<Self> { _styled(.backgroundImage(v)) }
    public func backgroundRepeat(_ v: BackgroundRepeat) -> _StyledTag<Self> { _styled(.backgroundRepeat(v)) }
    public func border(_ side: Side, width: CSSLength = .px(1), style: BorderStyle = .solid, color: CSSColor = .current) -> _StyledTag<Self> { _styled(.border(side, width: width, style: style, color: color)) }
    public func borderRadius(_ v: BorderRadius) -> _StyledTag<Self> { _styled(.borderRadius(v)) }
    /// Variadic: empty function list emits nothing (empty wrapper).
    public func filter(_ fns: FilterFunction...) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.filter(fns) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }
    public func transform(_ fns: TransformFunction...) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.transform(fns) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }
    public func pointerEvents(_ v: PointerEvents) -> _StyledTag<Self> { _styled(.pointerEvents(v)) }
    public func userSelect(_ v: UserSelect) -> _StyledTag<Self> { _styled(.userSelect(v)) }

    // Structural: layout / flex / grid
    public func inlineSize(_ v: CSSLength) -> _StyledTag<Self> { _styled(.inlineSize(v)) }
    public func blockSize(_ v: CSSLength) -> _StyledTag<Self> { _styled(.blockSize(v)) }
    public func inset(_ v: CSSLength) -> _StyledTag<Self> { _styled(.inset(v)) }
    public func marginInline(_ v: CSSLength) -> _StyledTag<Self> { _styled(.marginInline(v)) }
    public func marginBlock(_ v: CSSLength) -> _StyledTag<Self> { _styled(.marginBlock(v)) }
    public func paddingInline(_ v: CSSLength) -> _StyledTag<Self> { _styled(.paddingInline(v)) }
    public func paddingBlock(_ v: CSSLength) -> _StyledTag<Self> { _styled(.paddingBlock(v)) }
    public func rowGap(_ v: CSSLength) -> _StyledTag<Self> { _styled(.rowGap(v)) }
    public func columnGap(_ v: CSSLength) -> _StyledTag<Self> { _styled(.columnGap(v)) }
    public func gap(row: CSSLength, column: CSSLength) -> _StyledTag<Self> { _styled(.gap(row: row, column: column)) }
    public func order(_ v: Int) -> _StyledTag<Self> { _styled(.order(v)) }
    public func justifyItems(_ v: JustifyItems) -> _StyledTag<Self> { _styled(.justifyItems(v)) }
    public func justifySelf(_ v: JustifySelf) -> _StyledTag<Self> { _styled(.justifySelf(v)) }
    public func alignContent(_ v: AlignContent) -> _StyledTag<Self> { _styled(.alignContent(v)) }
    public func placeContent(_ align: AlignContent, _ justify: JustifyContent) -> _StyledTag<Self> { _styled(.placeContent(align, justify)) }
    public func placeItems(_ align: AlignItems, _ justify: JustifyItems) -> _StyledTag<Self> { _styled(.placeItems(align, justify)) }
    public func gridAutoFlow(_ v: GridAutoFlow) -> _StyledTag<Self> { _styled(.gridAutoFlow(v)) }
    public func gridColumnStart(_ v: GridLine) -> _StyledTag<Self> { _styled(.gridColumnStart(v)) }
    public func gridColumnEnd(_ v: GridLine) -> _StyledTag<Self> { _styled(.gridColumnEnd(v)) }
    public func gridRowStart(_ v: GridLine) -> _StyledTag<Self> { _styled(.gridRowStart(v)) }
    public func gridRowEnd(_ v: GridLine) -> _StyledTag<Self> { _styled(.gridRowEnd(v)) }
    public func gridColumn(_ start: GridLine, _ end: GridLine? = nil) -> _StyledTag<Self> { _styled(.gridColumn(start, end)) }
    public func gridRow(_ start: GridLine, _ end: GridLine? = nil) -> _StyledTag<Self> { _styled(.gridRow(start, end)) }
    /// Assert-and-drop: unsafe value → empty wrapper (no declaration).
    public func gridTemplateAreas(_ v: String) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.gridTemplateAreas(v) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }
    /// Assert-and-drop: invalid ident → empty wrapper (no declaration).
    public func gridArea(_ name: String) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.gridArea(name) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }

    // Typography + background/border
    public func fontStyle(_ v: FontStyle) -> _StyledTag<Self> { _styled(.fontStyle(v)) }
    public func textDecorationLine(_ v: TextDecorationLine) -> _StyledTag<Self> { _styled(.textDecorationLine(v)) }
    public func textDecorationColor(_ v: CSSColor) -> _StyledTag<Self> { _styled(.textDecorationColor(v)) }
    public func textDecorationStyle(_ v: TextDecorationStyle) -> _StyledTag<Self> { _styled(.textDecorationStyle(v)) }
    public func textDecorationThickness(_ v: CSSLength) -> _StyledTag<Self> { _styled(.textDecorationThickness(v)) }
    public func textIndent(_ v: CSSLength) -> _StyledTag<Self> { _styled(.textIndent(v)) }
    /// Variadic: empty shadow list emits nothing (empty wrapper).
    public func textShadow(_ shadows: Shadow...) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.textShadow(shadows) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }
    public func wordBreak(_ v: WordBreak) -> _StyledTag<Self> { _styled(.wordBreak(v)) }
    public func overflowWrap(_ v: OverflowWrap) -> _StyledTag<Self> { _styled(.overflowWrap(v)) }
    public func verticalAlign(_ v: VerticalAlign) -> _StyledTag<Self> { _styled(.verticalAlign(v)) }
    public func lineHeight(_ v: CSSLength) -> _StyledTag<Self> { _styled(.lineHeight(v)) }
    public func listStyleType(_ v: ListStyleType) -> _StyledTag<Self> { _styled(.listStyleType(v)) }
    public func textWrap(_ v: TextWrap) -> _StyledTag<Self> { _styled(.textWrap(v)) }
    public func fontVariantNumeric(_ v: FontVariantNumeric) -> _StyledTag<Self> { _styled(.fontVariantNumeric(v)) }
    /// Bundled: appends both the prefixed and unprefixed background-clip declarations.
    public func backgroundClip(_ v: BackgroundClip) -> _StyledTag<Self> {
        let decls = StyleDeclaration.backgroundClip(v)
        var t = _styled(decls[0])
        for d in decls.dropFirst() { t = t._styled(d) }
        return t
    }
    public func borderWidth(_ v: CSSLength) -> _StyledTag<Self> { _styled(.borderWidth(v)) }
    public func borderWidth(_ side: Side, _ v: CSSLength) -> _StyledTag<Self> { _styled(.borderWidth(side, v)) }
    public func borderStyle(_ v: BorderStyle) -> _StyledTag<Self> { _styled(.borderStyle(v)) }
    public func borderStyle(_ side: Side, _ v: BorderStyle) -> _StyledTag<Self> { _styled(.borderStyle(side, v)) }
    public func borderColor(_ side: Side, _ v: CSSColor) -> _StyledTag<Self> { _styled(.borderColor(side, v)) }
    public func outlineOffset(_ v: CSSLength) -> _StyledTag<Self> { _styled(.outlineOffset(v)) }
    public func outlineWidth(_ v: CSSLength) -> _StyledTag<Self> { _styled(.outlineWidth(v)) }
    public func outlineStyle(_ v: OutlineStyle) -> _StyledTag<Self> { _styled(.outlineStyle(v)) }
    /// Variadic: empty shadow list emits nothing (empty wrapper).
    public func boxShadow(_ shadows: Shadow...) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.boxShadow(shadows) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }
    public func mixBlendMode(_ v: BlendMode) -> _StyledTag<Self> { _styled(.mixBlendMode(v)) }

    // Effects/motion + interactivity/misc
    /// Variadic: empty function list emits nothing (empty wrapper).
    public func backdropFilter(_ fns: FilterFunction...) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.backdropFilter(fns) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }
    public func clipPath(_ v: ClipPath) -> _StyledTag<Self> { _styled(.clipPath(v)) }
    /// Typed transition longhand. `cssTransition(_:)` remains the raw-string escape.
    public func transition(property: String, duration: CSSDuration, timingFunction: TimingFunction = .ease, delay: CSSDuration = .ms(0)) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.transition(property: property, duration: duration, timingFunction: timingFunction, delay: delay) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }
    public func transitionDuration(_ v: CSSDuration) -> _StyledTag<Self> { _styled(.transitionDuration(v)) }
    public func transitionTimingFunction(_ v: TimingFunction) -> _StyledTag<Self> { _styled(.transitionTimingFunction(v)) }
    public func touchAction(_ v: TouchAction) -> _StyledTag<Self> { _styled(.touchAction(v)) }
    public func scrollBehavior(_ v: ScrollBehavior) -> _StyledTag<Self> { _styled(.scrollBehavior(v)) }
    public func scrollSnapType(_ v: ScrollSnapType) -> _StyledTag<Self> { _styled(.scrollSnapType(v)) }
    public func scrollSnapAlign(_ v: ScrollSnapAlign) -> _StyledTag<Self> { _styled(.scrollSnapAlign(v)) }
    public func scrollPadding(_ v: CSSLength) -> _StyledTag<Self> { _styled(.scrollPadding(v)) }
    public func scrollPadding(_ side: Side, _ v: CSSLength) -> _StyledTag<Self> { _styled(.scrollPadding(side, v)) }
    public func overscrollBehavior(_ v: OverscrollBehavior) -> _StyledTag<Self> { _styled(.overscrollBehavior(v)) }
    public func overscrollBehaviorX(_ v: OverscrollBehavior) -> _StyledTag<Self> { _styled(.overscrollBehaviorX(v)) }
    public func overscrollBehaviorY(_ v: OverscrollBehavior) -> _StyledTag<Self> { _styled(.overscrollBehaviorY(v)) }
    public func resize(_ v: Resize) -> _StyledTag<Self> { _styled(.resize(v)) }
    /// Bundled: appends both the prefixed and unprefixed appearance declarations.
    public func appearance(_ v: Appearance) -> _StyledTag<Self> {
        let decls = StyleDeclaration.appearance(v)
        var t = _styled(decls[0])
        for d in decls.dropFirst() { t = t._styled(d) }
        return t
    }
    public func accentColor(_ v: CSSColor) -> _StyledTag<Self> { _styled(.accentColor(v)) }
    public func listStylePosition(_ v: ListStylePosition) -> _StyledTag<Self> { _styled(.listStylePosition(v)) }
    public func borderCollapse(_ v: BorderCollapse) -> _StyledTag<Self> { _styled(.borderCollapse(v)) }
    public func tableLayout(_ v: TableLayout) -> _StyledTag<Self> { _styled(.tableLayout(v)) }
    public func colorSchemeHint(_ v: ColorSchemeHint) -> _StyledTag<Self> { _styled(.colorSchemeHint(v)) }
    public func breakInside(_ v: BreakInside) -> _StyledTag<Self> { _styled(.breakInside(v)) }
    public func breakBefore(_ v: BreakBetween) -> _StyledTag<Self> { _styled(.breakBefore(v)) }
    public func breakAfter(_ v: BreakBetween) -> _StyledTag<Self> { _styled(.breakAfter(v)) }

    // Logical box + font sub-props + background/border tail
    public func marginInlineStart(_ v: CSSLength) -> _StyledTag<Self> { _styled(.marginInlineStart(v)) }
    public func marginInlineEnd(_ v: CSSLength) -> _StyledTag<Self> { _styled(.marginInlineEnd(v)) }
    public func marginBlockStart(_ v: CSSLength) -> _StyledTag<Self> { _styled(.marginBlockStart(v)) }
    public func marginBlockEnd(_ v: CSSLength) -> _StyledTag<Self> { _styled(.marginBlockEnd(v)) }
    public func paddingInlineStart(_ v: CSSLength) -> _StyledTag<Self> { _styled(.paddingInlineStart(v)) }
    public func paddingInlineEnd(_ v: CSSLength) -> _StyledTag<Self> { _styled(.paddingInlineEnd(v)) }
    public func paddingBlockStart(_ v: CSSLength) -> _StyledTag<Self> { _styled(.paddingBlockStart(v)) }
    public func paddingBlockEnd(_ v: CSSLength) -> _StyledTag<Self> { _styled(.paddingBlockEnd(v)) }
    public func insetInlineStart(_ v: CSSLength) -> _StyledTag<Self> { _styled(.insetInlineStart(v)) }
    public func insetInlineEnd(_ v: CSSLength) -> _StyledTag<Self> { _styled(.insetInlineEnd(v)) }
    public func insetBlockStart(_ v: CSSLength) -> _StyledTag<Self> { _styled(.insetBlockStart(v)) }
    public func insetBlockEnd(_ v: CSSLength) -> _StyledTag<Self> { _styled(.insetBlockEnd(v)) }
    public func minInlineSize(_ v: CSSLength) -> _StyledTag<Self> { _styled(.minInlineSize(v)) }
    public func maxInlineSize(_ v: CSSLength) -> _StyledTag<Self> { _styled(.maxInlineSize(v)) }
    public func minBlockSize(_ v: CSSLength) -> _StyledTag<Self> { _styled(.minBlockSize(v)) }
    public func maxBlockSize(_ v: CSSLength) -> _StyledTag<Self> { _styled(.maxBlockSize(v)) }
    public func float(_ v: CSSFloat) -> _StyledTag<Self> { _styled(.float(v)) }
    public func clear(_ v: Clear) -> _StyledTag<Self> { _styled(.clear(v)) }
    public func isolation(_ v: Isolation) -> _StyledTag<Self> { _styled(.isolation(v)) }
    public func fontVariant(_ v: FontVariant) -> _StyledTag<Self> { _styled(.fontVariant(v)) }
    public func fontStretch(_ v: FontStretch) -> _StyledTag<Self> { _styled(.fontStretch(v)) }
    public func fontOpticalSizing(_ v: FontOpticalSizing) -> _StyledTag<Self> { _styled(.fontOpticalSizing(v)) }
    /// Bundled: appends the prefixed declaration plus `font-smooth` for `auto`/`none`.
    public func fontSmoothing(_ v: FontSmoothing) -> _StyledTag<Self> {
        let decls = StyleDeclaration.fontSmoothing(v)
        var t = _styled(decls[0])
        for d in decls.dropFirst() { t = t._styled(d) }
        return t
    }
    public func textAlignLast(_ v: TextAlignLast) -> _StyledTag<Self> { _styled(.textAlignLast(v)) }
    public func textUnderlineOffset(_ v: CSSLength) -> _StyledTag<Self> { _styled(.textUnderlineOffset(v)) }
    public func wordSpacing(_ v: CSSLength) -> _StyledTag<Self> { _styled(.wordSpacing(v)) }
    public func hyphens(_ v: Hyphens) -> _StyledTag<Self> { _styled(.hyphens(v)) }
    public func direction(_ v: Direction) -> _StyledTag<Self> { _styled(.direction(v)) }
    public func caretColor(_ v: CaretColor) -> _StyledTag<Self> { _styled(.caretColor(v)) }
    public func textStroke(_ v: TextStroke) -> _StyledTag<Self> { _styled(.textStroke(v)) }
    public func backgroundAttachment(_ v: BackgroundAttachment) -> _StyledTag<Self> { _styled(.backgroundAttachment(v)) }
    public func backgroundOrigin(_ v: BackgroundOrigin) -> _StyledTag<Self> { _styled(.backgroundOrigin(v)) }
    public func backgroundBlendMode(_ v: BlendMode) -> _StyledTag<Self> { _styled(.backgroundBlendMode(v)) }
    public func backgroundPosition(_ v: BackgroundPosition) -> _StyledTag<Self> { _styled(.backgroundPosition(v)) }
    public func backgroundSize(_ v: BackgroundSize) -> _StyledTag<Self> { _styled(.backgroundSize(v)) }
    public func outlineColor(_ v: CSSColor) -> _StyledTag<Self> { _styled(.outlineColor(v)) }
    public func borderSpacing(_ h: CSSLength, _ v: CSSLength? = nil) -> _StyledTag<Self> { _styled(.borderSpacing(h, v)) }

    // Motion 3D + scroll/flex tail + multicol + SVG + counters
    public func transformStyle(_ v: TransformStyle) -> _StyledTag<Self> { _styled(.transformStyle(v)) }
    public func perspective(_ v: CSSLength) -> _StyledTag<Self> { _styled(.perspective(v)) }
    public func backfaceVisibility(_ v: BackfaceVisibility) -> _StyledTag<Self> { _styled(.backfaceVisibility(v)) }
    /// Variadic: empty hint list emits nothing (empty wrapper).
    public func willChange(_ hints: WillChange...) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.willChange(hints) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }
    /// Attaches a CSS `@keyframes` animation. Distinct from the WAAPI engine's
    /// `animation(_:value:)` (Animation/AnimationModifier.swift): that one
    /// interpolates between two states when a value changes, this one drives a
    /// declarative CSS loop the engine does not cover.
    ///
    /// Gated on `@media (prefers-reduced-motion: no-preference)` by default —
    /// pass `respectsReducedMotion: false` for an animation that carries
    /// information rather than decoration.
    ///
    /// Do not animate the same CSS property with both this and state-driven
    /// styles — a running CSS animation outranks inline declarations, so the
    /// WAAPI engine's value never takes effect while this animation is live.
    ///
    /// With `fillMode: .forwards`, don't rely on the animation to reach a
    /// visible end state; the reduced-motion gate suppresses the rule
    /// entirely.
    ///
    /// The animation lands in a generated class, so an inline
    /// `.style("animation", …)` on the same element wins over it.
    public func animation(_ keyframes: Keyframes, duration: CSSDuration,
                          timingFunction: TimingFunction = .ease,
                          delay: CSSDuration = .ms(0),
                          iterations: AnimationIterations = .count(1),
                          direction: AnimationDirection = .normal,
                          fillMode: AnimationFillMode = .none,
                          respectsReducedMotion: Bool = true) -> _StyledTag<Self> {
        guard let rule = _animationRule(keyframes, duration: duration,
                                        timingFunction: timingFunction, delay: delay,
                                        iterations: iterations, direction: direction,
                                        fillMode: fillMode,
                                        respectsReducedMotion: respectsReducedMotion) else {
            return _StyledTag(content: self, declarations: [], rules: [])
        }
        return _StyledTag(content: self, declarations: [], rules: [rule])
    }
    public func transitionDelay(_ v: CSSDuration) -> _StyledTag<Self> { _styled(.transitionDelay(v)) }
    public func contentVisibility(_ v: ContentVisibility) -> _StyledTag<Self> { _styled(.contentVisibility(v)) }
    public func containIntrinsicSize(_ v: CSSLength) -> _StyledTag<Self> { _styled(.containIntrinsicSize(v)) }
    public func containIntrinsicSize(_ w: CSSLength, _ h: CSSLength) -> _StyledTag<Self> { _styled(.containIntrinsicSize(w, h)) }
    public func scrollSnapStop(_ v: ScrollSnapStop) -> _StyledTag<Self> { _styled(.scrollSnapStop(v)) }
    public func scrollMargin(_ v: CSSLength) -> _StyledTag<Self> { _styled(.scrollMargin(v)) }
    public func scrollMargin(_ side: Side, _ v: CSSLength) -> _StyledTag<Self> { _styled(.scrollMargin(side, v)) }
    public func placeSelf(_ align: AlignItems, _ justify: JustifySelf) -> _StyledTag<Self> { _styled(.placeSelf(align, justify)) }
    public func flex(_ v: FlexShorthand) -> _StyledTag<Self> { _styled(.flex(v)) }
    public func flex(_ grow: Double) -> _StyledTag<Self> { _styled(.flex(grow)) }
    public func flexFlow(_ direction: FlexDirection, _ wrap: FlexWrap) -> _StyledTag<Self> { _styled(.flexFlow(direction, wrap)) }
    /// Unsafe value → empty wrapper (no declaration); asserts in debug.
    public func content(_ v: String) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.content(v) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }
    public func columnCount(_ v: Int) -> _StyledTag<Self> { _styled(.columnCount(v)) }
    public func columnWidth(_ v: CSSLength) -> _StyledTag<Self> { _styled(.columnWidth(v)) }
    public func scrollbarWidth(_ v: ScrollbarWidth) -> _StyledTag<Self> { _styled(.scrollbarWidth(v)) }
    public func scrollbarColor(_ thumb: CSSColor, _ track: CSSColor) -> _StyledTag<Self> { _styled(.scrollbarColor(thumb, track)) }
    public func tapHighlightColor(_ v: CSSColor) -> _StyledTag<Self> { _styled(.tapHighlightColor(v)) }
    public func fill(_ v: CSSColor) -> _StyledTag<Self> { _styled(.fill(v)) }
    public func stroke(_ v: CSSColor) -> _StyledTag<Self> { _styled(.stroke(v)) }
    public func strokeWidth(_ v: CSSLength) -> _StyledTag<Self> { _styled(.strokeWidth(v)) }
    /// Variadic: empty action list emits nothing (empty wrapper).
    public func counterReset(_ actions: CounterAction...) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.counterReset(actions) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }
    public func counterIncrement(_ actions: CounterAction...) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.counterIncrement(actions) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }
    public func counterSet(_ actions: CounterAction...) -> _StyledTag<Self> {
        guard let d = StyleDeclaration.counterSet(actions) else { return _StyledTag(content: self, declarations: [], rules: []) }
        return _styled(d)
    }

    /// Desugars a `Responsive` value into a base stylesheet rule + non-overlapping
    /// `@media` override rules. Note: do NOT also apply a plain (inline) modifier for
    /// the same property on the same element — inline styles out-specify these
    /// class-based rules and would defeat every breakpoint override.
    func _responsive<V>(_ r: Responsive<V>,
                        _ apply: (inout StyleProxy, V) -> Void) -> _StyledTag<Self> {
        var base = StyleProxy(); apply(&base, r.base)
        var rules: [PendingStyleRule] = []
        // Base goes through the same anonymous-rule path (media: nil → no @media
        // wrapper) rather than the wrapper's inline `declarations`, so it lands in
        // the stylesheet next to its overrides instead of an inline style attribute.
        if !base.declarations.isEmpty {
            rules.append(PendingStyleRule(pseudo: nil, media: nil, declarations: base.declarations))
        }
        for (i, pair) in r.overrides.enumerated() {
            var p = StyleProxy(); apply(&p, pair.1)
            guard !p.declarations.isEmpty else { continue }
            let cond: MediaQuery = (i + 1 < r.overrides.count)
                ? .and(.up(pair.0), .maxWidth(.px(r.overrides[i + 1].0.minWidthPx - 0.02)))
                : .up(pair.0)
            rules.append(PendingStyleRule(pseudo: nil, media: cond.condition, declarations: p.declarations))
        }
        return _StyledTag(content: self, declarations: [], rules: rules)
    }
    // ponytail: overload set bounded to layout/typography props that actually vary by width; extend per demand.
    public func padding(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.padding($1) } }
    public func margin(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.margin($1) } }
    public func width(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.width($1) } }
    public func height(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.height($1) } }
    public func minWidth(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.minWidth($1) } }
    public func maxWidth(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.maxWidth($1) } }
    public func fontSize(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.fontSize($1) } }
    public func gap(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.gap($1) } }
    public func display(_ r: Responsive<Display>) -> _StyledTag<Self> { _responsive(r) { $0.display($1) } }
    public func flexDirection(_ r: Responsive<FlexDirection>) -> _StyledTag<Self> { _responsive(r) { $0.flexDirection($1) } }
    public func textAlign(_ r: Responsive<TextAlign>) -> _StyledTag<Self> { _responsive(r) { $0.textAlign($1) } }
    public func gridTemplateColumns(_ r: Responsive<String>) -> _StyledTag<Self> { _responsive(r) { $0.gridTemplateColumns($1) } }
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
    func _styledContainer(_ query: MediaQuery, name: String?,
                          _ body: (inout StyleProxy) -> Void) -> Self {
        var proxy = StyleProxy(); body(&proxy)
        let safeName = name.flatMap { CSSSanitize.isValidIdent($0) ? $0 : nil }
        let container = (safeName.map { "\($0) " } ?? "") + query.condition
        // safeName drops an invalid ident: the @container prelude is emitted raw into
        // CSS with no downstream sanitize sink, so validating-and-dropping here is the
        // injection guard (must hold in release; no assert, which would also break the
        // regression test under debug).
        var copy = self
        copy.rules.append(PendingStyleRule(pseudo: nil, media: nil, container: container,
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
    public func container(_ query: MediaQuery, name: String? = nil,
                          _ body: (inout StyleProxy) -> Void) -> Self {
        _styledContainer(query, name: name, body)
    }
    public func containerType(_ type: ContainerType = .inlineSize, name: String? = nil) -> Self {
        var t = _styled(StyleDeclaration(property: "container-type", value: type.rawValue))
        if let name, CSSSanitize.isValidIdent(name) {
            t = t._styled(StyleDeclaration(property: "container-name", value: name))
        } else if name != nil {
            assertionFailure("invalid container-name ident")
        }
        return t
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
    public func cssTransition(_ v: String) -> Self { _styled(.transition(v)) }
    public func listStyle(_ v: String) -> Self { _styled(.listStyle(v)) }

    // Collapse variants
    public func overflowX(_ v: Overflow) -> Self { _styled(.overflowX(v)) }
    public func overflowY(_ v: Overflow) -> Self { _styled(.overflowY(v)) }
    public func objectFit(_ v: ObjectFit) -> Self { _styled(.objectFit(v)) }
    public func objectPosition(_ v: ObjectPosition) -> Self { _styled(.objectPosition(v)) }
    public func aspectRatio(_ v: AspectRatio) -> Self { _styled(.aspectRatio(v)) }
    public func aspectRatio(_ w: Double, _ h: Double) -> Self { _styled(.aspectRatio(.ratio(w, h))) }
    public func visibility(_ v: Visibility) -> Self { _styled(.visibility(v)) }
    public func whiteSpace(_ v: WhiteSpace) -> Self { _styled(.whiteSpace(v)) }
    public func textTransform(_ v: TextTransform) -> Self { _styled(.textTransform(v)) }
    public func textOverflow(_ v: TextOverflow) -> Self { _styled(.textOverflow(v)) }
    public func lineClamp(_ lines: Int) -> Self {
        var copy = self
        for d in StyleDeclaration.lineClamp(lines) { copy = copy._styled(d) }
        return copy
    }
    public func backgroundColor(_ v: CSSColor) -> Self { _styled(.backgroundColor(v)) }
    public func backgroundImage(_ v: CSSBackgroundImage) -> Self { _styled(.backgroundImage(v)) }
    public func backgroundRepeat(_ v: BackgroundRepeat) -> Self { _styled(.backgroundRepeat(v)) }
    public func border(_ side: Side, width: CSSLength = .px(1), style: BorderStyle = .solid, color: CSSColor = .current) -> Self { _styled(.border(side, width: width, style: style, color: color)) }
    public func borderRadius(_ v: BorderRadius) -> Self { _styled(.borderRadius(v)) }
    public func filter(_ fns: FilterFunction...) -> Self {
        guard let d = StyleDeclaration.filter(fns) else { return self }
        return _styled(d)
    }
    public func transform(_ fns: TransformFunction...) -> Self {
        guard let d = StyleDeclaration.transform(fns) else { return self }
        return _styled(d)
    }
    public func pointerEvents(_ v: PointerEvents) -> Self { _styled(.pointerEvents(v)) }
    public func userSelect(_ v: UserSelect) -> Self { _styled(.userSelect(v)) }

    // Collapse variants: structural (layout / flex / grid)
    public func inlineSize(_ v: CSSLength) -> Self { _styled(.inlineSize(v)) }
    public func blockSize(_ v: CSSLength) -> Self { _styled(.blockSize(v)) }
    public func inset(_ v: CSSLength) -> Self { _styled(.inset(v)) }
    public func marginInline(_ v: CSSLength) -> Self { _styled(.marginInline(v)) }
    public func marginBlock(_ v: CSSLength) -> Self { _styled(.marginBlock(v)) }
    public func paddingInline(_ v: CSSLength) -> Self { _styled(.paddingInline(v)) }
    public func paddingBlock(_ v: CSSLength) -> Self { _styled(.paddingBlock(v)) }
    public func rowGap(_ v: CSSLength) -> Self { _styled(.rowGap(v)) }
    public func columnGap(_ v: CSSLength) -> Self { _styled(.columnGap(v)) }
    public func gap(row: CSSLength, column: CSSLength) -> Self { _styled(.gap(row: row, column: column)) }
    public func order(_ v: Int) -> Self { _styled(.order(v)) }
    public func justifyItems(_ v: JustifyItems) -> Self { _styled(.justifyItems(v)) }
    public func justifySelf(_ v: JustifySelf) -> Self { _styled(.justifySelf(v)) }
    public func alignContent(_ v: AlignContent) -> Self { _styled(.alignContent(v)) }
    public func placeContent(_ align: AlignContent, _ justify: JustifyContent) -> Self { _styled(.placeContent(align, justify)) }
    public func placeItems(_ align: AlignItems, _ justify: JustifyItems) -> Self { _styled(.placeItems(align, justify)) }
    public func gridAutoFlow(_ v: GridAutoFlow) -> Self { _styled(.gridAutoFlow(v)) }
    public func gridColumnStart(_ v: GridLine) -> Self { _styled(.gridColumnStart(v)) }
    public func gridColumnEnd(_ v: GridLine) -> Self { _styled(.gridColumnEnd(v)) }
    public func gridRowStart(_ v: GridLine) -> Self { _styled(.gridRowStart(v)) }
    public func gridRowEnd(_ v: GridLine) -> Self { _styled(.gridRowEnd(v)) }
    public func gridColumn(_ start: GridLine, _ end: GridLine? = nil) -> Self { _styled(.gridColumn(start, end)) }
    public func gridRow(_ start: GridLine, _ end: GridLine? = nil) -> Self { _styled(.gridRow(start, end)) }
    public func gridTemplateAreas(_ v: String) -> Self {
        guard let d = StyleDeclaration.gridTemplateAreas(v) else { return self }
        return _styled(d)
    }
    public func gridArea(_ name: String) -> Self {
        guard let d = StyleDeclaration.gridArea(name) else { return self }
        return _styled(d)
    }

    // Collapse variants: typography + background/border
    public func fontStyle(_ v: FontStyle) -> Self { _styled(.fontStyle(v)) }
    public func textDecorationLine(_ v: TextDecorationLine) -> Self { _styled(.textDecorationLine(v)) }
    public func textDecorationColor(_ v: CSSColor) -> Self { _styled(.textDecorationColor(v)) }
    public func textDecorationStyle(_ v: TextDecorationStyle) -> Self { _styled(.textDecorationStyle(v)) }
    public func textDecorationThickness(_ v: CSSLength) -> Self { _styled(.textDecorationThickness(v)) }
    public func textIndent(_ v: CSSLength) -> Self { _styled(.textIndent(v)) }
    public func textShadow(_ shadows: Shadow...) -> Self {
        guard let d = StyleDeclaration.textShadow(shadows) else { return self }
        return _styled(d)
    }
    public func wordBreak(_ v: WordBreak) -> Self { _styled(.wordBreak(v)) }
    public func overflowWrap(_ v: OverflowWrap) -> Self { _styled(.overflowWrap(v)) }
    public func verticalAlign(_ v: VerticalAlign) -> Self { _styled(.verticalAlign(v)) }
    public func lineHeight(_ v: CSSLength) -> Self { _styled(.lineHeight(v)) }
    public func listStyleType(_ v: ListStyleType) -> Self { _styled(.listStyleType(v)) }
    public func textWrap(_ v: TextWrap) -> Self { _styled(.textWrap(v)) }
    public func fontVariantNumeric(_ v: FontVariantNumeric) -> Self { _styled(.fontVariantNumeric(v)) }
    public func backgroundClip(_ v: BackgroundClip) -> Self {
        var copy = self
        for d in StyleDeclaration.backgroundClip(v) { copy = copy._styled(d) }
        return copy
    }
    public func borderWidth(_ v: CSSLength) -> Self { _styled(.borderWidth(v)) }
    public func borderWidth(_ side: Side, _ v: CSSLength) -> Self { _styled(.borderWidth(side, v)) }
    public func borderStyle(_ v: BorderStyle) -> Self { _styled(.borderStyle(v)) }
    public func borderStyle(_ side: Side, _ v: BorderStyle) -> Self { _styled(.borderStyle(side, v)) }
    public func borderColor(_ side: Side, _ v: CSSColor) -> Self { _styled(.borderColor(side, v)) }
    public func outlineOffset(_ v: CSSLength) -> Self { _styled(.outlineOffset(v)) }
    public func outlineWidth(_ v: CSSLength) -> Self { _styled(.outlineWidth(v)) }
    public func outlineStyle(_ v: OutlineStyle) -> Self { _styled(.outlineStyle(v)) }
    public func boxShadow(_ shadows: Shadow...) -> Self {
        guard let d = StyleDeclaration.boxShadow(shadows) else { return self }
        return _styled(d)
    }
    public func mixBlendMode(_ v: BlendMode) -> Self { _styled(.mixBlendMode(v)) }

    // Effects/motion + interactivity/misc collapse variants
    public func backdropFilter(_ fns: FilterFunction...) -> Self {
        guard let d = StyleDeclaration.backdropFilter(fns) else { return self }
        return _styled(d)
    }
    public func clipPath(_ v: ClipPath) -> Self { _styled(.clipPath(v)) }
    public func transition(property: String, duration: CSSDuration, timingFunction: TimingFunction = .ease, delay: CSSDuration = .ms(0)) -> Self {
        guard let d = StyleDeclaration.transition(property: property, duration: duration, timingFunction: timingFunction, delay: delay) else { return self }
        return _styled(d)
    }
    public func transitionDuration(_ v: CSSDuration) -> Self { _styled(.transitionDuration(v)) }
    public func transitionTimingFunction(_ v: TimingFunction) -> Self { _styled(.transitionTimingFunction(v)) }
    public func touchAction(_ v: TouchAction) -> Self { _styled(.touchAction(v)) }
    public func scrollBehavior(_ v: ScrollBehavior) -> Self { _styled(.scrollBehavior(v)) }
    public func scrollSnapType(_ v: ScrollSnapType) -> Self { _styled(.scrollSnapType(v)) }
    public func scrollSnapAlign(_ v: ScrollSnapAlign) -> Self { _styled(.scrollSnapAlign(v)) }
    public func scrollPadding(_ v: CSSLength) -> Self { _styled(.scrollPadding(v)) }
    public func scrollPadding(_ side: Side, _ v: CSSLength) -> Self { _styled(.scrollPadding(side, v)) }
    public func overscrollBehavior(_ v: OverscrollBehavior) -> Self { _styled(.overscrollBehavior(v)) }
    public func overscrollBehaviorX(_ v: OverscrollBehavior) -> Self { _styled(.overscrollBehaviorX(v)) }
    public func overscrollBehaviorY(_ v: OverscrollBehavior) -> Self { _styled(.overscrollBehaviorY(v)) }
    public func resize(_ v: Resize) -> Self { _styled(.resize(v)) }
    public func appearance(_ v: Appearance) -> Self {
        var copy = self
        for d in StyleDeclaration.appearance(v) { copy = copy._styled(d) }
        return copy
    }
    public func accentColor(_ v: CSSColor) -> Self { _styled(.accentColor(v)) }
    public func listStylePosition(_ v: ListStylePosition) -> Self { _styled(.listStylePosition(v)) }
    public func borderCollapse(_ v: BorderCollapse) -> Self { _styled(.borderCollapse(v)) }
    public func tableLayout(_ v: TableLayout) -> Self { _styled(.tableLayout(v)) }
    public func colorSchemeHint(_ v: ColorSchemeHint) -> Self { _styled(.colorSchemeHint(v)) }
    public func breakInside(_ v: BreakInside) -> Self { _styled(.breakInside(v)) }
    public func breakBefore(_ v: BreakBetween) -> Self { _styled(.breakBefore(v)) }
    public func breakAfter(_ v: BreakBetween) -> Self { _styled(.breakAfter(v)) }

    // Logical box + font sub-props + background/border tail collapse variants
    public func marginInlineStart(_ v: CSSLength) -> Self { _styled(.marginInlineStart(v)) }
    public func marginInlineEnd(_ v: CSSLength) -> Self { _styled(.marginInlineEnd(v)) }
    public func marginBlockStart(_ v: CSSLength) -> Self { _styled(.marginBlockStart(v)) }
    public func marginBlockEnd(_ v: CSSLength) -> Self { _styled(.marginBlockEnd(v)) }
    public func paddingInlineStart(_ v: CSSLength) -> Self { _styled(.paddingInlineStart(v)) }
    public func paddingInlineEnd(_ v: CSSLength) -> Self { _styled(.paddingInlineEnd(v)) }
    public func paddingBlockStart(_ v: CSSLength) -> Self { _styled(.paddingBlockStart(v)) }
    public func paddingBlockEnd(_ v: CSSLength) -> Self { _styled(.paddingBlockEnd(v)) }
    public func insetInlineStart(_ v: CSSLength) -> Self { _styled(.insetInlineStart(v)) }
    public func insetInlineEnd(_ v: CSSLength) -> Self { _styled(.insetInlineEnd(v)) }
    public func insetBlockStart(_ v: CSSLength) -> Self { _styled(.insetBlockStart(v)) }
    public func insetBlockEnd(_ v: CSSLength) -> Self { _styled(.insetBlockEnd(v)) }
    public func minInlineSize(_ v: CSSLength) -> Self { _styled(.minInlineSize(v)) }
    public func maxInlineSize(_ v: CSSLength) -> Self { _styled(.maxInlineSize(v)) }
    public func minBlockSize(_ v: CSSLength) -> Self { _styled(.minBlockSize(v)) }
    public func maxBlockSize(_ v: CSSLength) -> Self { _styled(.maxBlockSize(v)) }
    public func float(_ v: CSSFloat) -> Self { _styled(.float(v)) }
    public func clear(_ v: Clear) -> Self { _styled(.clear(v)) }
    public func isolation(_ v: Isolation) -> Self { _styled(.isolation(v)) }
    public func fontVariant(_ v: FontVariant) -> Self { _styled(.fontVariant(v)) }
    public func fontStretch(_ v: FontStretch) -> Self { _styled(.fontStretch(v)) }
    public func fontOpticalSizing(_ v: FontOpticalSizing) -> Self { _styled(.fontOpticalSizing(v)) }
    public func fontSmoothing(_ v: FontSmoothing) -> Self {
        var copy = self
        for d in StyleDeclaration.fontSmoothing(v) { copy = copy._styled(d) }
        return copy
    }
    public func textAlignLast(_ v: TextAlignLast) -> Self { _styled(.textAlignLast(v)) }
    public func textUnderlineOffset(_ v: CSSLength) -> Self { _styled(.textUnderlineOffset(v)) }
    public func wordSpacing(_ v: CSSLength) -> Self { _styled(.wordSpacing(v)) }
    public func hyphens(_ v: Hyphens) -> Self { _styled(.hyphens(v)) }
    public func direction(_ v: Direction) -> Self { _styled(.direction(v)) }
    public func caretColor(_ v: CaretColor) -> Self { _styled(.caretColor(v)) }
    public func textStroke(_ v: TextStroke) -> Self { _styled(.textStroke(v)) }
    public func backgroundAttachment(_ v: BackgroundAttachment) -> Self { _styled(.backgroundAttachment(v)) }
    public func backgroundOrigin(_ v: BackgroundOrigin) -> Self { _styled(.backgroundOrigin(v)) }
    public func backgroundBlendMode(_ v: BlendMode) -> Self { _styled(.backgroundBlendMode(v)) }
    public func backgroundPosition(_ v: BackgroundPosition) -> Self { _styled(.backgroundPosition(v)) }
    public func backgroundSize(_ v: BackgroundSize) -> Self { _styled(.backgroundSize(v)) }
    public func outlineColor(_ v: CSSColor) -> Self { _styled(.outlineColor(v)) }
    public func borderSpacing(_ h: CSSLength, _ v: CSSLength? = nil) -> Self { _styled(.borderSpacing(h, v)) }

    // Motion 3D + scroll/flex tail + multicol + SVG + counters collapse variants
    public func transformStyle(_ v: TransformStyle) -> Self { _styled(.transformStyle(v)) }
    public func perspective(_ v: CSSLength) -> Self { _styled(.perspective(v)) }
    public func backfaceVisibility(_ v: BackfaceVisibility) -> Self { _styled(.backfaceVisibility(v)) }
    public func willChange(_ hints: WillChange...) -> Self {
        guard let d = StyleDeclaration.willChange(hints) else { return self }
        return _styled(d)
    }
    /// See `Tag.animation(_:duration:…)`.
    public func animation(_ keyframes: Keyframes, duration: CSSDuration,
                          timingFunction: TimingFunction = .ease,
                          delay: CSSDuration = .ms(0),
                          iterations: AnimationIterations = .count(1),
                          direction: AnimationDirection = .normal,
                          fillMode: AnimationFillMode = .none,
                          respectsReducedMotion: Bool = true) -> Self {
        guard let rule = _animationRule(keyframes, duration: duration,
                                        timingFunction: timingFunction, delay: delay,
                                        iterations: iterations, direction: direction,
                                        fillMode: fillMode,
                                        respectsReducedMotion: respectsReducedMotion) else {
            return self
        }
        var copy = self
        copy.rules.append(rule)
        return copy
    }
    public func transitionDelay(_ v: CSSDuration) -> Self { _styled(.transitionDelay(v)) }
    public func contentVisibility(_ v: ContentVisibility) -> Self { _styled(.contentVisibility(v)) }
    public func containIntrinsicSize(_ v: CSSLength) -> Self { _styled(.containIntrinsicSize(v)) }
    public func containIntrinsicSize(_ w: CSSLength, _ h: CSSLength) -> Self { _styled(.containIntrinsicSize(w, h)) }
    public func scrollSnapStop(_ v: ScrollSnapStop) -> Self { _styled(.scrollSnapStop(v)) }
    public func scrollMargin(_ v: CSSLength) -> Self { _styled(.scrollMargin(v)) }
    public func scrollMargin(_ side: Side, _ v: CSSLength) -> Self { _styled(.scrollMargin(side, v)) }
    public func placeSelf(_ align: AlignItems, _ justify: JustifySelf) -> Self { _styled(.placeSelf(align, justify)) }
    public func flex(_ v: FlexShorthand) -> Self { _styled(.flex(v)) }
    public func flex(_ grow: Double) -> Self { _styled(.flex(grow)) }
    public func flexFlow(_ direction: FlexDirection, _ wrap: FlexWrap) -> Self { _styled(.flexFlow(direction, wrap)) }
    public func content(_ v: String) -> Self {
        guard let d = StyleDeclaration.content(v) else { return self }
        return _styled(d)
    }
    public func columnCount(_ v: Int) -> Self { _styled(.columnCount(v)) }
    public func columnWidth(_ v: CSSLength) -> Self { _styled(.columnWidth(v)) }
    public func scrollbarWidth(_ v: ScrollbarWidth) -> Self { _styled(.scrollbarWidth(v)) }
    public func scrollbarColor(_ thumb: CSSColor, _ track: CSSColor) -> Self { _styled(.scrollbarColor(thumb, track)) }
    public func tapHighlightColor(_ v: CSSColor) -> Self { _styled(.tapHighlightColor(v)) }
    public func fill(_ v: CSSColor) -> Self { _styled(.fill(v)) }
    public func stroke(_ v: CSSColor) -> Self { _styled(.stroke(v)) }
    public func strokeWidth(_ v: CSSLength) -> Self { _styled(.strokeWidth(v)) }
    public func counterReset(_ actions: CounterAction...) -> Self {
        guard let d = StyleDeclaration.counterReset(actions) else { return self }
        return _styled(d)
    }
    public func counterIncrement(_ actions: CounterAction...) -> Self {
        guard let d = StyleDeclaration.counterIncrement(actions) else { return self }
        return _styled(d)
    }
    public func counterSet(_ actions: CounterAction...) -> Self {
        guard let d = StyleDeclaration.counterSet(actions) else { return self }
        return _styled(d)
    }

    func _responsive<V>(_ r: Responsive<V>,
                        _ apply: (inout StyleProxy, V) -> Void) -> Self {
        var copy = self
        var base = StyleProxy(); apply(&base, r.base)
        // Same anonymous-rule routing as the Tag variant (see its comment) —
        // base declarations join `rules`, not the wrapper's inline `declarations`.
        if !base.declarations.isEmpty {
            copy.rules.append(PendingStyleRule(pseudo: nil, media: nil, declarations: base.declarations))
        }
        for (i, pair) in r.overrides.enumerated() {
            var p = StyleProxy(); apply(&p, pair.1)
            guard !p.declarations.isEmpty else { continue }
            let cond: MediaQuery = (i + 1 < r.overrides.count)
                ? .and(.up(pair.0), .maxWidth(.px(r.overrides[i + 1].0.minWidthPx - 0.02)))
                : .up(pair.0)
            copy.rules.append(PendingStyleRule(pseudo: nil, media: cond.condition, declarations: p.declarations))
        }
        return copy
    }
    // ponytail: overload set bounded to layout/typography props that actually vary by width; extend per demand.
    public func padding(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.padding($1) } }
    public func margin(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.margin($1) } }
    public func width(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.width($1) } }
    public func height(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.height($1) } }
    public func minWidth(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.minWidth($1) } }
    public func maxWidth(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.maxWidth($1) } }
    public func fontSize(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.fontSize($1) } }
    public func gap(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.gap($1) } }
    public func display(_ r: Responsive<Display>) -> Self { _responsive(r) { $0.display($1) } }
    public func flexDirection(_ r: Responsive<FlexDirection>) -> Self { _responsive(r) { $0.flexDirection($1) } }
    public func textAlign(_ r: Responsive<TextAlign>) -> Self { _responsive(r) { $0.textAlign($1) } }
    public func gridTemplateColumns(_ r: Responsive<String>) -> Self { _responsive(r) { $0.gridTemplateColumns($1) } }
}
