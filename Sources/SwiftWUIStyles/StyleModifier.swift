// StyleModifier.swift - Type-safe CSS modifiers

import SwiftWUICore

// MARK: - Layout

extension Tag {
    public func display(_ value: Display) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("display", value.rawValue)])
    }

    public func position(_ value: Position) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("position", value.rawValue)])
    }

    public func width(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("width", value.cssValue)])
    }

    public func height(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("height", value.cssValue)])
    }

    public func minWidth(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("min-width", value.cssValue)])
    }

    public func maxWidth(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("max-width", value.cssValue)])
    }

    public func minHeight(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("min-height", value.cssValue)])
    }

    public func maxHeight(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("max-height", value.cssValue)])
    }

    public func top(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("top", value.cssValue)])
    }

    public func right(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("right", value.cssValue)])
    }

    public func bottom(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("bottom", value.cssValue)])
    }

    public func left(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("left", value.cssValue)])
    }
}

// MARK: - Spacing

extension Tag {
    public func padding(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("padding", value.cssValue)])
    }

    public func padding(_ vertical: CSSUnit, _ horizontal: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("padding", "\(vertical.cssValue) \(horizontal.cssValue)")])
    }

    public func paddingTop(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("padding-top", value.cssValue)])
    }

    public func paddingRight(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("padding-right", value.cssValue)])
    }

    public func paddingBottom(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("padding-bottom", value.cssValue)])
    }

    public func paddingLeft(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("padding-left", value.cssValue)])
    }

    public func margin(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("margin", value.cssValue)])
    }

    public func margin(_ vertical: CSSUnit, _ horizontal: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("margin", "\(vertical.cssValue) \(horizontal.cssValue)")])
    }

    public func marginTop(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("margin-top", value.cssValue)])
    }

    public func marginRight(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("margin-right", value.cssValue)])
    }

    public func marginBottom(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("margin-bottom", value.cssValue)])
    }

    public func marginLeft(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("margin-left", value.cssValue)])
    }

    public func gap(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("gap", value.cssValue)])
    }
}

// MARK: - Flexbox

extension Tag {
    public func flexDirection(_ value: FlexDirection) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("flex-direction", value.rawValue)])
    }

    public func flexWrap(_ value: FlexWrap) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("flex-wrap", value.rawValue)])
    }

    public func justifyContent(_ value: JustifyContent) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("justify-content", value.rawValue)])
    }

    public func alignItems(_ value: AlignItems) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("align-items", value.rawValue)])
    }

    public func alignSelf(_ value: AlignSelf) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("align-self", value.rawValue)])
    }

    public func flex(_ grow: Double, _ shrink: Double = 1, _ basis: CSSUnit = .auto) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("flex", "\(grow) \(shrink) \(basis.cssValue)")])
    }

    public func flexGrow(_ value: Double) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("flex-grow", "\(value)")])
    }

    public func flexShrink(_ value: Double) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("flex-shrink", "\(value)")])
    }
}

// MARK: - Colors

extension Tag {
    public func backgroundColor(_ color: CSSColor) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("background-color", color.cssValue)])
    }

    public func foregroundColor(_ color: CSSColor) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("color", color.cssValue)])
    }

    public func opacity(_ value: Double) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("opacity", "\(value)")])
    }
}

// MARK: - Typography

extension Tag {
    public func fontSize(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("font-size", value.cssValue)])
    }

    public func fontWeight(_ value: FontWeight) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("font-weight", value.cssValue)])
    }

    public func fontFamily(_ value: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("font-family", value)])
    }

    public func fontStyle(_ value: FontStyle) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("font-style", value.rawValue)])
    }

    public func lineHeight(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("line-height", value.cssValue)])
    }

    public func textAlign(_ value: TextAlign) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("text-align", value.rawValue)])
    }

    public func textDecoration(_ value: TextDecoration) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("text-decoration", value.rawValue)])
    }

    public func textTransform(_ value: TextTransform) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("text-transform", value.rawValue)])
    }

    public func letterSpacing(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("letter-spacing", value.cssValue)])
    }

    public func whiteSpace(_ value: WhiteSpace) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("white-space", value.rawValue)])
    }

    public func wordBreak(_ value: WordBreak) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("word-break", value.rawValue)])
    }

    public func textIndent(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("text-indent", value.cssValue)])
    }
}

// MARK: - Border

extension Tag {
    public func border(_ width: CSSUnit, _ style: BorderStyle, _ color: CSSColor) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("border", "\(width.cssValue) \(style.rawValue) \(color.cssValue)")])
    }

    public func borderRadius(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("border-radius", value.cssValue)])
    }

    public func borderColor(_ color: CSSColor) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("border-color", color.cssValue)])
    }

    public func borderWidth(_ value: CSSUnit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("border-width", value.cssValue)])
    }

    public func borderStyle(_ value: BorderStyle) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("border-style", value.rawValue)])
    }

    public func borderBottom(_ width: CSSUnit, _ style: BorderStyle, _ color: CSSColor) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("border-bottom", "\(width.cssValue) \(style.rawValue) \(color.cssValue)")])
    }
}

// MARK: - Box Model

extension Tag {
    public func boxSizing(_ value: BoxSizing) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("box-sizing", value.rawValue)])
    }

    public func overflow(_ value: Overflow) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("overflow", value.rawValue)])
    }

    public func overflowX(_ value: Overflow) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("overflow-x", value.rawValue)])
    }

    public func overflowY(_ value: Overflow) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("overflow-y", value.rawValue)])
    }

    public func boxShadow(_ value: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("box-shadow", value)])
    }

    public func zIndex(_ value: Int) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("z-index", "\(value)")])
    }
}

// MARK: - Cursor & Interaction

extension Tag {
    public func cursor(_ value: Cursor) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("cursor", value.rawValue)])
    }

    public func visibility(_ value: Visibility) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("visibility", value.rawValue)])
    }

    public func objectFit(_ value: ObjectFit) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("object-fit", value.rawValue)])
    }
}

// MARK: - Transform & Animation

extension Tag {
    public func transform(_ value: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("transform", value)])
    }

    public func transition(_ value: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("transition", value)])
    }

    public func animation(_ value: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("animation", value)])
    }

    /// Apply a type-safe CSS transition for all properties.
    ///
    /// ```swift
    /// Div { content }
    ///     .animation(.easeInOut(duration: 0.3))
    ///     .opacity(isVisible ? 1 : 0)
    /// ```
    public func animation(_ animation: Animation) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("transition", animation.cssTransitionAll)])
    }

    /// Apply a type-safe enter/exit transition.
    ///
    /// ```swift
    /// if isVisible {
    ///     Div { content }.transition(.opacity)
    /// }
    /// ```
    public func transition(_ transition: TagTransition) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("transition", transition.animation.cssTransitionAll)])
    }
}

// MARK: - Grid

extension Tag {
    public func gridTemplateColumns(_ value: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("grid-template-columns", value)])
    }

    public func gridTemplateRows(_ value: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("grid-template-rows", value)])
    }

    public func gridColumn(_ value: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("grid-column", value)])
    }

    public func gridRow(_ value: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("grid-row", value)])
    }

    public func gridAutoFlow(_ value: GridAutoFlow) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("grid-auto-flow", value.rawValue)])
    }
}

// MARK: - Chaining on ModifiedContent (re-applying modifiers)

extension ModifiedContent {
    public func display(_ value: Display) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("display", value.rawValue)); return copy
    }
    public func position(_ value: Position) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("position", value.rawValue)); return copy
    }
    public func width(_ value: CSSUnit) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("width", value.cssValue)); return copy
    }
    public func height(_ value: CSSUnit) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("height", value.cssValue)); return copy
    }
    public func padding(_ value: CSSUnit) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("padding", value.cssValue)); return copy
    }
    public func padding(_ vertical: CSSUnit, _ horizontal: CSSUnit) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("padding", "\(vertical.cssValue) \(horizontal.cssValue)")); return copy
    }
    public func margin(_ value: CSSUnit) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("margin", value.cssValue)); return copy
    }
    public func gap(_ value: CSSUnit) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("gap", value.cssValue)); return copy
    }
    public func backgroundColor(_ color: CSSColor) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("background-color", color.cssValue)); return copy
    }
    public func foregroundColor(_ color: CSSColor) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("color", color.cssValue)); return copy
    }
    public func fontSize(_ value: CSSUnit) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("font-size", value.cssValue)); return copy
    }
    public func fontWeight(_ value: FontWeight) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("font-weight", value.cssValue)); return copy
    }
    public func border(_ width: CSSUnit, _ bStyle: BorderStyle, _ color: CSSColor) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("border", "\(width.cssValue) \(bStyle.rawValue) \(color.cssValue)")); return copy
    }
    public func borderRadius(_ value: CSSUnit) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("border-radius", value.cssValue)); return copy
    }
    public func cursor(_ value: Cursor) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("cursor", value.rawValue)); return copy
    }
    public func opacity(_ value: Double) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("opacity", "\(value)")); return copy
    }
    public func flexDirection(_ value: FlexDirection) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("flex-direction", value.rawValue)); return copy
    }
    public func justifyContent(_ value: JustifyContent) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("justify-content", value.rawValue)); return copy
    }
    public func alignItems(_ value: AlignItems) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("align-items", value.rawValue)); return copy
    }
    public func textAlign(_ value: TextAlign) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("text-align", value.rawValue)); return copy
    }
    public func overflow(_ value: Overflow) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("overflow", value.rawValue)); return copy
    }
    public func zIndex(_ value: Int) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("z-index", "\(value)")); return copy
    }
    public func transition(_ value: String) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("transition", value)); return copy
    }
    public func transform(_ value: String) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("transform", value)); return copy
    }
    public func boxShadow(_ value: String) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("box-shadow", value)); return copy
    }
    public func lineHeight(_ value: CSSUnit) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("line-height", value.cssValue)); return copy
    }
    public func textDecoration(_ value: TextDecoration) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("text-decoration", value.rawValue)); return copy
    }
    public func animation(_ anim: Animation) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("transition", anim.cssTransitionAll)); return copy
    }
    public func transition(_ trans: TagTransition) -> ModifiedContent<Content> {
        var copy = self; copy.styles.append(("transition", trans.animation.cssTransitionAll)); return copy
    }
}
