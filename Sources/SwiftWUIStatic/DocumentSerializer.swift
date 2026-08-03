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
        /// Links only the prerender can compute — the synthesized canonical and
        /// the hreflang set. Emitted under `data-swiftwui-ssg`, NOT the managed
        /// marker; see the loop below for why.
        public var prerenderedLinks: [LinkTag]
        /// Meta the prerender owns, emitted under `data-swiftwui-ssg` like the
        /// prerendered links — the client can recompute none of it.
        public var prerenderedMeta: [MetaTag]
        public var snapshotJSON: String?     // hydrate mode only
        public var importMapJSON: String?    // hydrate mode only
        public var wasmScriptPath: String?   // hydrate mode only
        public var lang: String
        public var dir: String?              // "rtl" for right-to-left locales; nil = omit
        public init(bodyHTML: String, css: String? = nil, cssHref: String? = nil,
                    head: PageHead? = nil, prerenderedLinks: [LinkTag] = [],
                    prerenderedMeta: [MetaTag] = [],
                    snapshotJSON: String? = nil, importMapJSON: String? = nil,
                    wasmScriptPath: String? = nil, lang: String = "en", dir: String? = nil) {
            self.bodyHTML = bodyHTML; self.css = css; self.cssHref = cssHref
            self.head = head; self.prerenderedLinks = prerenderedLinks
            self.prerenderedMeta = prerenderedMeta
            self.snapshotJSON = snapshotJSON
            self.importMapJSON = importMapJSON
            self.wasmScriptPath = wasmScriptPath; self.lang = lang; self.dir = dir
        }
    }

    public static func render(_ input: Input) -> String {
        var out = "<!doctype html>\n<html lang=\"" + HTMLEscaping.text(input.lang) + "\""
        if let dir = input.dir { out += " dir=\"" + HTMLEscaping.text(dir) + "\"" }
        out += ">\n<head>\n"
        out += "<meta charset=\"utf-8\">\n"
        let metas = input.head?.meta ?? []
        let hasViewport = metas.contains { $0.attributes["name"] == "viewport" }
        if !hasViewport {
            // unmanaged, like hand-written meta — setMetaTags must never strip the mobile viewport at boot
            out += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        }
        out += "<title>" + HTMLEscaping.text(input.head?.title ?? "") + "</title>\n"
        for meta in metas {
            out += "<meta"
            for name in meta.attributes.keys.sorted() {
                out += " \(name)=\"\(HTMLEscaping.text(meta.attributes[name]!))\""
            }
            out += " data-swiftwui>\n"       // managed set marker (phase-4 semantics)
        }
        for link in input.head?.links ?? [] {
            out += "<link"
            for name in link.attributes.keys.sorted() {
                out += " \(name)=\"\(HTMLEscaping.text(link.attributes[name]!))\""
            }
            out += " data-swiftwui>\n"       // managed set marker (same as meta)
        }
        // Prerender-only tags get their OWN marker, so the hydration re-apply
        // (`setLinks`/`setMetaTags` sweep `link[data-swiftwui]` and
        // `meta[data-swiftwui]`, an exact attribute-NAME match) leaves them
        // standing. Neither CanonicalSynthesis nor HreflangLinks exists
        // client-side, the client has neither siteURL nor the locale set, and
        // it never learns a page was a fall-through, so anything swept here is
        // gone for good.
        //
        // They describe THE URL THAT WAS SERVED. The moment the client moves the
        // URL — SPA navigation, back/forward, a `.pathPrefix` locale switch —
        // they stop describing it, so the runtime drops them there
        // (`Runtime.moveURL` / `handlePopState` → `dropPrerenderedHeadLinks`).
        // Dropping beats keeping a stale canonical, and costs nothing: crawlers
        // fetch each URL fresh and read its own prerendered head.
        for meta in input.prerenderedMeta {
            out += "<meta"
            for name in meta.attributes.keys.sorted() {
                out += " \(name)=\"\(HTMLEscaping.text(meta.attributes[name]!))\""
            }
            out += " data-swiftwui-ssg>\n"
        }
        for link in input.prerenderedLinks {
            out += "<link"
            for name in link.attributes.keys.sorted() {
                out += " \(name)=\"\(HTMLEscaping.text(link.attributes[name]!))\""
            }
            out += " data-swiftwui-ssg>\n"
        }
        for block in input.head?.structuredData ?? [] {
            // Raw-text sink: same audited helper the state snapshot uses.
            out += "<script type=\"application/ld+json\" data-swiftwui>"
                + HTMLEscaping.scriptJSON(block) + "</script>\n"
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
        if let map = input.importMapJSON {
            // Same raw-text sink as the snapshot script above — the wasm bundle's bare
            // "@bjorn3/browser_wasi_shim" import cannot resolve without this map, and it
            // must precede the module script that triggers that import.
            out += "<script type=\"importmap\">" + HTMLEscaping.scriptJSON(map) + "</script>\n"
        }
        if let src = input.wasmScriptPath {
            // type="module" defers by default — head placement is behavior-identical, and
            // keeps <body> byte-exact for adoption (a stray "\n" text node poisons the stream).
            //
            // Inline import, not src=: the PackageToJS bundle's index.js only EXPORTS
            // `init` — it has no side effects, so a bare `src=` script loads but never
            // boots. Same raw-text sink as snapshot/importmap above.
            out += "<script type=\"module\">import { init } from "
                + HTMLEscaping.scriptJSON(SnapshotJSON.jsonString(src))
                + "; await init();</script>\n"
        }
        // No trailing newline (or anything) after </body>: per the HTML spec,
        // character tokens after </body> are reparented INTO body, which
        // poisons the adoption stream with a stray text node.
        out += "</head>\n<body>" + input.bodyHTML + "</body></html>"
        return out
    }
}
