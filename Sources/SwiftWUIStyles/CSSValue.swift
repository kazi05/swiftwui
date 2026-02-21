// CSSValue.swift - Type-safe CSS value enums

// MARK: - Display

public enum Display: String, Sendable {
    case block, inline, flex, grid, none
    case inlineBlock = "inline-block"
    case inlineFlex = "inline-flex"
    case inlineGrid = "inline-grid"
    case contents
    case table
    case tableRow = "table-row"
    case tableCell = "table-cell"
}

// MARK: - Position

public enum Position: String, Sendable {
    case `static`, relative, absolute, fixed, sticky
}

// MARK: - Flexbox

public enum FlexDirection: String, Sendable {
    case row, column
    case rowReverse = "row-reverse"
    case columnReverse = "column-reverse"
}

public enum FlexWrap: String, Sendable {
    case nowrap, wrap
    case wrapReverse = "wrap-reverse"
}

public enum JustifyContent: String, Sendable {
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center
    case spaceBetween = "space-between"
    case spaceAround = "space-around"
    case spaceEvenly = "space-evenly"
    case start, end
    case stretch
}

public enum AlignItems: String, Sendable {
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center, stretch, baseline
    case start, end
}

public enum AlignSelf: String, Sendable {
    case auto
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center, stretch, baseline
}

// MARK: - Grid

public enum GridAutoFlow: String, Sendable {
    case row, column
    case rowDense = "row dense"
    case columnDense = "column dense"
}

// MARK: - Text

public enum TextAlign: String, Sendable {
    case left, right, center, justify, start, end
}

public enum TextDecoration: String, Sendable {
    case none, underline, overline, lineThrough = "line-through"
}

public enum TextTransform: String, Sendable {
    case none, uppercase, lowercase, capitalize
}

public enum WhiteSpace: String, Sendable {
    case normal, nowrap, pre
    case preWrap = "pre-wrap"
    case preLine = "pre-line"
    case breakSpaces = "break-spaces"
}

public enum WordBreak: String, Sendable {
    case normal
    case breakAll = "break-all"
    case keepAll = "keep-all"
    case breakWord = "break-word"
}

// MARK: - Font

public enum FontWeight: Sendable {
    case normal, bold, lighter, bolder
    case w100, w200, w300, w400, w500, w600, w700, w800, w900

    public var cssValue: String {
        switch self {
        case .normal: return "normal"
        case .bold: return "bold"
        case .lighter: return "lighter"
        case .bolder: return "bolder"
        case .w100: return "100"
        case .w200: return "200"
        case .w300: return "300"
        case .w400: return "400"
        case .w500: return "500"
        case .w600: return "600"
        case .w700: return "700"
        case .w800: return "800"
        case .w900: return "900"
        }
    }
}

public enum FontStyle: String, Sendable {
    case normal, italic, oblique
}

// MARK: - Border

public enum BorderStyle: String, Sendable {
    case none, solid, dashed, dotted, double_, groove, ridge, inset, outset
}

// MARK: - Overflow

public enum Overflow: String, Sendable {
    case visible, hidden, scroll, auto, clip
}

// MARK: - Cursor

public enum Cursor: String, Sendable {
    case auto, default_, pointer, wait, text, move
    case notAllowed = "not-allowed"
    case crosshair, grab, grabbing
    case colResize = "col-resize"
    case rowResize = "row-resize"
    case nResize = "n-resize"
    case eResize = "e-resize"
    case sResize = "s-resize"
    case wResize = "w-resize"
    case zoomIn = "zoom-in"
    case zoomOut = "zoom-out"
    case help, progress, none
}

// MARK: - Box Sizing

public enum BoxSizing: String, Sendable {
    case contentBox = "content-box"
    case borderBox = "border-box"
}

// MARK: - Visibility

public enum Visibility: String, Sendable {
    case visible, hidden, collapse
}

// MARK: - Object Fit

public enum ObjectFit: String, Sendable {
    case contain, cover, fill, none, scaleDown = "scale-down"
}
