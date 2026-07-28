/// Declaration collector shared by rules, Style bundles, and pseudo blocks.
/// Statement style: `s.padding(.px(8))`.
public struct StyleProxy {
    var declarations: [StyleDeclaration] = []
    var pseudoBlocks: [(pseudo: String, declarations: [StyleDeclaration])] = []
    var mediaBlocks: [(media: String, declarations: [StyleDeclaration])] = []
    var containerBlocks: [(container: String, declarations: [StyleDeclaration])] = []

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
        assert(sub.mediaBlocks.isEmpty && sub.containerBlocks.isEmpty, "nested media/container blocks are not supported")
        guard !sub.declarations.isEmpty else { return }   // empty block → nothing to register
        pseudoBlocks.append((name, sub.declarations))
    }
    public mutating func hover(_ body: (inout StyleProxy) -> Void)  { _pseudo(":hover", body) }
    public mutating func focus(_ body: (inout StyleProxy) -> Void)  { _pseudo(":focus", body) }
    /// Focus ring only when the browser judges it warranted — keyboard and
    /// programmatic focus, not a mouse click. Prefer this over `focus` for
    /// rings; `focus` is still right for a persistent field-active treatment.
    public mutating func focusVisible(_ body: (inout StyleProxy) -> Void) { _pseudo(":focus-visible", body) }
    public mutating func active(_ body: (inout StyleProxy) -> Void) { _pseudo(":active", body) }

    /// Media block collector for `Style` bundles (spec §10 promises media in
    /// bundles). Same shape as `_pseudo`: a sub-proxy collects declarations,
    /// no nested pseudo/media blocks.
    public mutating func media(_ query: MediaQuery, _ body: (inout StyleProxy) -> Void) {
        var sub = StyleProxy()
        body(&sub)
        assert(sub.pseudoBlocks.isEmpty, "pseudo blocks inside a media block are not supported")
        assert(sub.mediaBlocks.isEmpty && sub.containerBlocks.isEmpty, "nested media/container blocks are not supported")
        guard !sub.declarations.isEmpty else { return }   // empty block → nothing to register
        mediaBlocks.append((query.condition, sub.declarations))
    }

    /// Container-query block collector for `Style` bundles, mirroring `media`.
    public mutating func container(_ query: MediaQuery, name: String? = nil, _ body: (inout StyleProxy) -> Void) {
        var sub = StyleProxy()
        body(&sub)
        assert(sub.pseudoBlocks.isEmpty, "pseudo blocks inside a container block are not supported")
        assert(sub.mediaBlocks.isEmpty && sub.containerBlocks.isEmpty, "nested media/container blocks are not supported")
        guard !sub.declarations.isEmpty else { return }
        let safeName = name.flatMap { CSSSanitize.isValidIdent($0) ? $0 : nil }
        containerBlocks.append(((safeName.map { "\($0) " } ?? "") + query.condition, sub.declarations))
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

    public mutating func overflowX(_ v: Overflow) { _add(.overflowX(v)) }
    public mutating func overflowY(_ v: Overflow) { _add(.overflowY(v)) }
    public mutating func objectFit(_ v: ObjectFit) { _add(.objectFit(v)) }
    public mutating func objectPosition(_ v: ObjectPosition) { _add(.objectPosition(v)) }
    public mutating func aspectRatio(_ v: AspectRatio) { _add(.aspectRatio(v)) }
    public mutating func aspectRatio(_ w: Double, _ h: Double) { _add(.aspectRatio(.ratio(w, h))) }
    public mutating func visibility(_ v: Visibility) { _add(.visibility(v)) }
    public mutating func whiteSpace(_ v: WhiteSpace) { _add(.whiteSpace(v)) }
    public mutating func textTransform(_ v: TextTransform) { _add(.textTransform(v)) }
    public mutating func textOverflow(_ v: TextOverflow) { _add(.textOverflow(v)) }
    public mutating func lineClamp(_ lines: Int) { for d in StyleDeclaration.lineClamp(lines) { _add(d) } }
    public mutating func backgroundColor(_ v: CSSColor) { _add(.backgroundColor(v)) }
    public mutating func backgroundImage(_ v: CSSBackgroundImage) { _add(.backgroundImage(v)) }
    public mutating func backgroundRepeat(_ v: BackgroundRepeat) { _add(.backgroundRepeat(v)) }
    public mutating func border(_ side: Side, width: CSSLength = .px(1), style: BorderStyle = .solid, color: CSSColor = .current) { _add(.border(side, width: width, style: style, color: color)) }
    public mutating func borderRadius(_ v: BorderRadius) { _add(.borderRadius(v)) }
    public mutating func filter(_ fns: FilterFunction...) { if let d = StyleDeclaration.filter(fns) { _add(d) } }
    public mutating func transform(_ fns: TransformFunction...) { if let d = StyleDeclaration.transform(fns) { _add(d) } }
    public mutating func pointerEvents(_ v: PointerEvents) { _add(.pointerEvents(v)) }
    public mutating func userSelect(_ v: UserSelect) { _add(.userSelect(v)) }

    // Structural: layout / flex / grid
    public mutating func inlineSize(_ v: CSSLength) { _add(.inlineSize(v)) }
    public mutating func blockSize(_ v: CSSLength) { _add(.blockSize(v)) }
    public mutating func inset(_ v: CSSLength) { _add(.inset(v)) }
    public mutating func marginInline(_ v: CSSLength) { _add(.marginInline(v)) }
    public mutating func marginBlock(_ v: CSSLength) { _add(.marginBlock(v)) }
    public mutating func paddingInline(_ v: CSSLength) { _add(.paddingInline(v)) }
    public mutating func paddingBlock(_ v: CSSLength) { _add(.paddingBlock(v)) }
    public mutating func rowGap(_ v: CSSLength) { _add(.rowGap(v)) }
    public mutating func columnGap(_ v: CSSLength) { _add(.columnGap(v)) }
    public mutating func gap(row: CSSLength, column: CSSLength) { _add(.gap(row: row, column: column)) }
    public mutating func order(_ v: Int) { _add(.order(v)) }
    public mutating func justifyItems(_ v: JustifyItems) { _add(.justifyItems(v)) }
    public mutating func justifySelf(_ v: JustifySelf) { _add(.justifySelf(v)) }
    public mutating func alignContent(_ v: AlignContent) { _add(.alignContent(v)) }
    public mutating func placeContent(_ align: AlignContent, _ justify: JustifyContent) { _add(.placeContent(align, justify)) }
    public mutating func placeItems(_ align: AlignItems, _ justify: JustifyItems) { _add(.placeItems(align, justify)) }
    public mutating func gridAutoFlow(_ v: GridAutoFlow) { _add(.gridAutoFlow(v)) }
    public mutating func gridColumnStart(_ v: GridLine) { _add(.gridColumnStart(v)) }
    public mutating func gridColumnEnd(_ v: GridLine) { _add(.gridColumnEnd(v)) }
    public mutating func gridRowStart(_ v: GridLine) { _add(.gridRowStart(v)) }
    public mutating func gridRowEnd(_ v: GridLine) { _add(.gridRowEnd(v)) }
    public mutating func gridColumn(_ start: GridLine, _ end: GridLine? = nil) { _add(.gridColumn(start, end)) }
    public mutating func gridRow(_ start: GridLine, _ end: GridLine? = nil) { _add(.gridRow(start, end)) }
    public mutating func gridTemplateAreas(_ v: String) { if let d = StyleDeclaration.gridTemplateAreas(v) { _add(d) } }
    public mutating func gridArea(_ name: String) { if let d = StyleDeclaration.gridArea(name) { _add(d) } }

    // Typography + background/border
    public mutating func fontStyle(_ v: FontStyle) { _add(.fontStyle(v)) }
    public mutating func textDecorationLine(_ v: TextDecorationLine) { _add(.textDecorationLine(v)) }
    public mutating func textDecorationColor(_ v: CSSColor) { _add(.textDecorationColor(v)) }
    public mutating func textDecorationStyle(_ v: TextDecorationStyle) { _add(.textDecorationStyle(v)) }
    public mutating func textDecorationThickness(_ v: CSSLength) { _add(.textDecorationThickness(v)) }
    public mutating func textIndent(_ v: CSSLength) { _add(.textIndent(v)) }
    public mutating func textShadow(_ shadows: Shadow...) { if let d = StyleDeclaration.textShadow(shadows) { _add(d) } }
    public mutating func wordBreak(_ v: WordBreak) { _add(.wordBreak(v)) }
    public mutating func overflowWrap(_ v: OverflowWrap) { _add(.overflowWrap(v)) }
    public mutating func verticalAlign(_ v: VerticalAlign) { _add(.verticalAlign(v)) }
    public mutating func lineHeight(_ v: CSSLength) { _add(.lineHeight(v)) }
    public mutating func listStyleType(_ v: ListStyleType) { _add(.listStyleType(v)) }
    public mutating func textWrap(_ v: TextWrap) { _add(.textWrap(v)) }
    public mutating func fontVariantNumeric(_ v: FontVariantNumeric) { _add(.fontVariantNumeric(v)) }
    public mutating func backgroundClip(_ v: BackgroundClip) { for d in StyleDeclaration.backgroundClip(v) { _add(d) } }
    public mutating func borderWidth(_ v: CSSLength) { _add(.borderWidth(v)) }
    public mutating func borderWidth(_ side: Side, _ v: CSSLength) { _add(.borderWidth(side, v)) }
    public mutating func borderStyle(_ v: BorderStyle) { _add(.borderStyle(v)) }
    public mutating func borderStyle(_ side: Side, _ v: BorderStyle) { _add(.borderStyle(side, v)) }
    public mutating func borderColor(_ side: Side, _ v: CSSColor) { _add(.borderColor(side, v)) }
    public mutating func outlineOffset(_ v: CSSLength) { _add(.outlineOffset(v)) }
    public mutating func outlineWidth(_ v: CSSLength) { _add(.outlineWidth(v)) }
    public mutating func outlineStyle(_ v: OutlineStyle) { _add(.outlineStyle(v)) }
    public mutating func boxShadow(_ shadows: Shadow...) { if let d = StyleDeclaration.boxShadow(shadows) { _add(d) } }
    public mutating func mixBlendMode(_ v: BlendMode) { _add(.mixBlendMode(v)) }

    // Effects/motion + interactivity/misc
    public mutating func backdropFilter(_ fns: FilterFunction...) { if let d = StyleDeclaration.backdropFilter(fns) { _add(d) } }
    public mutating func clipPath(_ v: ClipPath) { _add(.clipPath(v)) }
    public mutating func transition(property: String, duration: CSSDuration, timingFunction: TimingFunction = .ease, delay: CSSDuration = .ms(0)) {
        if let d = StyleDeclaration.transition(property: property, duration: duration, timingFunction: timingFunction, delay: delay) { _add(d) }
    }
    public mutating func transitionDuration(_ v: CSSDuration) { _add(.transitionDuration(v)) }
    public mutating func transitionTimingFunction(_ v: TimingFunction) { _add(.transitionTimingFunction(v)) }
    public mutating func touchAction(_ v: TouchAction) { _add(.touchAction(v)) }
    public mutating func scrollBehavior(_ v: ScrollBehavior) { _add(.scrollBehavior(v)) }
    public mutating func scrollSnapType(_ v: ScrollSnapType) { _add(.scrollSnapType(v)) }
    public mutating func scrollSnapAlign(_ v: ScrollSnapAlign) { _add(.scrollSnapAlign(v)) }
    public mutating func scrollPadding(_ v: CSSLength) { _add(.scrollPadding(v)) }
    public mutating func scrollPadding(_ side: Side, _ v: CSSLength) { _add(.scrollPadding(side, v)) }
    public mutating func overscrollBehavior(_ v: OverscrollBehavior) { _add(.overscrollBehavior(v)) }
    public mutating func overscrollBehaviorX(_ v: OverscrollBehavior) { _add(.overscrollBehaviorX(v)) }
    public mutating func overscrollBehaviorY(_ v: OverscrollBehavior) { _add(.overscrollBehaviorY(v)) }
    public mutating func resize(_ v: Resize) { _add(.resize(v)) }
    public mutating func appearance(_ v: Appearance) { for d in StyleDeclaration.appearance(v) { _add(d) } }
    public mutating func accentColor(_ v: CSSColor) { _add(.accentColor(v)) }
    public mutating func listStylePosition(_ v: ListStylePosition) { _add(.listStylePosition(v)) }
    public mutating func borderCollapse(_ v: BorderCollapse) { _add(.borderCollapse(v)) }
    public mutating func tableLayout(_ v: TableLayout) { _add(.tableLayout(v)) }
    public mutating func colorSchemeHint(_ v: ColorSchemeHint) { _add(.colorSchemeHint(v)) }
    public mutating func breakInside(_ v: BreakInside) { _add(.breakInside(v)) }
    public mutating func breakBefore(_ v: BreakBetween) { _add(.breakBefore(v)) }
    public mutating func breakAfter(_ v: BreakBetween) { _add(.breakAfter(v)) }

    // Logical box + font sub-props + background/border tail
    public mutating func marginInlineStart(_ v: CSSLength) { _add(.marginInlineStart(v)) }
    public mutating func marginInlineEnd(_ v: CSSLength) { _add(.marginInlineEnd(v)) }
    public mutating func marginBlockStart(_ v: CSSLength) { _add(.marginBlockStart(v)) }
    public mutating func marginBlockEnd(_ v: CSSLength) { _add(.marginBlockEnd(v)) }
    public mutating func paddingInlineStart(_ v: CSSLength) { _add(.paddingInlineStart(v)) }
    public mutating func paddingInlineEnd(_ v: CSSLength) { _add(.paddingInlineEnd(v)) }
    public mutating func paddingBlockStart(_ v: CSSLength) { _add(.paddingBlockStart(v)) }
    public mutating func paddingBlockEnd(_ v: CSSLength) { _add(.paddingBlockEnd(v)) }
    public mutating func insetInlineStart(_ v: CSSLength) { _add(.insetInlineStart(v)) }
    public mutating func insetInlineEnd(_ v: CSSLength) { _add(.insetInlineEnd(v)) }
    public mutating func insetBlockStart(_ v: CSSLength) { _add(.insetBlockStart(v)) }
    public mutating func insetBlockEnd(_ v: CSSLength) { _add(.insetBlockEnd(v)) }
    public mutating func minInlineSize(_ v: CSSLength) { _add(.minInlineSize(v)) }
    public mutating func maxInlineSize(_ v: CSSLength) { _add(.maxInlineSize(v)) }
    public mutating func minBlockSize(_ v: CSSLength) { _add(.minBlockSize(v)) }
    public mutating func maxBlockSize(_ v: CSSLength) { _add(.maxBlockSize(v)) }
    public mutating func float(_ v: CSSFloat) { _add(.float(v)) }
    public mutating func clear(_ v: Clear) { _add(.clear(v)) }
    public mutating func isolation(_ v: Isolation) { _add(.isolation(v)) }
    public mutating func fontVariant(_ v: FontVariant) { _add(.fontVariant(v)) }
    public mutating func fontStretch(_ v: FontStretch) { _add(.fontStretch(v)) }
    public mutating func fontOpticalSizing(_ v: FontOpticalSizing) { _add(.fontOpticalSizing(v)) }
    public mutating func fontSmoothing(_ v: FontSmoothing) { for d in StyleDeclaration.fontSmoothing(v) { _add(d) } }
    public mutating func textAlignLast(_ v: TextAlignLast) { _add(.textAlignLast(v)) }
    public mutating func textUnderlineOffset(_ v: CSSLength) { _add(.textUnderlineOffset(v)) }
    public mutating func wordSpacing(_ v: CSSLength) { _add(.wordSpacing(v)) }
    public mutating func hyphens(_ v: Hyphens) { _add(.hyphens(v)) }
    public mutating func direction(_ v: Direction) { _add(.direction(v)) }
    public mutating func caretColor(_ v: CaretColor) { _add(.caretColor(v)) }
    public mutating func textStroke(_ v: TextStroke) { _add(.textStroke(v)) }
    public mutating func backgroundAttachment(_ v: BackgroundAttachment) { _add(.backgroundAttachment(v)) }
    public mutating func backgroundOrigin(_ v: BackgroundOrigin) { _add(.backgroundOrigin(v)) }
    public mutating func backgroundBlendMode(_ v: BlendMode) { _add(.backgroundBlendMode(v)) }
    public mutating func backgroundPosition(_ v: BackgroundPosition) { _add(.backgroundPosition(v)) }
    public mutating func backgroundSize(_ v: BackgroundSize) { _add(.backgroundSize(v)) }
    public mutating func outlineColor(_ v: CSSColor) { _add(.outlineColor(v)) }
    public mutating func borderSpacing(_ h: CSSLength, _ v: CSSLength? = nil) { _add(.borderSpacing(h, v)) }

    // Motion 3D + scroll/flex tail + multicol + SVG + counters
    public mutating func transformStyle(_ v: TransformStyle) { _add(.transformStyle(v)) }
    public mutating func perspective(_ v: CSSLength) { _add(.perspective(v)) }
    public mutating func backfaceVisibility(_ v: BackfaceVisibility) { _add(.backfaceVisibility(v)) }
    public mutating func willChange(_ hints: WillChange...) { if let d = StyleDeclaration.willChange(hints) { _add(d) } }
    public mutating func transitionDelay(_ v: CSSDuration) { _add(.transitionDelay(v)) }
    public mutating func contentVisibility(_ v: ContentVisibility) { _add(.contentVisibility(v)) }
    public mutating func containIntrinsicSize(_ v: CSSLength) { _add(.containIntrinsicSize(v)) }
    public mutating func containIntrinsicSize(_ w: CSSLength, _ h: CSSLength) { _add(.containIntrinsicSize(w, h)) }
    public mutating func scrollSnapStop(_ v: ScrollSnapStop) { _add(.scrollSnapStop(v)) }
    public mutating func scrollMargin(_ v: CSSLength) { _add(.scrollMargin(v)) }
    public mutating func scrollMargin(_ side: Side, _ v: CSSLength) { _add(.scrollMargin(side, v)) }
    public mutating func placeSelf(_ align: AlignItems, _ justify: JustifySelf) { _add(.placeSelf(align, justify)) }
    public mutating func flex(_ v: FlexShorthand) { _add(.flex(v)) }
    public mutating func flex(_ grow: Double) { _add(.flex(grow)) }
    public mutating func flexFlow(_ direction: FlexDirection, _ wrap: FlexWrap) { _add(.flexFlow(direction, wrap)) }
    public mutating func content(_ v: String) { if let d = StyleDeclaration.content(v) { _add(d) } }
    public mutating func columnCount(_ v: Int) { _add(.columnCount(v)) }
    public mutating func columnWidth(_ v: CSSLength) { _add(.columnWidth(v)) }
    public mutating func scrollbarWidth(_ v: ScrollbarWidth) { _add(.scrollbarWidth(v)) }
    public mutating func scrollbarColor(_ thumb: CSSColor, _ track: CSSColor) { _add(.scrollbarColor(thumb, track)) }
    public mutating func tapHighlightColor(_ v: CSSColor) { _add(.tapHighlightColor(v)) }
    public mutating func fill(_ v: CSSColor) { _add(.fill(v)) }
    public mutating func stroke(_ v: CSSColor) { _add(.stroke(v)) }
    public mutating func strokeWidth(_ v: CSSLength) { _add(.strokeWidth(v)) }
    public mutating func counterReset(_ actions: CounterAction...) { if let d = StyleDeclaration.counterReset(actions) { _add(d) } }
    public mutating func counterIncrement(_ actions: CounterAction...) { if let d = StyleDeclaration.counterIncrement(actions) { _add(d) } }
    public mutating func counterSet(_ actions: CounterAction...) { if let d = StyleDeclaration.counterSet(actions) { _add(d) } }
}
