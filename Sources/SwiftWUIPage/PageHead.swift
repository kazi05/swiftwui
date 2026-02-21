// PageHead.swift - Head section configuration types

/// Represents a `<meta>` tag configuration.
public struct MetaTag: Sendable {
    public let attributes: [String: String]

    public init(attributes: [String: String]) {
        self.attributes = attributes
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

    /// `<meta property="..." content="...">`  (Open Graph)
    public static func property(_ property: String, content: String) -> MetaTag {
        MetaTag(attributes: ["property": property, "content": content])
    }
}

/// Represents a `<link rel="stylesheet">` reference.
public struct StyleSheetRef: Sendable {
    public enum Source: Sendable {
        case file(String)
        case url(String)
        case inline(String)
    }

    public let source: Source

    /// Link to a local CSS file.
    public static func file(_ path: String) -> StyleSheetRef {
        StyleSheetRef(source: .file(path))
    }

    /// Link to an external CSS URL (e.g., CDN).
    public static func url(_ url: String) -> StyleSheetRef {
        StyleSheetRef(source: .url(url))
    }

    /// Inline CSS text in a `<style>` tag.
    public static func inline(_ css: String) -> StyleSheetRef {
        StyleSheetRef(source: .inline(css))
    }
}

/// Represents a `<script>` reference.
public struct ScriptRef: Sendable {
    public enum Source: Sendable {
        case file(String)
        case url(String)
        case inline(String)
    }

    public let source: Source
    public let isAsync: Bool
    public let isDefer: Bool
    public let type: String?

    public init(source: Source, isAsync: Bool = false, isDefer: Bool = false, type: String? = nil) {
        self.source = source
        self.isAsync = isAsync
        self.isDefer = isDefer
        self.type = type
    }

    /// Link to a local JS file.
    public static func file(_ path: String, async: Bool = false, defer: Bool = false) -> ScriptRef {
        ScriptRef(source: .file(path), isAsync: async, isDefer: `defer`)
    }

    /// Link to an external JS URL.
    public static func url(_ url: String, async: Bool = false, defer: Bool = false) -> ScriptRef {
        ScriptRef(source: .url(url), isAsync: async, isDefer: `defer`)
    }

    /// Inline JavaScript code.
    public static func inline(_ code: String) -> ScriptRef {
        ScriptRef(source: .inline(code))
    }

    /// Module script.
    public static func module(_ path: String) -> ScriptRef {
        ScriptRef(source: .file(path), type: "module")
    }
}
