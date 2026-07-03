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

// MARK: - Void Elements

public struct Wbr: _HTMLVoidTag {
    public static var tagName: String { "wbr" }
    public var _attributes: _AttributeBag
    public init() { _attributes = _AttributeBag() }
}
