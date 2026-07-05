// MARK: - Interactive Containers

public struct Details<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "details" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(open: Bool = false, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if open { _attributes.set("open", "") }
        self.content = content()
    }
}
extension Details where Content == EmptyTag {
    public init(open: Bool = false, id: String? = nil, class classes: String? = nil) {
        self.init(open: open, id: id, class: classes) { EmptyTag() }
    }
}

public struct Dialog<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "dialog" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(open: Bool = false, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if open { _attributes.set("open", "") }
        self.content = content()
    }
}
extension Dialog where Content == EmptyTag {
    public init(open: Bool = false, id: String? = nil, class classes: String? = nil) {
        self.init(open: open, id: id, class: classes) { EmptyTag() }
    }
}

// (`Summary` landed in Task 2.)

// MARK: - Media

public struct Video<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "video" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(src: String? = nil, poster: String? = nil,
                controls: Bool = false, autoplay: Bool = false,
                loop: Bool = false, muted: Bool = false, playsinline: Bool = false,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let src { _attributes.set("src", HTMLEscaping.sanitizeURL(src)) }
        if let poster { _attributes.set("poster", HTMLEscaping.sanitizeURL(poster)) }
        if controls { _attributes.set("controls", "") }
        if autoplay { _attributes.set("autoplay", "") }
        if loop { _attributes.set("loop", "") }
        if muted { _attributes.set("muted", "") }
        if playsinline { _attributes.set("playsinline", "") }
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
        self.content = content()
    }
}
extension Video where Content == EmptyTag {
    public init(src: String? = nil, poster: String? = nil, controls: Bool = false, autoplay: Bool = false, loop: Bool = false, muted: Bool = false, playsinline: Bool = false, width: Int? = nil, height: Int? = nil, id: String? = nil, class classes: String? = nil) {
        self.init(src: src, poster: poster, controls: controls, autoplay: autoplay, loop: loop, muted: muted, playsinline: playsinline, width: width, height: height, id: id, class: classes) { EmptyTag() }
    }
}

public struct Audio<Content: Tag>: _HTMLContainerTag {   // Video minus visual params
    public static var tagName: String { "audio" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(src: String? = nil, controls: Bool = false, autoplay: Bool = false,
                loop: Bool = false, muted: Bool = false,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let src { _attributes.set("src", HTMLEscaping.sanitizeURL(src)) }
        if controls { _attributes.set("controls", "") }
        if autoplay { _attributes.set("autoplay", "") }
        if loop { _attributes.set("loop", "") }
        if muted { _attributes.set("muted", "") }
        self.content = content()
    }
}
extension Audio where Content == EmptyTag {
    public init(src: String? = nil, controls: Bool = false, autoplay: Bool = false, loop: Bool = false, muted: Bool = false, id: String? = nil, class classes: String? = nil) {
        self.init(src: src, controls: controls, autoplay: autoplay, loop: loop, muted: muted, id: id, class: classes) { EmptyTag() }
    }
}

public struct Source: _HTMLVoidTag {
    public static var tagName: String { "source" }
    public var _attributes: _AttributeBag
    public init(src: String? = nil, srcset: String? = nil, type: String? = nil,
                media: String? = nil, id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let src { _attributes.set("src", HTMLEscaping.sanitizeURL(src)) }
        _attributes.set("srcset", srcset)          // srcset is a URL LIST — not single-URL sanitizable; escaped at serialization like any attr
        _attributes.set("type", type)
        _attributes.set("media", media)
    }
}

public struct Track: _HTMLVoidTag {
    public static var tagName: String { "track" }
    public var _attributes: _AttributeBag
    public init(src: String, kind: String? = nil, srclang: String? = nil,
                label: String? = nil, isDefault: Bool = false,
                id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("src", HTMLEscaping.sanitizeURL(src))
        _attributes.set("kind", kind)
        _attributes.set("srclang", srclang)
        _attributes.set("label", label)
        if isDefault { _attributes.set("default", "") }
    }
}

public struct Picture<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "picture" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
extension Picture where Content == EmptyTag {
    public init(id: String? = nil, class classes: String? = nil) {
        self.init(id: id, class: classes) { EmptyTag() }
    }
}

// MARK: - Embedded

public struct Iframe<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "iframe" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(src: String, title: String? = nil, sandbox: String? = nil,
                allow: String? = nil, loading: String? = nil,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("src", HTMLEscaping.sanitizeURL(src))
        _attributes.set("title", title)
        _attributes.set("sandbox", sandbox)
        _attributes.set("allow", allow)
        _attributes.set("loading", loading)
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
        self.content = content()
    }
}
extension Iframe where Content == EmptyTag {
    public init(src: String, title: String? = nil, sandbox: String? = nil,
                allow: String? = nil, loading: String? = nil,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil) {
        self.init(src: src, title: title, sandbox: sandbox, allow: allow,
                  loading: loading, width: width, height: height,
                  id: id, class: classes) { EmptyTag() }
    }
}

public struct Canvas<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "canvas" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
        self.content = content()
    }
}
extension Canvas where Content == EmptyTag {
    public init(width: Int? = nil, height: Int? = nil, id: String? = nil, class classes: String? = nil) {
        self.init(width: width, height: height, id: id, class: classes) { EmptyTag() }
    }
}

public struct Object<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "object" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(data: String? = nil, type: String? = nil,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let data { _attributes.set("data", HTMLEscaping.sanitizeURL(data)) }
        _attributes.set("type", type)
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
        self.content = content()
    }
}
extension Object where Content == EmptyTag {
    public init(data: String? = nil, type: String? = nil, width: Int? = nil, height: Int? = nil, id: String? = nil, class classes: String? = nil) {
        self.init(data: data, type: type, width: width, height: height, id: id, class: classes) { EmptyTag() }
    }
}

public struct Embed: _HTMLVoidTag {
    public static var tagName: String { "embed" }
    public var _attributes: _AttributeBag
    public init(src: String, type: String? = nil,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("src", HTMLEscaping.sanitizeURL(src))
        _attributes.set("type", type)
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
    }
}

public struct Param: _HTMLVoidTag {
    public static var tagName: String { "param" }
    public var _attributes: _AttributeBag
    public init(name: String, value: String) {
        _attributes = _AttributeBag()
        _attributes.set("name", name)
        _attributes.set("value", value)
    }
}

public struct Map<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "map" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(name: String, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("name", name)
        self.content = content()
    }
}
extension Map where Content == EmptyTag {
    public init(name: String, id: String? = nil, class classes: String? = nil) {
        self.init(name: name, id: id, class: classes) { EmptyTag() }
    }
}

public struct Area: _HTMLVoidTag {
    public static var tagName: String { "area" }
    public var _attributes: _AttributeBag
    public init(shape: String, coords: String? = nil, href: String? = nil,
                alt: String, id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("shape", shape)
        _attributes.set("coords", coords)
        if let href { _attributes.set("href", HTMLEscaping.sanitizeURL(href)) }
        _attributes.set("alt", alt)
    }
}

// MARK: - Noscript

/// Text-only by design: with scripting enabled, the HTML parser treats
/// noscript content as raw text — element children would come back as one
/// text node and break T8/adoption. One text child matches in both worlds.
public struct Noscript: _HTMLContainerTag {
    public static var tagName: String { "noscript" }
    public var _attributes: _AttributeBag
    public var content: Text
    public init(_ text: String, id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        content = Text(text)
    }
}
