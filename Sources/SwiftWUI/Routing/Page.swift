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
    /// renders its initial value in SSG output (ledgered phase-6 ticket).
    var title: String { get }
    /// Managed `<meta>` set (replaces only tags marked data-swiftwui).
    var meta: [MetaTag] { get }
}
extension Page {
    public var meta: [MetaTag] { [] }
}

/// Head snapshot the Router captures for the matched page; the runtime diffs
/// it against the last applied snapshot post-pass (spec §9).
public struct PageHead: Equatable {
    public var title: String
    public var meta: [MetaTag]
    public init(title: String, meta: [MetaTag]) { self.title = title; self.meta = meta }
}
