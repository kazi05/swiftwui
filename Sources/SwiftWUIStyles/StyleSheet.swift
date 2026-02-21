// StyleSheet.swift - External CSS file references

/// Represents an external CSS stylesheet reference.
public struct StyleSheet: Sendable {
    public enum Source: Sendable {
        case file(String)
        case url(String)
        case inline(String)
    }

    public let source: Source

    /// Link to a local CSS file.
    public static func file(_ path: String) -> StyleSheet {
        StyleSheet(source: .file(path))
    }

    /// Link to an external CSS URL (e.g., CDN).
    public static func url(_ url: String) -> StyleSheet {
        StyleSheet(source: .url(url))
    }

    /// Inline CSS text.
    public static func inline(_ css: String) -> StyleSheet {
        StyleSheet(source: .inline(css))
    }
}
