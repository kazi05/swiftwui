// Typed temporary-resource variants of the existing String URL APIs. Handles
// stay in _AttributeBag's resource channel and are never stringified here.

extension Img {
    public init(src: WebObjectURL, alt: String,
                width: Int? = nil, height: Int? = nil,
                srcset: String? = nil, sizes: String? = nil,
                loading: ImgLoading? = nil, decoding: ImgDecoding? = nil,
                id: String? = nil, class classes: String? = nil) {
        self.init(src: "", alt: alt, width: width, height: height,
                  srcset: srcset, sizes: sizes, loading: loading, decoding: decoding,
                  id: id, class: classes)
        _attributes.setObjectURL("src", src)
    }

    public func source(_ value: WebObjectURL) -> Self {
        var copy = self
        copy._attributes.setObjectURL("src", value)
        return copy
    }
}

extension Video {
    public init(src: WebObjectURL, poster: String? = nil,
                controls: Bool = false, autoplay: Bool = false,
                loop: Bool = false, muted: Bool = false, playsinline: Bool = false,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        self.init(src: nil, poster: poster, controls: controls, autoplay: autoplay,
                  loop: loop, muted: muted, playsinline: playsinline,
                  width: width, height: height, id: id, class: classes, content: content)
        _attributes.setObjectURL("src", src)
    }

    public func source(_ value: WebObjectURL) -> Self {
        var copy = self
        copy._attributes.setObjectURL("src", value)
        return copy
    }
}

extension Video where Content == EmptyTag {
    public init(src: WebObjectURL, poster: String? = nil,
                controls: Bool = false, autoplay: Bool = false,
                loop: Bool = false, muted: Bool = false, playsinline: Bool = false,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil) {
        self.init(src: src, poster: poster, controls: controls, autoplay: autoplay,
                  loop: loop, muted: muted, playsinline: playsinline,
                  width: width, height: height, id: id, class: classes) { EmptyTag() }
    }
}

extension Audio {
    public init(src: WebObjectURL, controls: Bool = false, autoplay: Bool = false,
                loop: Bool = false, muted: Bool = false,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        self.init(src: nil, controls: controls, autoplay: autoplay, loop: loop, muted: muted,
                  id: id, class: classes, content: content)
        _attributes.setObjectURL("src", src)
    }

    public func source(_ value: WebObjectURL) -> Self {
        var copy = self
        copy._attributes.setObjectURL("src", value)
        return copy
    }
}

extension Audio where Content == EmptyTag {
    public init(src: WebObjectURL, controls: Bool = false, autoplay: Bool = false,
                loop: Bool = false, muted: Bool = false,
                id: String? = nil, class classes: String? = nil) {
        self.init(src: src, controls: controls, autoplay: autoplay, loop: loop, muted: muted,
                  id: id, class: classes) { EmptyTag() }
    }
}

extension A {
    public init(href: WebObjectURL, target: LinkTarget? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        self.init(href: "", target: target, id: id, class: classes, content: content)
        _attributes.setObjectURL("href", href)
    }

    public func destination(_ value: WebObjectURL) -> Self {
        var copy = self
        copy._attributes.setObjectURL("href", value)
        return copy
    }
}

extension A where Content == EmptyTag {
    public init(href: WebObjectURL, target: LinkTarget? = nil,
                id: String? = nil, class classes: String? = nil) {
        self.init(href: href, target: target, id: id, class: classes) { EmptyTag() }
    }
}
