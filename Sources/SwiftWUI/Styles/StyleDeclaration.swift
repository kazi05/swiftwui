public struct StyleDeclaration: Equatable, Hashable {
    public let property: String
    public let value: String
    public init(property: String, value: String) {
        self.property = property; self.value = value
    }
}

extension StyleDeclaration {
    // Layout
    public static func display(_ v: Display) -> Self { .init(property: "display", value: v.css) }
    public static func position(_ v: Position) -> Self { .init(property: "position", value: v.css) }
    public static func top(_ v: CSSLength) -> Self { .init(property: "top", value: v.css) }
    public static func right(_ v: CSSLength) -> Self { .init(property: "right", value: v.css) }
    public static func bottom(_ v: CSSLength) -> Self { .init(property: "bottom", value: v.css) }
    public static func left(_ v: CSSLength) -> Self { .init(property: "left", value: v.css) }
    public static func width(_ v: CSSLength) -> Self { .init(property: "width", value: v.css) }
    public static func height(_ v: CSSLength) -> Self { .init(property: "height", value: v.css) }
    public static func minWidth(_ v: CSSLength) -> Self { .init(property: "min-width", value: v.css) }
    public static func minHeight(_ v: CSSLength) -> Self { .init(property: "min-height", value: v.css) }
    public static func maxWidth(_ v: CSSLength) -> Self { .init(property: "max-width", value: v.css) }
    public static func maxHeight(_ v: CSSLength) -> Self { .init(property: "max-height", value: v.css) }
    public static func margin(_ v: CSSLength) -> Self { .init(property: "margin", value: v.css) }
    public static func margin(_ side: Side, _ v: CSSLength) -> Self { .init(property: "margin-\(side.rawValue)", value: v.css) }
    public static func margin(vertical: CSSLength, horizontal: CSSLength) -> Self {
        .init(property: "margin", value: vertical.css + " " + horizontal.css)
    }
    public static func padding(_ v: CSSLength) -> Self { .init(property: "padding", value: v.css) }
    public static func padding(_ side: Side, _ v: CSSLength) -> Self { .init(property: "padding-\(side.rawValue)", value: v.css) }
    public static func padding(vertical: CSSLength, horizontal: CSSLength) -> Self {
        .init(property: "padding", value: vertical.css + " " + horizontal.css)
    }
    public static func gap(_ v: CSSLength) -> Self { .init(property: "gap", value: v.css) }
    public static func overflow(_ v: Overflow) -> Self { .init(property: "overflow", value: v.css) }
    public static func zIndex(_ v: Int) -> Self { .init(property: "z-index", value: String(v)) }
    public static func boxSizing(_ v: BoxSizing) -> Self { .init(property: "box-sizing", value: v.css) }
    // Flex / Grid
    public static func flexDirection(_ v: FlexDirection) -> Self { .init(property: "flex-direction", value: v.css) }
    public static func justifyContent(_ v: JustifyContent) -> Self { .init(property: "justify-content", value: v.css) }
    public static func alignItems(_ v: AlignItems) -> Self { .init(property: "align-items", value: v.css) }
    public static func alignSelf(_ v: AlignItems) -> Self { .init(property: "align-self", value: v.css) }
    public static func flexWrap(_ v: FlexWrap) -> Self { .init(property: "flex-wrap", value: v.css) }
    public static func flexGrow(_ v: Double) -> Self { .init(property: "flex-grow", value: cssNumber(v)) }
    public static func flexShrink(_ v: Double) -> Self { .init(property: "flex-shrink", value: cssNumber(v)) }
    public static func flexBasis(_ v: CSSLength) -> Self { .init(property: "flex-basis", value: v.css) }
    public static func gridTemplateColumns(_ v: String) -> Self { .init(property: "grid-template-columns", value: v) }
    public static func gridTemplateRows(_ v: String) -> Self { .init(property: "grid-template-rows", value: v) }
    // Typography
    public static func fontSize(_ v: CSSLength) -> Self { .init(property: "font-size", value: v.css) }
    public static func fontWeight(_ v: FontWeight) -> Self { .init(property: "font-weight", value: v.css) }
    public static func fontFamily(_ v: String) -> Self { .init(property: "font-family", value: v) }
    public static func lineHeight(_ v: Double) -> Self { .init(property: "line-height", value: cssNumber(v)) }
    public static func textAlign(_ v: TextAlign) -> Self { .init(property: "text-align", value: v.css) }
    public static func textDecoration(_ v: TextDecoration) -> Self { .init(property: "text-decoration", value: v.css) }
    public static func letterSpacing(_ v: CSSLength) -> Self { .init(property: "letter-spacing", value: v.css) }
    public static func color(_ v: CSSColor) -> Self { .init(property: "color", value: v.css) }
    // Box
    public static func background(_ v: CSSColor) -> Self { .init(property: "background", value: v.css) }
    public static func border(_ width: CSSLength, _ style: BorderStyle, _ color: CSSColor) -> Self {
        .init(property: "border", value: width.css + " " + style.css + " " + color.css)
    }
    public static func borderColor(_ v: CSSColor) -> Self { .init(property: "border-color", value: v.css) }
    public static func borderRadius(_ v: CSSLength) -> Self { .init(property: "border-radius", value: v.css) }
    public static func boxShadow(_ v: String) -> Self { .init(property: "box-shadow", value: v) }
    public static func opacity(_ v: Double) -> Self { .init(property: "opacity", value: cssNumber(v)) }
    public static func outline(_ v: Outline) -> Self { .init(property: "outline", value: v.css) }
    // Misc
    public static func cursor(_ v: Cursor) -> Self { .init(property: "cursor", value: v.css) }
    public static func transition(_ v: String) -> Self { .init(property: "transition", value: v) }
    public static func listStyle(_ v: String) -> Self { .init(property: "list-style", value: v) }
}

// Factories. Same shape as above; bundled/variadic ones
// mirror `containerType`'s multi-declaration pattern.
extension StyleDeclaration {
    // Sizing / layout
    public static func overflowX(_ v: Overflow) -> Self { .init(property: "overflow-x", value: v.css) }
    public static func overflowY(_ v: Overflow) -> Self { .init(property: "overflow-y", value: v.css) }
    public static func objectFit(_ v: ObjectFit) -> Self { .init(property: "object-fit", value: v.css) }
    public static func objectPosition(_ v: ObjectPosition) -> Self { .init(property: "object-position", value: v.css) }
    public static func aspectRatio(_ v: AspectRatio) -> Self { .init(property: "aspect-ratio", value: v.css) }
    public static func visibility(_ v: Visibility) -> Self { .init(property: "visibility", value: v.css) }
    // Typography
    public static func whiteSpace(_ v: WhiteSpace) -> Self { .init(property: "white-space", value: v.css) }
    public static func textTransform(_ v: TextTransform) -> Self { .init(property: "text-transform", value: v.css) }
    public static func textOverflow(_ v: TextOverflow) -> Self { .init(property: "text-overflow", value: v.css) }
    /// Bundled: `-webkit-line-clamp` does nothing alone. Emits 5 declarations in order.
    public static func lineClamp(_ lines: Int) -> [StyleDeclaration] {
        [.init(property: "display", value: "-webkit-box"),
         .init(property: "-webkit-box-orient", value: "vertical"),
         .init(property: "overflow", value: "hidden"),
         .init(property: "-webkit-line-clamp", value: String(lines)),
         .init(property: "line-clamp", value: String(lines))]
    }
    // Background / border
    public static func backgroundColor(_ v: CSSColor) -> Self { .init(property: "background-color", value: v.css) }
    public static func backgroundImage(_ v: CSSBackgroundImage) -> Self { .init(property: "background-image", value: v.css) }
    public static func backgroundRepeat(_ v: BackgroundRepeat) -> Self { .init(property: "background-repeat", value: v.css) }
    public static func border(_ side: Side, width: CSSLength = .px(1), style: BorderStyle = .solid, color: CSSColor = .current) -> Self {
        .init(property: "border-\(side.rawValue)", value: width.css + " " + style.css + " " + color.css)
    }
    public static func borderRadius(_ v: BorderRadius) -> Self { .init(property: "border-radius", value: v.css) }
    // Effects / transform — variadic: empty function list → no declaration (nil).
    public static func filter(_ fns: [FilterFunction]) -> Self? {
        guard !fns.isEmpty else { return nil }
        return .init(property: "filter", value: fns.map(\.css).joined(separator: " "))
    }
    public static func transform(_ fns: [TransformFunction]) -> Self? {
        guard !fns.isEmpty else { return nil }
        return .init(property: "transform", value: fns.map(\.css).joined(separator: " "))
    }
    // Interactivity
    public static func pointerEvents(_ v: PointerEvents) -> Self { .init(property: "pointer-events", value: v.css) }
    public static func userSelect(_ v: UserSelect) -> Self { .init(property: "user-select", value: v.css) }
}

// Structural factories (layout / flex / grid). Same shape
// as above; typed values self-render safely — only the raw `String` inputs
// (grid-template-areas, grid-area) carry a CSSSanitize assert-and-drop guard.
extension StyleDeclaration {
    // Sizing / box
    public static func inlineSize(_ v: CSSLength) -> Self { .init(property: "inline-size", value: v.css) }
    public static func blockSize(_ v: CSSLength) -> Self { .init(property: "block-size", value: v.css) }
    public static func inset(_ v: CSSLength) -> Self { .init(property: "inset", value: v.css) }
    public static func marginInline(_ v: CSSLength) -> Self { .init(property: "margin-inline", value: v.css) }
    public static func marginBlock(_ v: CSSLength) -> Self { .init(property: "margin-block", value: v.css) }
    public static func paddingInline(_ v: CSSLength) -> Self { .init(property: "padding-inline", value: v.css) }
    public static func paddingBlock(_ v: CSSLength) -> Self { .init(property: "padding-block", value: v.css) }
    // Gaps — `normal` default = omit; never map `.auto` here.
    public static func rowGap(_ v: CSSLength) -> Self { .init(property: "row-gap", value: v.css) }
    public static func columnGap(_ v: CSSLength) -> Self { .init(property: "column-gap", value: v.css) }
    public static func gap(row: CSSLength, column: CSSLength) -> Self { .init(property: "gap", value: row.css + " " + column.css) }
    public static func order(_ v: Int) -> Self { .init(property: "order", value: String(v)) }
    // Flex / grid alignment — dedicated justify-axis enums, never AlignItems.
    public static func justifyItems(_ v: JustifyItems) -> Self { .init(property: "justify-items", value: v.css) }
    public static func justifySelf(_ v: JustifySelf) -> Self { .init(property: "justify-self", value: v.css) }
    public static func alignContent(_ v: AlignContent) -> Self { .init(property: "align-content", value: v.css) }
    public static func placeContent(_ align: AlignContent, _ justify: JustifyContent) -> Self { .init(property: "place-content", value: align.css + " " + justify.css) }
    public static func placeItems(_ align: AlignItems, _ justify: JustifyItems) -> Self { .init(property: "place-items", value: align.css + " " + justify.css) }
    // Grid item placement — GridLine self-renders/sanitizes.
    public static func gridAutoFlow(_ v: GridAutoFlow) -> Self { .init(property: "grid-auto-flow", value: v.css) }
    public static func gridColumnStart(_ v: GridLine) -> Self { .init(property: "grid-column-start", value: v.css) }
    public static func gridColumnEnd(_ v: GridLine) -> Self { .init(property: "grid-column-end", value: v.css) }
    public static func gridRowStart(_ v: GridLine) -> Self { .init(property: "grid-row-start", value: v.css) }
    public static func gridRowEnd(_ v: GridLine) -> Self { .init(property: "grid-row-end", value: v.css) }
    public static func gridColumn(_ start: GridLine, _ end: GridLine? = nil) -> Self {
        .init(property: "grid-column", value: end.map { start.css + " / " + $0.css } ?? start.css)
    }
    public static func gridRow(_ start: GridLine, _ end: GridLine? = nil) -> Self {
        .init(property: "grid-row", value: end.map { start.css + " / " + $0.css } ?? start.css)
    }
    /// Assert-and-drop: raw value must be rule-safe, else nil (no declaration).
    public static func gridTemplateAreas(_ v: String) -> Self? {
        guard CSSSanitize.isSafeValue(v) else {
            assertionFailure("invalid grid-template-areas value: \(v)")
            return nil
        }
        return .init(property: "grid-template-areas", value: v)
    }
    /// Assert-and-drop: name must be a CSS ident, else nil (no declaration).
    public static func gridArea(_ name: String) -> Self? {
        guard CSSSanitize.isValidIdent(name) else {
            assertionFailure("invalid grid-area ident: \(name)")
            return nil
        }
        return .init(property: "grid-area", value: name)
    }
}

// Typography + background/border factories. Typed values self-render;
// only `ListStyleType.custom` carries its own CSSSanitize guard inside `.css`.
extension StyleDeclaration {
    // Typography
    public static func fontStyle(_ v: FontStyle) -> Self { .init(property: "font-style", value: v.css) }
    public static func textDecorationLine(_ v: TextDecorationLine) -> Self { .init(property: "text-decoration-line", value: v.css) }
    public static func textDecorationColor(_ v: CSSColor) -> Self { .init(property: "text-decoration-color", value: v.css) }
    public static func textDecorationStyle(_ v: TextDecorationStyle) -> Self { .init(property: "text-decoration-style", value: v.css) }
    public static func textDecorationThickness(_ v: CSSLength) -> Self { .init(property: "text-decoration-thickness", value: v.css) }
    public static func textIndent(_ v: CSSLength) -> Self { .init(property: "text-indent", value: v.css) }
    /// Variadic: empty shadow list → no declaration (nil). Uses `textShadowCSS` (no spread/inset).
    public static func textShadow(_ shadows: [Shadow]) -> Self? {
        guard !shadows.isEmpty else { return nil }
        return .init(property: "text-shadow", value: shadows.map(\.textShadowCSS).joined(separator: ", "))
    }
    public static func wordBreak(_ v: WordBreak) -> Self { .init(property: "word-break", value: v.css) }
    public static func overflowWrap(_ v: OverflowWrap) -> Self { .init(property: "overflow-wrap", value: v.css) }
    public static func verticalAlign(_ v: VerticalAlign) -> Self { .init(property: "vertical-align", value: v.css) }
    public static func lineHeight(_ v: CSSLength) -> Self { .init(property: "line-height", value: v.css) }
    public static func listStyleType(_ v: ListStyleType) -> Self { .init(property: "list-style-type", value: v.css) }
    public static func textWrap(_ v: TextWrap) -> Self { .init(property: "text-wrap", value: v.css) }
    public static func fontVariantNumeric(_ v: FontVariantNumeric) -> Self { .init(property: "font-variant-numeric", value: v.css) }
    // Background / border
    /// Bundled: the prefixed prop makes `.text` gradient-text work in Safari. Both declarations, in order.
    public static func backgroundClip(_ v: BackgroundClip) -> [StyleDeclaration] {
        [.init(property: "-webkit-background-clip", value: v.css),
         .init(property: "background-clip", value: v.css)]
    }
    public static func borderWidth(_ v: CSSLength) -> Self { .init(property: "border-width", value: v.css) }
    public static func borderWidth(_ side: Side, _ v: CSSLength) -> Self { .init(property: "border-\(side.rawValue)-width", value: v.css) }
    public static func borderStyle(_ v: BorderStyle) -> Self { .init(property: "border-style", value: v.css) }
    public static func borderStyle(_ side: Side, _ v: BorderStyle) -> Self { .init(property: "border-\(side.rawValue)-style", value: v.css) }
    public static func borderColor(_ side: Side, _ v: CSSColor) -> Self { .init(property: "border-\(side.rawValue)-color", value: v.css) }
    public static func outlineOffset(_ v: CSSLength) -> Self { .init(property: "outline-offset", value: v.css) }
    public static func outlineWidth(_ v: CSSLength) -> Self { .init(property: "outline-width", value: v.css) }
    public static func outlineStyle(_ v: OutlineStyle) -> Self { .init(property: "outline-style", value: v.css) }
    /// Variadic: empty shadow list → no declaration (nil). Uses `boxShadowCSS` (spread/inset honored).
    public static func boxShadow(_ shadows: [Shadow]) -> Self? {
        guard !shadows.isEmpty else { return nil }
        return .init(property: "box-shadow", value: shadows.map(\.boxShadowCSS).joined(separator: ", "))
    }
    public static func mixBlendMode(_ v: BlendMode) -> Self { .init(property: "mix-blend-mode", value: v.css) }
}

// Effects/motion + interactivity/misc factories. Typed values self-render;
// only the raw `String` transition-property and `ClipPath.custom` carry a
// CSSSanitize guard. Bundled `appearance` mirrors `backgroundClip`.
extension StyleDeclaration {
    // Effects / motion — variadic: empty function list → no declaration (nil).
    public static func backdropFilter(_ fns: [FilterFunction]) -> Self? {
        guard !fns.isEmpty else { return nil }
        return .init(property: "backdrop-filter", value: fns.map(\.css).joined(separator: " "))
    }
    public static func clipPath(_ v: ClipPath) -> Self { .init(property: "clip-path", value: v.css) }
    /// The `property` name must be rule-safe, else nil (no declaration); asserts in debug.
    public static func transition(property: String, duration: CSSDuration, timingFunction: TimingFunction = .ease, delay: CSSDuration = .ms(0)) -> Self? {
        guard CSSSanitize.isSafeValue(property) else {
            assertionFailure("unsafe transition property: \(property)")
            return nil
        }
        return .init(property: "transition", value: "\(property) \(duration.css) \(timingFunction.css) \(delay.css)")
    }
    public static func transitionDuration(_ v: CSSDuration) -> Self { .init(property: "transition-duration", value: v.css) }
    public static func transitionTimingFunction(_ v: TimingFunction) -> Self { .init(property: "transition-timing-function", value: v.css) }
    // Interactivity / misc
    public static func touchAction(_ v: TouchAction) -> Self { .init(property: "touch-action", value: v.css) }
    public static func scrollBehavior(_ v: ScrollBehavior) -> Self { .init(property: "scroll-behavior", value: v.css) }
    public static func scrollSnapType(_ v: ScrollSnapType) -> Self { .init(property: "scroll-snap-type", value: v.css) }
    public static func scrollSnapAlign(_ v: ScrollSnapAlign) -> Self { .init(property: "scroll-snap-align", value: v.css) }
    public static func scrollPadding(_ v: CSSLength) -> Self { .init(property: "scroll-padding", value: v.css) }
    public static func scrollPadding(_ side: Side, _ v: CSSLength) -> Self { .init(property: "scroll-padding-\(side.rawValue)", value: v.css) }
    public static func overscrollBehavior(_ v: OverscrollBehavior) -> Self { .init(property: "overscroll-behavior", value: v.css) }
    public static func overscrollBehaviorX(_ v: OverscrollBehavior) -> Self { .init(property: "overscroll-behavior-x", value: v.css) }
    public static func overscrollBehaviorY(_ v: OverscrollBehavior) -> Self { .init(property: "overscroll-behavior-y", value: v.css) }
    public static func resize(_ v: Resize) -> Self { .init(property: "resize", value: v.css) }
    /// Bundled: the prefixed prop makes form-control resets work in Safari. Both declarations, in order.
    public static func appearance(_ v: Appearance) -> [StyleDeclaration] {
        [.init(property: "-webkit-appearance", value: v.css),
         .init(property: "appearance", value: v.css)]
    }
    public static func accentColor(_ v: CSSColor) -> Self { .init(property: "accent-color", value: v.css) }
    public static func listStylePosition(_ v: ListStylePosition) -> Self { .init(property: "list-style-position", value: v.css) }
    public static func borderCollapse(_ v: BorderCollapse) -> Self { .init(property: "border-collapse", value: v.css) }
    public static func tableLayout(_ v: TableLayout) -> Self { .init(property: "table-layout", value: v.css) }
    public static func colorSchemeHint(_ v: ColorSchemeHint) -> Self { .init(property: "color-scheme", value: v.css) }
    public static func breakInside(_ v: BreakInside) -> Self { .init(property: "break-inside", value: v.css) }
    public static func breakBefore(_ v: BreakBetween) -> Self { .init(property: "break-before", value: v.css) }
    public static func breakAfter(_ v: BreakBetween) -> Self { .init(property: "break-after", value: v.css) }
}

// Logical box props + font sub-props + background/border tail. Typed values
// self-render; `fontSmoothing` is bundled (mirrors `backgroundClip`).
extension StyleDeclaration {
    // Logical box
    public static func marginInlineStart(_ v: CSSLength) -> Self { .init(property: "margin-inline-start", value: v.css) }
    public static func marginInlineEnd(_ v: CSSLength) -> Self { .init(property: "margin-inline-end", value: v.css) }
    public static func marginBlockStart(_ v: CSSLength) -> Self { .init(property: "margin-block-start", value: v.css) }
    public static func marginBlockEnd(_ v: CSSLength) -> Self { .init(property: "margin-block-end", value: v.css) }
    public static func paddingInlineStart(_ v: CSSLength) -> Self { .init(property: "padding-inline-start", value: v.css) }
    public static func paddingInlineEnd(_ v: CSSLength) -> Self { .init(property: "padding-inline-end", value: v.css) }
    public static func paddingBlockStart(_ v: CSSLength) -> Self { .init(property: "padding-block-start", value: v.css) }
    public static func paddingBlockEnd(_ v: CSSLength) -> Self { .init(property: "padding-block-end", value: v.css) }
    public static func insetInlineStart(_ v: CSSLength) -> Self { .init(property: "inset-inline-start", value: v.css) }
    public static func insetInlineEnd(_ v: CSSLength) -> Self { .init(property: "inset-inline-end", value: v.css) }
    public static func insetBlockStart(_ v: CSSLength) -> Self { .init(property: "inset-block-start", value: v.css) }
    public static func insetBlockEnd(_ v: CSSLength) -> Self { .init(property: "inset-block-end", value: v.css) }
    public static func minInlineSize(_ v: CSSLength) -> Self { .init(property: "min-inline-size", value: v.css) }
    public static func maxInlineSize(_ v: CSSLength) -> Self { .init(property: "max-inline-size", value: v.css) }
    public static func minBlockSize(_ v: CSSLength) -> Self { .init(property: "min-block-size", value: v.css) }
    public static func maxBlockSize(_ v: CSSLength) -> Self { .init(property: "max-block-size", value: v.css) }
    // Display / flow
    public static func float(_ v: CSSFloat) -> Self { .init(property: "float", value: v.css) }
    public static func clear(_ v: Clear) -> Self { .init(property: "clear", value: v.css) }
    public static func isolation(_ v: Isolation) -> Self { .init(property: "isolation", value: v.css) }
    // Font / text
    public static func fontVariant(_ v: FontVariant) -> Self { .init(property: "font-variant", value: v.css) }
    public static func fontStretch(_ v: FontStretch) -> Self { .init(property: "font-stretch", value: v.css) }
    public static func fontOpticalSizing(_ v: FontOpticalSizing) -> Self { .init(property: "font-optical-sizing", value: v.css) }
    /// Bundled: `-webkit-font-smoothing` always; `font-smooth` only for `auto`/`none`
    /// (`antialiased`/`subpixel-antialiased` are invalid on the unprefixed prop).
    public static func fontSmoothing(_ v: FontSmoothing) -> [StyleDeclaration] {
        var decls: [StyleDeclaration] = [.init(property: "-webkit-font-smoothing", value: v.css)]
        if v == .auto || v == .none { decls.append(.init(property: "font-smooth", value: v.css)) }
        return decls
    }
    public static func textAlignLast(_ v: TextAlignLast) -> Self { .init(property: "text-align-last", value: v.css) }
    public static func textUnderlineOffset(_ v: CSSLength) -> Self { .init(property: "text-underline-offset", value: v.css) }
    public static func wordSpacing(_ v: CSSLength) -> Self { .init(property: "word-spacing", value: v.css) }
    public static func hyphens(_ v: Hyphens) -> Self { .init(property: "hyphens", value: v.css) }
    public static func direction(_ v: Direction) -> Self { .init(property: "direction", value: v.css) }
    public static func caretColor(_ v: CaretColor) -> Self { .init(property: "caret-color", value: v.css) }
    public static func textStroke(_ v: TextStroke) -> Self { .init(property: "-webkit-text-stroke", value: v.css) }
    // Background / border
    public static func backgroundAttachment(_ v: BackgroundAttachment) -> Self { .init(property: "background-attachment", value: v.css) }
    public static func backgroundOrigin(_ v: BackgroundOrigin) -> Self { .init(property: "background-origin", value: v.css) }
    public static func backgroundBlendMode(_ v: BlendMode) -> Self { .init(property: "background-blend-mode", value: v.css) }
    public static func backgroundPosition(_ v: BackgroundPosition) -> Self { .init(property: "background-position", value: v.css) }
    public static func backgroundSize(_ v: BackgroundSize) -> Self { .init(property: "background-size", value: v.css) }
    public static func outlineColor(_ v: CSSColor) -> Self { .init(property: "outline-color", value: v.css) }
    public static func borderSpacing(_ h: CSSLength, _ v: CSSLength? = nil) -> Self {
        .init(property: "border-spacing", value: v.map { h.css + " " + $0.css } ?? h.css)
    }
}

// Motion 3D + scroll/flex tail + multicol + SVG + counters. Typed values self-render;
// the raw `String` inputs (`content`, `WillChange.property`, `CounterAction.name`) carry
// a CSSSanitize guard. The variadic `willChange`/`counter*` collapse an empty list to nil.
extension StyleDeclaration {
    // Motion / 3D
    public static func transformStyle(_ v: TransformStyle) -> Self { .init(property: "transform-style", value: v.css) }
    public static func perspective(_ v: CSSLength) -> Self { .init(property: "perspective", value: v.css) }
    public static func backfaceVisibility(_ v: BackfaceVisibility) -> Self { .init(property: "backface-visibility", value: v.css) }
    public static func willChange(_ hints: [WillChange]) -> Self? {
        guard !hints.isEmpty else { return nil }
        return .init(property: "will-change", value: hints.map(\.css).joined(separator: ", "))
    }
    public static func transitionDelay(_ v: CSSDuration) -> Self { .init(property: "transition-delay", value: v.css) }
    /// All six operands are always emitted (no omit-if-default) so the value is
    /// a pure function of the parameters. `name` is a `Keyframes.cssName`,
    /// which is ident-validated at construction.
    public static func animation(name: String, duration: CSSDuration,
                                 timingFunction: TimingFunction, delay: CSSDuration,
                                 iterations: AnimationIterations,
                                 direction: AnimationDirection,
                                 fillMode: AnimationFillMode) -> Self {
        .init(property: "animation",
              value: [name, duration.css, timingFunction.css, delay.css,
                      iterations.css, direction.css, fillMode.css].joined(separator: " "))
    }
    // Layout perf / scroll / flex
    public static func contentVisibility(_ v: ContentVisibility) -> Self { .init(property: "content-visibility", value: v.css) }
    public static func containIntrinsicSize(_ v: CSSLength) -> Self { .init(property: "contain-intrinsic-size", value: v.css) }
    public static func containIntrinsicSize(_ w: CSSLength, _ h: CSSLength) -> Self { .init(property: "contain-intrinsic-size", value: w.css + " " + h.css) }
    public static func scrollSnapStop(_ v: ScrollSnapStop) -> Self { .init(property: "scroll-snap-stop", value: v.css) }
    public static func scrollMargin(_ v: CSSLength) -> Self { .init(property: "scroll-margin", value: v.css) }
    public static func scrollMargin(_ side: Side, _ v: CSSLength) -> Self { .init(property: "scroll-margin-\(side.rawValue)", value: v.css) }
    public static func placeSelf(_ align: AlignItems, _ justify: JustifySelf) -> Self { .init(property: "place-self", value: align.css + " " + justify.css) }
    public static func flex(_ v: FlexShorthand) -> Self { .init(property: "flex", value: v.css) }
    public static func flex(_ grow: Double) -> Self { .init(property: "flex", value: cssNumber(grow)) }
    public static func flexFlow(_ direction: FlexDirection, _ wrap: FlexWrap) -> Self { .init(property: "flex-flow", value: direction.css + " " + wrap.css) }
    // Misc / multicol / SVG / counters
    /// The value must be rule-safe (user supplies its quotes), else nil; asserts in debug.
    public static func content(_ v: String) -> Self? {
        guard CSSSanitize.isSafeValue(v) else {
            assertionFailure("unsafe content value: \(v)")
            return nil
        }
        return .init(property: "content", value: v)
    }
    public static func columnCount(_ v: Int) -> Self { .init(property: "column-count", value: String(v)) }
    public static func columnWidth(_ v: CSSLength) -> Self { .init(property: "column-width", value: v.css) }
    public static func scrollbarWidth(_ v: ScrollbarWidth) -> Self { .init(property: "scrollbar-width", value: v.css) }
    public static func scrollbarColor(_ thumb: CSSColor, _ track: CSSColor) -> Self { .init(property: "scrollbar-color", value: thumb.css + " " + track.css) }
    public static func tapHighlightColor(_ v: CSSColor) -> Self { .init(property: "-webkit-tap-highlight-color", value: v.css) }
    public static func fill(_ v: CSSColor) -> Self { .init(property: "fill", value: v.css) }
    public static func stroke(_ v: CSSColor) -> Self { .init(property: "stroke", value: v.css) }
    public static func strokeWidth(_ v: CSSLength) -> Self { .init(property: "stroke-width", value: v.css) }
    public static func counterReset(_ actions: [CounterAction]) -> Self? { counterDeclaration("counter-reset", actions) }
    public static func counterIncrement(_ actions: [CounterAction]) -> Self? { counterDeclaration("counter-increment", actions) }
    public static func counterSet(_ actions: [CounterAction]) -> Self? { counterDeclaration("counter-set", actions) }
    /// Joins each action as `"name value"`; empty list → nil; an invalid name asserts and drops.
    private static func counterDeclaration(_ property: String, _ actions: [CounterAction]) -> Self? {
        guard !actions.isEmpty else { return nil }
        for a in actions where !CSSSanitize.isValidIdent(a.name) {
            assertionFailure("invalid counter name ident: \(a.name)")
            return nil
        }
        return .init(property: property, value: actions.map { "\($0.name) \($0.value)" }.joined(separator: " "))
    }

    /// `view-transition-name` (view-transitions spec §6). Returns nil for a name
    /// that must not reach CSS: a non-ident (the value is serialized unquoted
    /// into `style="…"` by HTMLRenderer, where a `;` would inject a sibling
    /// declaration), `root` (the document element's own name — duplicating it
    /// makes the browser skip every transition in the app), or the UA-reserved
    /// `-ua-` prefix. Validate-and-drop with no assert, same reasoning as
    /// `Keyframes.init`: the guard must hold in release, and an assert makes the
    /// regression test unrunnable under debug.
    public static func viewTransitionName(_ name: String) -> Self? {
        guard CSSSanitize.isValidIdent(name), name != "root", !name.hasPrefix("-ua-") else { return nil }
        return .init(property: "view-transition-name", value: name)
    }
}
