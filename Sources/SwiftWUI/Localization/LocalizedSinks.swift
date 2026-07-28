// Localized twins of the String-taking initializers. Each one hands the
// `LocalizedText` to the attribute bag unresolved; `resolveElement` turns it
// into a plain attribute value once the locale is known, so every localized
// value lands in the same escaping path as a plain one.

extension HTMLTag {
    /// Raw localized attribute escape hatch — same name validation as the
    /// String overload, value resolved per locale at render time. Like that
    /// overload, no URL/scheme sanitization is applied.
    public func attribute(_ name: String, _ localized: LocalizedText) -> Self {
        var copy = self
        copy._attributes.set(name, localized: localized)
        return copy
    }
}

extension Button where Content == Text {
    public init(_ title: LocalizedText, type: ButtonType = .button, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onClick: @escaping () -> Void) {
        self.init(type: type, disabled: disabled, id: id, class: classes,
                  onClick: onClick) { Text(title) }
    }
}

extension Img {
    public init(src: String, alt: LocalizedText,
                width: Int? = nil, height: Int? = nil,
                srcset: String? = nil, sizes: String? = nil,
                loading: ImgLoading? = nil, decoding: ImgDecoding? = nil,
                id: String? = nil, class classes: String? = nil) {
        self.init(src: src, alt: "", width: width, height: height, srcset: srcset,
                  sizes: sizes, loading: loading, decoding: decoding, id: id, class: classes)
        _attributes.set("alt", localized: alt)
    }
}

extension Input {
    public init(type: InputType = .text, name: String? = nil, value: String? = nil,
                placeholder: LocalizedText, disabled: Bool = false,
                accept: String? = nil, multiple: Bool = false,
                id: String? = nil, class classes: String? = nil) {
        self.init(type: type, name: name, value: value, placeholder: nil, disabled: disabled,
                  accept: accept, multiple: multiple, id: id, class: classes)
        _attributes.set("placeholder", localized: placeholder)
    }

    public init(type: InputType = .text, value: Binding<String>, name: String? = nil,
                placeholder: LocalizedText, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onInput: ((InputEvent) -> Void)? = nil,
                onKeyDown: ((KeyEvent) -> Void)? = nil) {
        self.init(type: type, value: value, name: name, placeholder: nil, disabled: disabled,
                  id: id, class: classes, onInput: onInput, onKeyDown: onKeyDown)
        _attributes.set("placeholder", localized: placeholder)
    }
}

extension Textarea where Content == EmptyTag {
    /// `Textarea` has no `placeholder` parameter of its own; the controlled
    /// initializer is the only form where one is meaningful. The content form
    /// is served by `.attribute("placeholder", localizedText)`.
    public init(text: Binding<String>, placeholder: LocalizedText,
                id: String? = nil, class classes: String? = nil) {
        self.init(text: text, id: id, class: classes)
        _attributes.set("placeholder", localized: placeholder)
    }
}
