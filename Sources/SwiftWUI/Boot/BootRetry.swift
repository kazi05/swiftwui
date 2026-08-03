/// A retry control for the `failed` boot state.
///
/// It carries no Swift closure and cannot: the failure state means there is no
/// wasm runtime to run one. The shim delegates a click listener on
/// `data-swui-boot-retry` which reloads the current URL **minus** the
/// `swui-boot` debug parameter — a plain `location.reload()` would re-enter a
/// forced `?swui-boot=fail` state, so retry could never succeed.
public struct BootRetry<Content: Tag>: Tag, _PrimitiveTag {
    public typealias Body = Never
    let content: Content
    public init(@TagBuilder content: () -> Content) { self.content = content() }

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        let children = resolve(content, path: path.appending(.child(0)), ctx: &ctx)
        return [.element(ElementNode(identity: path, tag: "button",
                                     attributes: ["type": "button", "data-swui-boot-retry": ""],
                                     style: OrderedStyle(), properties: [:],
                                     listeners: [:], observers: [:],
                                     children: children, key: nil))]
    }
}
