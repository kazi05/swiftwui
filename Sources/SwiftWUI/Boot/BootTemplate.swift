/// Wraps boot-only markup in `<template data-swui-boot-ui>`.
///
/// Template content is inert: never rendered, never styled, invisible to
/// accessibility and to text extraction. The shim clones it into the document
/// only after the delay threshold, so "Loading…" is not indexable body copy and
/// the no-JS story is structural rather than CSS-dependent.
struct _BootTemplate<C: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let content: C
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        let children = resolve(content, path: path.appending(.child(0)), ctx: &ctx)
        return [.element(ElementNode(identity: path, tag: "template",
                                     attributes: ["data-swui-boot-ui": ""],
                                     style: OrderedStyle(), properties: [:],
                                     listeners: [:], observers: [:],
                                     children: children, key: nil))]
    }
}
