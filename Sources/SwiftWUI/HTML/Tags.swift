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
