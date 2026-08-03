/// A `<meta>` tag description (spec §9). Names are validated against the
/// `_AttributeBag` rules — invalid names assert in debug and are dropped.
public struct MetaTag: Equatable {
    public let attributes: [String: String]
    public init(attributes: [String: String]) {
        var valid: [String: String] = [:]
        for (name, value) in attributes {
            guard _AttributeBag.isValidName(name) else {
                assertionFailure("MetaTag: invalid attribute name '\(name)'")
                continue
            }
            valid[name] = value
        }
        self.attributes = valid
    }
    /// `<meta charset="...">`
    public static func charset(_ value: String) -> MetaTag {
        MetaTag(attributes: ["charset": value])
    }
    /// `<meta name="viewport" content="...">`
    public static func viewport(_ content: String) -> MetaTag {
        MetaTag(attributes: ["name": "viewport", "content": content])
    }
    /// `<meta name="description" content="...">`
    public static func description(_ content: String) -> MetaTag {
        MetaTag(attributes: ["name": "description", "content": content])
    }
    /// `<meta name="..." content="...">`
    public static func named(_ name: String, content: String) -> MetaTag {
        MetaTag(attributes: ["name": name, "content": content])
    }
    /// `<meta property="..." content="...">` (Open Graph)
    public static func property(_ property: String, content: String) -> MetaTag {
        MetaTag(attributes: ["property": property, "content": content])
    }
}

/// A managed `<link>` tag description (assets spec §6). Mirrors `MetaTag`:
/// names validated against `_AttributeBag` rules; `href` sanitized at
/// construction (same policy as `A`/`Img`).
public struct LinkTag: Equatable {
    public let attributes: [String: String]
    public init(attributes: [String: String]) {
        var valid: [String: String] = [:]
        for (name, value) in attributes {
            guard _AttributeBag.isValidName(name) else {
                assertionFailure("LinkTag: invalid attribute name '\(name)'")
                continue
            }
            valid[name] = value
        }
        if let href = valid["href"] { valid["href"] = HTMLEscaping.sanitizeURL(href) }
        self.attributes = valid
    }
    /// `<link rel="icon" href="..." [type="..."]>`
    public static func icon(_ href: String, type: String? = nil) -> LinkTag {
        var attrs = ["rel": "icon", "href": href]
        if let type { attrs["type"] = type }
        return LinkTag(attributes: attrs)
    }
    /// `<link rel="stylesheet" href="...">`
    public static func stylesheet(_ href: String) -> LinkTag {
        LinkTag(attributes: ["rel": "stylesheet", "href": href])
    }
    /// `<link rel="preload" href="..." as="..."> ` — font preloads get `crossorigin`.
    public static func preload(_ href: String, as kind: PreloadKind, type: String? = nil) -> LinkTag {
        var attrs = ["rel": "preload", "href": href, "as": kind.rawValue]
        if kind == .font { attrs["crossorigin"] = "anonymous" }
        if let type { attrs["type"] = type }
        return LinkTag(attributes: attrs)
    }
    /// `<link rel="canonical" href="...">`
    public static func canonical(_ href: String) -> LinkTag {
        LinkTag(attributes: ["rel": "canonical", "href": href])
    }
}

/// `as` values for `LinkTag.preload` (assets spec §6).
public enum PreloadKind: String, Equatable {
    case font, image, style, script, fetch
}

/// Route content that manages the document head (spec §9). Detection is
/// top-level only: the tag returned by the Route builder must itself conform
/// (wrappers like `.padding()` around it hide the conformance — documented).
public protocol Page: Tag {
    /// Browser-tab title, applied on navigation.
    /// NOTE: head application is navigation-driven — a @State-driven change to
    /// `title` between navigations is NOT re-applied until the next route pass
    /// (phase-4 decision; revisit if live titles are ever needed).
    /// STATIC-SITE NOTE: `title` is captured when the route resolves — before
    /// `.staticTask` loaders run — so a title computed from loader-filled @State
    /// renders its initial value. Use `.pageMeta(title:)` for heads that depend
    /// on loaded data; it runs inside the route subtree, after the state graft.
    var title: String { get }
    /// Managed `<meta>` set (replaces only tags marked data-swiftwui).
    var meta: [MetaTag] { get }
    /// Managed `<link>` set (replaces only tags marked data-swiftwui).
    var links: [LinkTag] { get }
    /// Per-page override. `.inherit` (the default) takes the app's; `.none`
    /// suppresses it for this page.
    var bootUI: BootUI { get }
}
extension Page {
    public var meta: [MetaTag] { [] }
    public var links: [LinkTag] { [] }
    public var bootUI: BootUI { .inherit }
}

/// Head snapshot the Router captures for the matched page; the runtime diffs
/// it against the last applied snapshot post-pass (spec §9).
public struct PageHead: Equatable {
    public var title: String
    public var meta: [MetaTag]
    public var links: [LinkTag]
    /// JSON-LD documents, emitted as <script type="application/ld+json">.
    /// Serialized through `HTMLEscaping.scriptJSON` — NEVER `.text`, which
    /// would corrupt JSON and miss a `</script>` breakout inside a string.
    public var structuredData: [String]
    public init(title: String, meta: [MetaTag], links: [LinkTag] = [],
                structuredData: [String] = []) {
        self.title = title; self.meta = meta; self.links = links
        self.structuredData = structuredData
    }
}
