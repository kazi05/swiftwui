// Text-level & semantic container tags (phase-5 batch 1).

// MARK: - Plain Containers

public struct Aside<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "aside" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Aside where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Address<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "address" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Address where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Small<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "small" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Small where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Sub<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "sub" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Sub where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Sup<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "sup" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Sup where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Mark<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "mark" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Mark where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Kbd<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "kbd" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Kbd where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Cite<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "cite" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Cite where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Dfn<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "dfn" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Dfn where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Var<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "var" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Var where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Samp<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "samp" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Samp where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct B<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "b" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension B where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct I<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "i" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension I where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct U<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "u" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension U where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct S<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "s" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension S where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Bdi<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "bdi" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Bdi where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Bdo<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "bdo" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Bdo where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Ruby<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "ruby" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Ruby where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Rt<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "rt" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Rt where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Rp<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "rp" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Rp where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Hgroup<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "hgroup" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Hgroup where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Search<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "search" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Search where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Menu<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "menu" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Menu where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Figure<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "figure" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Figure where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Figcaption<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "figcaption" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Figcaption where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Dl<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "dl" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Dl where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Dt<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "dt" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Dt where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

public struct Dd<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "dd" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Dd where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

/// Also used by Task 4's `Details`.
public struct Summary<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "summary" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Summary where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

// MARK: - Typed-Attribute Containers

public struct Blockquote<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "blockquote" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(cite: String? = nil, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let cite { _attributes.set("cite", HTMLEscaping.sanitizeURL(cite)) }
        self.content = content()
    }
}
extension Blockquote where Content == EmptyTag {
    public init(cite: String? = nil, id: String? = nil, class classes: String? = nil) {
        self.init(cite: cite, id: id, class: classes) { EmptyTag() }
    }
}

public struct Q<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "q" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(cite: String? = nil, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let cite { _attributes.set("cite", HTMLEscaping.sanitizeURL(cite)) }
        self.content = content()
    }
}
extension Q where Content == EmptyTag {
    public init(cite: String? = nil, id: String? = nil, class classes: String? = nil) {
        self.init(cite: cite, id: id, class: classes) { EmptyTag() }
    }
}

public struct Time<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "time" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(datetime: String? = nil, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("datetime", datetime)
        self.content = content()
    }
}
extension Time where Content == EmptyTag {
    public init(datetime: String? = nil, id: String? = nil, class classes: String? = nil) {
        self.init(datetime: datetime, id: id, class: classes) { EmptyTag() }
    }
}

public struct Abbr<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "abbr" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(title: String? = nil, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("title", title)
        self.content = content()
    }
}
extension Abbr where Content == EmptyTag {
    public init(title: String? = nil, id: String? = nil, class classes: String? = nil) {
        self.init(title: title, id: id, class: classes) { EmptyTag() }
    }
}

public struct Del<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "del" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(cite: String? = nil, datetime: String? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let cite { _attributes.set("cite", HTMLEscaping.sanitizeURL(cite)) }
        _attributes.set("datetime", datetime)
        self.content = content()
    }
}
extension Del where Content == EmptyTag {
    public init(cite: String? = nil, datetime: String? = nil, id: String? = nil, class classes: String? = nil) {
        self.init(cite: cite, datetime: datetime, id: id, class: classes) { EmptyTag() }
    }
}

public struct Ins<Content: Tag>: _HTMLContainerTag {     // same params as Del
    public static var tagName: String { "ins" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(cite: String? = nil, datetime: String? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let cite { _attributes.set("cite", HTMLEscaping.sanitizeURL(cite)) }
        _attributes.set("datetime", datetime)
        self.content = content()
    }
}
extension Ins where Content == EmptyTag {
    public init(cite: String? = nil, datetime: String? = nil, id: String? = nil, class classes: String? = nil) {
        self.init(cite: cite, datetime: datetime, id: id, class: classes) { EmptyTag() }
    }
}

public struct Data<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "data" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(value: String, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("value", value)
        self.content = content()
    }
}
extension Data where Content == EmptyTag {
    public init(value: String, id: String? = nil, class classes: String? = nil) {
        self.init(value: value, id: id, class: classes) { EmptyTag() }
    }
}

// MARK: - Void Elements

public struct Wbr: _HTMLVoidTag {
    public static var tagName: String { "wbr" }
    public var _attributes: _AttributeBag
    public init() { _attributes = _AttributeBag() }
}
