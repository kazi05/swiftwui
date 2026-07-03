import SwiftWUI

/// Full-page assembly (spec §9). Pure string building; every dynamic value
/// flows through HTMLEscaping. <title> is RCDATA — entity escaping is correct
/// there. The snapshot <script> is RAW TEXT: no HTML escaping (entities are
/// NOT decoded in scripts); breakout is prevented at the JSON level ("\/").
public enum DocumentSerializer {
    public struct Input {
        public var bodyHTML: String
        public var css: String?              // inline <style> (default path)
        public var cssHref: String?          // <link rel="stylesheet"> instead
        public var head: PageHead?
        public var snapshotJSON: String?     // hydrate mode only
        public var wasmScriptPath: String?   // hydrate mode only
        public var lang: String
        public init(bodyHTML: String, css: String? = nil, cssHref: String? = nil,
                    head: PageHead? = nil, snapshotJSON: String? = nil,
                    wasmScriptPath: String? = nil, lang: String = "en") {
            self.bodyHTML = bodyHTML; self.css = css; self.cssHref = cssHref
            self.head = head; self.snapshotJSON = snapshotJSON
            self.wasmScriptPath = wasmScriptPath; self.lang = lang
        }
    }

    public static func render(_ input: Input) -> String {
        var out = "<!doctype html>\n<html lang=\"" + HTMLEscaping.text(input.lang) + "\">\n<head>\n"
        out += "<meta charset=\"utf-8\">\n"
        let metas = input.head?.meta ?? []
        let hasViewport = metas.contains { $0.attributes["name"] == "viewport" }
        if !hasViewport {
            out += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" data-swiftwui>\n"
        }
        out += "<title>" + HTMLEscaping.text(input.head?.title ?? "") + "</title>\n"
        for meta in metas {
            out += "<meta"
            for name in meta.attributes.keys.sorted() {
                out += " \(name)=\"\(HTMLEscaping.text(meta.attributes[name]!))\""
            }
            out += " data-swiftwui>\n"       // managed set marker (phase-4 semantics)
        }
        if let href = input.cssHref {
            out += "<link rel=\"stylesheet\" href=\"" + HTMLEscaping.text(href) + "\">\n"
        } else if let css = input.css, !css.isEmpty {
            // Raw-text context: CSS comes from our own registry (already
            // sanitized at registration — phase-3 sink guards); assert-guard
            // the impossible breakout anyway.
            assert(!css.contains("</style"), "registry CSS must never contain </style")
            out += "<style data-swiftwui>\n" + css + "\n</style>\n"
        }
        if let snapshot = input.snapshotJSON {
            // "\/" alone can't stop "<!--<script" (script-data-double-escaped state
            // swallows the document) — route through the audited scriptJSON helper,
            // which escapes < > U+2028 U+2029 as \uXXXX, JSON-preservingly.
            out += "<script type=\"application/swiftwui-state\" data-swiftwui>"
                + HTMLEscaping.scriptJSON(snapshot) + "</script>\n"
        }
        out += "</head>\n<body>\n" + input.bodyHTML + "\n"
        if let src = input.wasmScriptPath {
            out += "<script type=\"module\" src=\"" + HTMLEscaping.text(src) + "\"></script>\n"
        }
        out += "</body>\n</html>\n"
        return out
    }
}
