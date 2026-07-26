/// A partial `<head>` written from inside a route subtree (spec §5.1). Every
/// field is optional and means "leave whatever the baseline had". `PageHead`
/// itself cannot express this — its fields are non-optional — which is why the
/// patch is a separate type folded in at commit time.
public struct PageHeadPatch: Equatable {
    public var title: String?
    public var meta: [MetaTag]?
    public var links: [LinkTag]?

    public init(title: String? = nil, meta: [MetaTag]? = nil, links: [LinkTag]? = nil) {
        self.title = title; self.meta = meta; self.links = links
    }

    public func folded(over base: PageHead) -> PageHead {
        PageHead(title: title ?? base.title,
                 meta: meta ?? base.meta,
                 links: links ?? base.links)
    }
}

/// Writes `ctx.pageHeadPatch` during resolve. Sitting INSIDE the route subtree
/// is the point: it runs after state grafting and re-runs on the passes that
/// `.staticTask` writes trigger, which is exactly what `Page.title` cannot do
/// (Router snapshots that before the graft).
struct _PageMetaTag<Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let patch: PageHeadPatch
    let content: Content

    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        #if DEBUG
        if let existing = ctx.pageHeadPatch, existing != patch {
            print("SwiftWUI: two .pageMeta in one route subtree — deepest wins (at \(id))")
        }
        #endif
        ctx.pageHeadPatch = patch      // deepest/last resolve wins
        return resolve(content, path: id, ctx: &ctx)
    }
}

extension Tag {
    /// Declares document head values computed from this subtree's state
    /// (spec §5.1). nil parameters inherit; an explicit value replaces.
    public func pageMeta(title: String? = nil,
                         meta: [MetaTag]? = nil,
                         links: [LinkTag]? = nil) -> some Tag {
        _PageMetaTag(patch: PageHeadPatch(title: title, meta: meta, links: links),
                     content: self)
    }
}
