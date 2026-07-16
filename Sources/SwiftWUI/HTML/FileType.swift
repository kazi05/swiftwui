/// UTType analog for the web: a mime pattern + associated extensions.
/// TRUST: matching runs against client-claimed `WebFile.mimeType`/`name` —
/// UX filtering only; consumers must validate bytes server-side.
public struct FileType: Hashable, Sendable {
    public let mime: String              // "image/png" or family "image/*"
    public let extensions: [String]      // no leading dots
    public init(mime: String, extensions: [String] = []) {
        self.mime = mime; self.extensions = extensions
    }

    public static let image = FileType(mime: "image/*")
    public static let png   = FileType(mime: "image/png",  extensions: ["png"])
    public static let jpeg  = FileType(mime: "image/jpeg", extensions: ["jpg", "jpeg"])
    public static let gif   = FileType(mime: "image/gif",  extensions: ["gif"])
    public static let svg   = FileType(mime: "image/svg+xml", extensions: ["svg"])
    public static let webp  = FileType(mime: "image/webp", extensions: ["webp"])
    public static let video = FileType(mime: "video/*")
    public static let audio = FileType(mime: "audio/*")
    public static let pdf   = FileType(mime: "application/pdf", extensions: ["pdf"])
    public static let text  = FileType(mime: "text/plain", extensions: ["txt"])
    public static let json  = FileType(mime: "application/json", extensions: ["json"])
    public static let csv   = FileType(mime: "text/csv", extensions: ["csv"])
    public static let zip   = FileType(mime: "application/zip", extensions: ["zip"])
    public static let any   = FileType(mime: "*/*")

    /// Mime match when the file claims one; extension fallback otherwise.
    public func matches(_ file: WebFile) -> Bool {
        if !file.mimeType.isEmpty {
            return _DragAcceptance.mimeMatches(pattern: mime, mime: file.mimeType)
        }
        let parts = file.name.split(separator: ".")
        guard parts.count >= 2, let last = parts.last else { return false }
        return extensions.contains(String(last).lowercased())
    }

    /// `accept` attribute body: mimes + dotted extensions, comma-joined.
    static func acceptString(_ types: [FileType]) -> String? {
        guard !types.isEmpty else { return nil }
        var parts: [String] = []
        for t in types {
            parts.append(t.mime)
            parts += t.extensions.map { "." + $0 }
        }
        return parts.joined(separator: ",")
    }
}

extension Input {
    /// Typed accept-list convenience over the base `accept: String?` init.
    public init(type: InputType, accept: [FileType], multiple: Bool = false,
                name: String? = nil, id: String? = nil, class classes: String? = nil) {
        self.init(type: type, name: name, accept: FileType.acceptString(accept),
                  multiple: multiple, id: id, class: classes)
    }
}
