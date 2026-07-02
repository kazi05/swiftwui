public protocol HTMLTag: Tag, _PrimitiveTag where Body == Never {
    static var tagName: String { get }
    var _attributes: _AttributeBag { get set }
}

extension HTMLTag {
    /// Raw attribute escape hatch. The NAME is validated ([a-zA-Z_:][a-zA-Z0-9_.:-]*,
    /// spec §11); the VALUE is escaped only at serialization time like every other
    /// attribute. No URL/scheme sanitization is applied — attributes like `href`
    /// set through this API are the caller's responsibility.
    public func attribute(_ name: String, _ value: String?) -> Self {
        var copy = self; copy._attributes.set(name, value); return copy
    }
    public func id(_ value: String) -> Self { attribute("id", value) }
    public func classes(_ names: String...) -> Self {
        var copy = self; copy._attributes.appendClasses(names); return copy
    }
}

/// Container tags: generic content, ONE shared resolution path (spec §3.3).
public protocol _HTMLContainerTag: HTMLTag {
    associatedtype Content: Tag
    var content: Content { get }
}
extension _HTMLContainerTag {
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        resolveElement(tagName: Self.tagName, bag: _attributes, content: content, path: path, ctx: &ctx)
    }
}

/// Void tags: no content, no closing tag.
public protocol _HTMLVoidTag: HTMLTag {}
extension _HTMLVoidTag {
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        resolveElement(tagName: Self.tagName, bag: _attributes, content: EmptyTag(), path: path, ctx: &ctx)
    }
}
