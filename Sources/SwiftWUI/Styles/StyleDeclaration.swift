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
