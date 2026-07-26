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
    public func cssTransition(_ v: String) -> Self { _style(.transition(v)) }
    public func listStyle(_ v: String) -> Self { _style(.listStyle(v)) }

    public func overflowX(_ v: Overflow) -> Self { _style(.overflowX(v)) }
    public func overflowY(_ v: Overflow) -> Self { _style(.overflowY(v)) }
    public func objectFit(_ v: ObjectFit) -> Self { _style(.objectFit(v)) }
    public func objectPosition(_ v: ObjectPosition) -> Self { _style(.objectPosition(v)) }
    public func aspectRatio(_ v: AspectRatio) -> Self { _style(.aspectRatio(v)) }
    public func aspectRatio(_ w: Double, _ h: Double) -> Self { _style(.aspectRatio(.ratio(w, h))) }
    public func visibility(_ v: Visibility) -> Self { _style(.visibility(v)) }
    public func whiteSpace(_ v: WhiteSpace) -> Self { _style(.whiteSpace(v)) }
    public func textTransform(_ v: TextTransform) -> Self { _style(.textTransform(v)) }
    public func textOverflow(_ v: TextOverflow) -> Self { _style(.textOverflow(v)) }
    public func lineClamp(_ lines: Int) -> Self {
        var copy = self
        for d in StyleDeclaration.lineClamp(lines) { copy = copy._style(d) }
        return copy
    }
    public func backgroundColor(_ v: CSSColor) -> Self { _style(.backgroundColor(v)) }
    public func backgroundImage(_ v: CSSBackgroundImage) -> Self { _style(.backgroundImage(v)) }
    public func backgroundRepeat(_ v: BackgroundRepeat) -> Self { _style(.backgroundRepeat(v)) }
    public func border(_ side: Side, width: CSSLength = .px(1), style: BorderStyle = .solid, color: CSSColor = .current) -> Self { _style(.border(side, width: width, style: style, color: color)) }
    public func borderRadius(_ v: BorderRadius) -> Self { _style(.borderRadius(v)) }
    public func filter(_ fns: FilterFunction...) -> Self {
        guard let d = StyleDeclaration.filter(fns) else { return self }
        return _style(d)
    }
    public func transform(_ fns: TransformFunction...) -> Self {
        guard let d = StyleDeclaration.transform(fns) else { return self }
        return _style(d)
    }
    public func pointerEvents(_ v: PointerEvents) -> Self { _style(.pointerEvents(v)) }
    public func userSelect(_ v: UserSelect) -> Self { _style(.userSelect(v)) }

    // Structural: layout / flex / grid
    public func inlineSize(_ v: CSSLength) -> Self { _style(.inlineSize(v)) }
    public func blockSize(_ v: CSSLength) -> Self { _style(.blockSize(v)) }
    public func inset(_ v: CSSLength) -> Self { _style(.inset(v)) }
    public func marginInline(_ v: CSSLength) -> Self { _style(.marginInline(v)) }
    public func marginBlock(_ v: CSSLength) -> Self { _style(.marginBlock(v)) }
    public func paddingInline(_ v: CSSLength) -> Self { _style(.paddingInline(v)) }
    public func paddingBlock(_ v: CSSLength) -> Self { _style(.paddingBlock(v)) }
    public func rowGap(_ v: CSSLength) -> Self { _style(.rowGap(v)) }
    public func columnGap(_ v: CSSLength) -> Self { _style(.columnGap(v)) }
    public func gap(row: CSSLength, column: CSSLength) -> Self { _style(.gap(row: row, column: column)) }
    public func order(_ v: Int) -> Self { _style(.order(v)) }
    public func justifyItems(_ v: JustifyItems) -> Self { _style(.justifyItems(v)) }
    public func justifySelf(_ v: JustifySelf) -> Self { _style(.justifySelf(v)) }
    public func alignContent(_ v: AlignContent) -> Self { _style(.alignContent(v)) }
    public func placeContent(_ align: AlignContent, _ justify: JustifyContent) -> Self { _style(.placeContent(align, justify)) }
    public func placeItems(_ align: AlignItems, _ justify: JustifyItems) -> Self { _style(.placeItems(align, justify)) }
    public func gridAutoFlow(_ v: GridAutoFlow) -> Self { _style(.gridAutoFlow(v)) }
    public func gridColumnStart(_ v: GridLine) -> Self { _style(.gridColumnStart(v)) }
    public func gridColumnEnd(_ v: GridLine) -> Self { _style(.gridColumnEnd(v)) }
    public func gridRowStart(_ v: GridLine) -> Self { _style(.gridRowStart(v)) }
    public func gridRowEnd(_ v: GridLine) -> Self { _style(.gridRowEnd(v)) }
    public func gridColumn(_ start: GridLine, _ end: GridLine? = nil) -> Self { _style(.gridColumn(start, end)) }
    public func gridRow(_ start: GridLine, _ end: GridLine? = nil) -> Self { _style(.gridRow(start, end)) }
    public func gridTemplateAreas(_ v: String) -> Self {
        guard let d = StyleDeclaration.gridTemplateAreas(v) else { return self }
        return _style(d)
    }
    public func gridArea(_ name: String) -> Self {
        guard let d = StyleDeclaration.gridArea(name) else { return self }
        return _style(d)
    }

    // Typography + background/border
    public func fontStyle(_ v: FontStyle) -> Self { _style(.fontStyle(v)) }
    public func textDecorationLine(_ v: TextDecorationLine) -> Self { _style(.textDecorationLine(v)) }
    public func textDecorationColor(_ v: CSSColor) -> Self { _style(.textDecorationColor(v)) }
    public func textDecorationStyle(_ v: TextDecorationStyle) -> Self { _style(.textDecorationStyle(v)) }
    public func textDecorationThickness(_ v: CSSLength) -> Self { _style(.textDecorationThickness(v)) }
    public func textIndent(_ v: CSSLength) -> Self { _style(.textIndent(v)) }
    public func textShadow(_ shadows: Shadow...) -> Self {
        guard let d = StyleDeclaration.textShadow(shadows) else { return self }
        return _style(d)
    }
    public func wordBreak(_ v: WordBreak) -> Self { _style(.wordBreak(v)) }
    public func overflowWrap(_ v: OverflowWrap) -> Self { _style(.overflowWrap(v)) }
    public func verticalAlign(_ v: VerticalAlign) -> Self { _style(.verticalAlign(v)) }
    public func lineHeight(_ v: CSSLength) -> Self { _style(.lineHeight(v)) }
    public func listStyleType(_ v: ListStyleType) -> Self { _style(.listStyleType(v)) }
    public func textWrap(_ v: TextWrap) -> Self { _style(.textWrap(v)) }
    public func fontVariantNumeric(_ v: FontVariantNumeric) -> Self { _style(.fontVariantNumeric(v)) }
    public func backgroundClip(_ v: BackgroundClip) -> Self {
        var copy = self
        for d in StyleDeclaration.backgroundClip(v) { copy = copy._style(d) }
        return copy
    }
    public func borderWidth(_ v: CSSLength) -> Self { _style(.borderWidth(v)) }
    public func borderWidth(_ side: Side, _ v: CSSLength) -> Self { _style(.borderWidth(side, v)) }
    public func borderStyle(_ v: BorderStyle) -> Self { _style(.borderStyle(v)) }
    public func borderStyle(_ side: Side, _ v: BorderStyle) -> Self { _style(.borderStyle(side, v)) }
    public func borderColor(_ side: Side, _ v: CSSColor) -> Self { _style(.borderColor(side, v)) }
    public func outlineOffset(_ v: CSSLength) -> Self { _style(.outlineOffset(v)) }
    public func outlineWidth(_ v: CSSLength) -> Self { _style(.outlineWidth(v)) }
    public func outlineStyle(_ v: OutlineStyle) -> Self { _style(.outlineStyle(v)) }
    public func boxShadow(_ shadows: Shadow...) -> Self {
        guard let d = StyleDeclaration.boxShadow(shadows) else { return self }
        return _style(d)
    }
    public func mixBlendMode(_ v: BlendMode) -> Self { _style(.mixBlendMode(v)) }

    // Effects/motion + interactivity/misc
    public func backdropFilter(_ fns: FilterFunction...) -> Self {
        guard let d = StyleDeclaration.backdropFilter(fns) else { return self }
        return _style(d)
    }
    public func clipPath(_ v: ClipPath) -> Self { _style(.clipPath(v)) }
    /// Typed transition longhand. `cssTransition(_:)` remains the raw-string escape.
    public func transition(property: String, duration: CSSDuration, timingFunction: TimingFunction = .ease, delay: CSSDuration = .ms(0)) -> Self {
        guard let d = StyleDeclaration.transition(property: property, duration: duration, timingFunction: timingFunction, delay: delay) else { return self }
        return _style(d)
    }
    public func transitionDuration(_ v: CSSDuration) -> Self { _style(.transitionDuration(v)) }
    public func transitionTimingFunction(_ v: TimingFunction) -> Self { _style(.transitionTimingFunction(v)) }
    public func touchAction(_ v: TouchAction) -> Self { _style(.touchAction(v)) }
    public func scrollBehavior(_ v: ScrollBehavior) -> Self { _style(.scrollBehavior(v)) }
    public func scrollSnapType(_ v: ScrollSnapType) -> Self { _style(.scrollSnapType(v)) }
    public func scrollSnapAlign(_ v: ScrollSnapAlign) -> Self { _style(.scrollSnapAlign(v)) }
    public func scrollPadding(_ v: CSSLength) -> Self { _style(.scrollPadding(v)) }
    public func scrollPadding(_ side: Side, _ v: CSSLength) -> Self { _style(.scrollPadding(side, v)) }
    public func overscrollBehavior(_ v: OverscrollBehavior) -> Self { _style(.overscrollBehavior(v)) }
    public func overscrollBehaviorX(_ v: OverscrollBehavior) -> Self { _style(.overscrollBehaviorX(v)) }
    public func overscrollBehaviorY(_ v: OverscrollBehavior) -> Self { _style(.overscrollBehaviorY(v)) }
    public func resize(_ v: Resize) -> Self { _style(.resize(v)) }
    public func appearance(_ v: Appearance) -> Self {
        var copy = self
        for d in StyleDeclaration.appearance(v) { copy = copy._style(d) }
        return copy
    }
    public func accentColor(_ v: CSSColor) -> Self { _style(.accentColor(v)) }
    public func listStylePosition(_ v: ListStylePosition) -> Self { _style(.listStylePosition(v)) }
    public func borderCollapse(_ v: BorderCollapse) -> Self { _style(.borderCollapse(v)) }
    public func tableLayout(_ v: TableLayout) -> Self { _style(.tableLayout(v)) }
    public func colorSchemeHint(_ v: ColorSchemeHint) -> Self { _style(.colorSchemeHint(v)) }
    public func breakInside(_ v: BreakInside) -> Self { _style(.breakInside(v)) }
    public func breakBefore(_ v: BreakBetween) -> Self { _style(.breakBefore(v)) }
    public func breakAfter(_ v: BreakBetween) -> Self { _style(.breakAfter(v)) }

    // Logical box + font sub-props + background/border tail
    public func marginInlineStart(_ v: CSSLength) -> Self { _style(.marginInlineStart(v)) }
    public func marginInlineEnd(_ v: CSSLength) -> Self { _style(.marginInlineEnd(v)) }
    public func marginBlockStart(_ v: CSSLength) -> Self { _style(.marginBlockStart(v)) }
    public func marginBlockEnd(_ v: CSSLength) -> Self { _style(.marginBlockEnd(v)) }
    public func paddingInlineStart(_ v: CSSLength) -> Self { _style(.paddingInlineStart(v)) }
    public func paddingInlineEnd(_ v: CSSLength) -> Self { _style(.paddingInlineEnd(v)) }
    public func paddingBlockStart(_ v: CSSLength) -> Self { _style(.paddingBlockStart(v)) }
    public func paddingBlockEnd(_ v: CSSLength) -> Self { _style(.paddingBlockEnd(v)) }
    public func insetInlineStart(_ v: CSSLength) -> Self { _style(.insetInlineStart(v)) }
    public func insetInlineEnd(_ v: CSSLength) -> Self { _style(.insetInlineEnd(v)) }
    public func insetBlockStart(_ v: CSSLength) -> Self { _style(.insetBlockStart(v)) }
    public func insetBlockEnd(_ v: CSSLength) -> Self { _style(.insetBlockEnd(v)) }
    public func minInlineSize(_ v: CSSLength) -> Self { _style(.minInlineSize(v)) }
    public func maxInlineSize(_ v: CSSLength) -> Self { _style(.maxInlineSize(v)) }
    public func minBlockSize(_ v: CSSLength) -> Self { _style(.minBlockSize(v)) }
    public func maxBlockSize(_ v: CSSLength) -> Self { _style(.maxBlockSize(v)) }
    public func float(_ v: CSSFloat) -> Self { _style(.float(v)) }
    public func clear(_ v: Clear) -> Self { _style(.clear(v)) }
    public func isolation(_ v: Isolation) -> Self { _style(.isolation(v)) }
    public func fontVariant(_ v: FontVariant) -> Self { _style(.fontVariant(v)) }
    public func fontStretch(_ v: FontStretch) -> Self { _style(.fontStretch(v)) }
    public func fontOpticalSizing(_ v: FontOpticalSizing) -> Self { _style(.fontOpticalSizing(v)) }
    public func fontSmoothing(_ v: FontSmoothing) -> Self {
        var copy = self
        for d in StyleDeclaration.fontSmoothing(v) { copy = copy._style(d) }
        return copy
    }
    public func textAlignLast(_ v: TextAlignLast) -> Self { _style(.textAlignLast(v)) }
    public func textUnderlineOffset(_ v: CSSLength) -> Self { _style(.textUnderlineOffset(v)) }
    public func wordSpacing(_ v: CSSLength) -> Self { _style(.wordSpacing(v)) }
    public func hyphens(_ v: Hyphens) -> Self { _style(.hyphens(v)) }
    public func direction(_ v: Direction) -> Self { _style(.direction(v)) }
    public func caretColor(_ v: CaretColor) -> Self { _style(.caretColor(v)) }
    public func textStroke(_ v: TextStroke) -> Self { _style(.textStroke(v)) }
    public func backgroundAttachment(_ v: BackgroundAttachment) -> Self { _style(.backgroundAttachment(v)) }
    public func backgroundOrigin(_ v: BackgroundOrigin) -> Self { _style(.backgroundOrigin(v)) }
    public func backgroundBlendMode(_ v: BlendMode) -> Self { _style(.backgroundBlendMode(v)) }
    public func backgroundPosition(_ v: BackgroundPosition) -> Self { _style(.backgroundPosition(v)) }
    public func backgroundSize(_ v: BackgroundSize) -> Self { _style(.backgroundSize(v)) }
    public func outlineColor(_ v: CSSColor) -> Self { _style(.outlineColor(v)) }
    public func borderSpacing(_ h: CSSLength, _ v: CSSLength? = nil) -> Self { _style(.borderSpacing(h, v)) }

    // Motion 3D + scroll/flex tail + multicol + SVG + counters
    public func transformStyle(_ v: TransformStyle) -> Self { _style(.transformStyle(v)) }
    public func perspective(_ v: CSSLength) -> Self { _style(.perspective(v)) }
    public func backfaceVisibility(_ v: BackfaceVisibility) -> Self { _style(.backfaceVisibility(v)) }
    public func willChange(_ hints: WillChange...) -> Self {
        guard let d = StyleDeclaration.willChange(hints) else { return self }
        return _style(d)
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
        copy._attributes.addPendingRule(rule)
        return copy
    }
    public func transitionDelay(_ v: CSSDuration) -> Self { _style(.transitionDelay(v)) }
    public func contentVisibility(_ v: ContentVisibility) -> Self { _style(.contentVisibility(v)) }
    public func containIntrinsicSize(_ v: CSSLength) -> Self { _style(.containIntrinsicSize(v)) }
    public func containIntrinsicSize(_ w: CSSLength, _ h: CSSLength) -> Self { _style(.containIntrinsicSize(w, h)) }
    public func scrollSnapStop(_ v: ScrollSnapStop) -> Self { _style(.scrollSnapStop(v)) }
    public func scrollMargin(_ v: CSSLength) -> Self { _style(.scrollMargin(v)) }
    public func scrollMargin(_ side: Side, _ v: CSSLength) -> Self { _style(.scrollMargin(side, v)) }
    public func placeSelf(_ align: AlignItems, _ justify: JustifySelf) -> Self { _style(.placeSelf(align, justify)) }
    public func flex(_ v: FlexShorthand) -> Self { _style(.flex(v)) }
    public func flex(_ grow: Double) -> Self { _style(.flex(grow)) }
    public func flexFlow(_ direction: FlexDirection, _ wrap: FlexWrap) -> Self { _style(.flexFlow(direction, wrap)) }
    public func content(_ v: String) -> Self {
        guard let d = StyleDeclaration.content(v) else { return self }
        return _style(d)
    }
    public func columnCount(_ v: Int) -> Self { _style(.columnCount(v)) }
    public func columnWidth(_ v: CSSLength) -> Self { _style(.columnWidth(v)) }
    public func scrollbarWidth(_ v: ScrollbarWidth) -> Self { _style(.scrollbarWidth(v)) }
    public func scrollbarColor(_ thumb: CSSColor, _ track: CSSColor) -> Self { _style(.scrollbarColor(thumb, track)) }
    public func tapHighlightColor(_ v: CSSColor) -> Self { _style(.tapHighlightColor(v)) }
    public func fill(_ v: CSSColor) -> Self { _style(.fill(v)) }
    public func stroke(_ v: CSSColor) -> Self { _style(.stroke(v)) }
    public func strokeWidth(_ v: CSSLength) -> Self { _style(.strokeWidth(v)) }
    public func counterReset(_ actions: CounterAction...) -> Self {
        guard let d = StyleDeclaration.counterReset(actions) else { return self }
        return _style(d)
    }
    public func counterIncrement(_ actions: CounterAction...) -> Self {
        guard let d = StyleDeclaration.counterIncrement(actions) else { return self }
        return _style(d)
    }
    public func counterSet(_ actions: CounterAction...) -> Self {
        guard let d = StyleDeclaration.counterSet(actions) else { return self }
        return _style(d)
    }
}
