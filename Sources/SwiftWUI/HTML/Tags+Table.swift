// MARK: - Table Containers

public struct Table<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "table" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}

public struct Caption<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "caption" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}

public struct Thead<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "thead" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}

public struct Tbody<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "tbody" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}

public struct Tfoot<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "tfoot" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}

public struct Tr<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "tr" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}

public struct Th<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "th" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(colspan: Int? = nil, rowspan: Int? = nil, scope: String? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let colspan { _attributes.set("colspan", String(colspan)) }
        if let rowspan { _attributes.set("rowspan", String(rowspan)) }
        _attributes.set("scope", scope)
        self.content = content()
    }
}

public struct Td<Content: Tag>: _HTMLContainerTag {      // same minus scope
    public static var tagName: String { "td" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(colspan: Int? = nil, rowspan: Int? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let colspan { _attributes.set("colspan", String(colspan)) }
        if let rowspan { _attributes.set("rowspan", String(rowspan)) }
        self.content = content()
    }
}

public struct Colgroup<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "colgroup" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(span: Int? = nil, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let span { _attributes.set("span", String(span)) }
        self.content = content()
    }
}

public struct Col: _HTMLVoidTag {
    public static var tagName: String { "col" }
    public var _attributes: _AttributeBag
    public init(span: Int? = nil, id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let span { _attributes.set("span", String(span)) }
    }
}

// MARK: - Select / Option / Optgroup

public struct Option<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "option" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(value: String? = nil, selected: Bool = false, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("value", value)
        if selected { _attributes.set("selected", "") }
        if disabled { _attributes.set("disabled", "") }
        self.content = content()
    }
}
extension Option where Content == Text {
    public init(_ label: String, value: String? = nil, selected: Bool = false,
                disabled: Bool = false, id: String? = nil, class classes: String? = nil) {
        self.init(value: value, selected: selected, disabled: disabled,
                  id: id, class: classes) { Text(label) }
    }
}

public struct Optgroup<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "optgroup" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(label: String, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("label", label)
        if disabled { _attributes.set("disabled", "") }
        self.content = content()
    }
}

public struct Select<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "select" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(name: String? = nil, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("name", name)
        if disabled { _attributes.set("disabled", "") }
        self.content = content()
    }
    /// Controlled select (Input(value:) pattern): DOM `value` property tracks
    /// the binding; every change event writes it back.
    public init(value: Binding<String>, name: String? = nil, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onChange: ((ChangeEvent) -> Void)? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("name", name)
        if disabled { _attributes.set("disabled", "") }
        _attributes.setProperty("value", .string(value.wrappedValue))
        _attributes.addHandler(.change, payload: ChangeEvent.self) { e in
            value.wrappedValue = e.value
            onChange?(e)
        }
        self.content = content()
    }
}

// MARK: - Remaining form tags

public struct Fieldset<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "fieldset" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(disabled: Bool = false, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if disabled { _attributes.set("disabled", "") }
        self.content = content()
    }
}

public struct Legend<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "legend" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}

public struct Datalist<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "datalist" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}

public struct Output<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "output" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(for htmlFor: String? = nil, name: String? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("for", htmlFor)
        _attributes.set("name", name)
        self.content = content()
    }
}

public struct Progress<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "progress" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(value: Double? = nil, max: Double? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let value { _attributes.set("value", String(value)) }
        if let max { _attributes.set("max", String(max)) }
        self.content = content()
    }
}

public struct Meter<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "meter" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(value: Double, min: Double? = nil, max: Double? = nil,
                low: Double? = nil, high: Double? = nil, optimum: Double? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("value", String(value))
        if let min { _attributes.set("min", String(min)) }
        if let max { _attributes.set("max", String(max)) }
        if let low { _attributes.set("low", String(low)) }
        if let high { _attributes.set("high", String(high)) }
        if let optimum { _attributes.set("optimum", String(optimum)) }
        self.content = content()
    }
}
