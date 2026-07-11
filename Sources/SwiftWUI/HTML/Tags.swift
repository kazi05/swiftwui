public struct Div<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "div" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Div where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Span<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "span" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Span where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct P<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "p" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension P where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct H1<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "h1" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension H1 where Content == Text {
    public init(_ text: String, id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { Text(text) }
    }
}

public enum ButtonType: String { case button, submit, reset }

public struct Button<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "button" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(type: ButtonType = .button, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onClick: (() -> Void)? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("type", type.rawValue)
        if disabled { _attributes.set("disabled", "") }
        if let onClick { _attributes.addHandler(.click, onClick) }
        self.content = content()
    }
}
extension Button where Content == Text {
    public init(_ title: String, type: ButtonType = .button, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onClick: @escaping () -> Void) {
        self.init(type: type, disabled: disabled, id: id, class: classes,
                  onClick: onClick) { Text(title) }
    }
}

public enum InputType: String {
    case text, number, email, password, search, url, tel, checkbox, radio, hidden, date, file
}

/// Void element; attributes only — event payloads are phase 2 (spec decision 6).
public struct Input: _HTMLVoidTag {
    public static var tagName: String { "input" }
    public var _attributes: _AttributeBag
    public init(type: InputType = .text, name: String? = nil, value: String? = nil,
                placeholder: String? = nil, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("type", type.rawValue)
        _attributes.set("name", name)
        _attributes.set("value", value)
        _attributes.set("placeholder", placeholder)
        if disabled { _attributes.set("disabled", "") }
    }
}

extension Input {
    /// Controlled text input: DOM `value` property tracks the binding; every
    /// input event writes it back (spec §7).
    public init(type: InputType = .text, value: Binding<String>,
                name: String? = nil,
                placeholder: String? = nil, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onInput: ((InputEvent) -> Void)? = nil,
                onKeyDown: ((KeyEvent) -> Void)? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("type", type.rawValue)
        _attributes.set("name", name)
        _attributes.set("placeholder", placeholder)
        if disabled { _attributes.set("disabled", "") }
        _attributes.setProperty("value", .string(value.wrappedValue))
        _attributes.addHandler(.input, payload: InputEvent.self) { e in
            value.wrappedValue = e.value
            onInput?(e)
        }
        if let onKeyDown {
            _attributes.addHandler(.keydown, payload: KeyEvent.self, onKeyDown)
        }
    }

    /// Controlled checkbox.
    public init(checked: Binding<Bool>, name: String? = nil, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onChange: ((ChangeEvent) -> Void)? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("type", "checkbox")
        _attributes.set("name", name)
        if disabled { _attributes.set("disabled", "") }
        _attributes.setProperty("checked", .bool(checked.wrappedValue))
        _attributes.addHandler(.change, payload: ChangeEvent.self) { e in
            checked.wrappedValue = e.checked
            onChange?(e)
        }
    }
}

// MARK: - H2–H6 (Headings)

public struct H2<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "h2" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension H2 where Content == Text {
    public init(_ text: String, id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { Text(text) }
    }
}

public struct H3<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "h3" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension H3 where Content == Text {
    public init(_ text: String, id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { Text(text) }
    }
}

public struct H4<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "h4" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension H4 where Content == Text {
    public init(_ text: String, id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { Text(text) }
    }
}

public struct H5<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "h5" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension H5 where Content == Text {
    public init(_ text: String, id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { Text(text) }
    }
}

public struct H6<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "h6" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension H6 where Content == Text {
    public init(_ text: String, id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { Text(text) }
    }
}

// MARK: - Semantic Containers

public struct Main<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "main" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Main where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Header<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "header" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Header where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Footer<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "footer" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Footer where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Nav<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "nav" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Nav where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Section<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "section" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Section where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Article<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "article" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Article where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

// MARK: - List Containers

public struct Ul<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "ul" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Ul where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Ol<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "ol" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Ol where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Li<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "li" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Li where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

// MARK: - Form Containers

public struct Form<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "form" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Form where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

extension Form {
    /// Submit-handling form. The backend ALWAYS calls preventDefault() for
    /// submit events (spec D10) — no page reloads.
    public init(onSubmit: @escaping (SubmitEvent) -> Void,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.addHandler(.submit, payload: SubmitEvent.self, onSubmit)
        self.content = content()
    }
}

public struct Label<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "label" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Label where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

// MARK: - Text Formatting

public struct Strong<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "strong" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Strong where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Em<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "em" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Em where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Code<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "code" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Code where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Pre<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "pre" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Pre where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

// MARK: - Textarea

public struct Textarea<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "textarea" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}

extension Textarea where Content == EmptyTag {
    /// Controlled textarea (text-only mode — phase-1 review backlog item 3).
    public init(text: Binding<String>, id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.setProperty("value", .string(text.wrappedValue))
        _attributes.addHandler(.input, payload: InputEvent.self) { text.wrappedValue = $0.value }
        content = EmptyTag()
    }
}

// MARK: - Link Target

public enum LinkTarget: String {
    case blank = "_blank", current = "_self", parent = "_parent", top = "_top"
}

// MARK: - Anchor & Image

public struct A<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "a" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(href: String, target: LinkTarget? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("href", HTMLEscaping.sanitizeURL(href))
        if let target { _attributes.set("target", target.rawValue) }
        self.content = content()
    }
}
extension A where Content == EmptyTag {
    public init(href: String, target: LinkTarget? = nil, id: String? = nil, class classes: String? = nil) {
        self.init(href: href, target: target, id: id, class: classes) { EmptyTag() }
    }
}

public enum ImgLoading: String { case `lazy`, eager }
public enum ImgDecoding: String { case async, sync, auto }

public struct Img: _HTMLVoidTag {
    public static var tagName: String { "img" }
    public var _attributes: _AttributeBag
    /// `srcset` is sanitized per candidate URL (via `sanitizeSrcset`): any
    /// entry with a disallowed scheme drops the whole value to "#".
    public init(src: String, alt: String,
                width: Int? = nil, height: Int? = nil,
                srcset: String? = nil, sizes: String? = nil,
                loading: ImgLoading? = nil, decoding: ImgDecoding? = nil,
                id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("src", HTMLEscaping.sanitizeURL(src))
        _attributes.set("alt", alt)
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
        if let srcset { _attributes.set("srcset", HTMLEscaping.sanitizeSrcset(srcset)) }
        if let sizes { _attributes.set("sizes", sizes) }
        if let loading { _attributes.set("loading", loading.rawValue) }
        if let decoding { _attributes.set("decoding", decoding.rawValue) }
    }
}

// MARK: - Void Elements

public struct Br: _HTMLVoidTag {
    public static var tagName: String { "br" }
    public var _attributes: _AttributeBag
    public init() { _attributes = _AttributeBag() }
}

public struct Hr: _HTMLVoidTag {
    public static var tagName: String { "hr" }
    public var _attributes: _AttributeBag
    public init() { _attributes = _AttributeBag() }
}
