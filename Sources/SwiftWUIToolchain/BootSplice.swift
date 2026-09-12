import Foundation
import SwiftWUI

/// Writes the app's boot scripts into `dist/index.html` — the SPA counterpart of
/// what `DocumentSerializer` emits into every prerendered document, and the only
/// thing that starts the wasm in a built dist. The two blocks are deliberately
/// duplicated (`SwiftWUIToolchain` does not depend on `SwiftWUIStatic`); keep
/// the attribute names in step with `DocumentSerializer.render`, they are the
/// shim's contract.
public enum BootSplice {
    static let open = "<!--swiftwui:boot-->"
    static let close = "<!--/swiftwui:boot-->"

    /// The bundle entry, as `DistLayout.assemble` lays it out: it copies the
    /// PackageToJS bundle to `<outDir>/app` wholesale, and the plugin always
    /// names the module that exports `init` index.js.
    static let entryURL = "/app/index.js"

    /// The entry's OWN directory, not a hardcoded "/app/" — every URL the shim
    /// is given is derived from it, so the build, the SSG and `swiftwui dev`
    /// cannot disagree about where the files next to the entry are served from.
    static let entryDir = entryURL.lastIndex(of: "/").map { String(entryURL[...$0]) } ?? "/app/"

    /// Splices `<outDir>/index.html` — never the project's own, which is
    /// user-owned. Returns whether the document ends up naming the wasm with a
    /// `?v=` digest.
    ///
    /// That answer is about this one file, so it is NOT the input to the
    /// immutable cache header: a dist also holds prerenders this call never
    /// touches, and one of them naming an older version is what has to veto the
    /// header. `ReleaseArtifacts.auditWasmVersions` reads the whole dist and is
    /// what `writeNginxConf` is given.
    ///
    /// Must run after `DistLayout.assemble` (which re-copies index.html over any
    /// earlier splice) and before `PWAAssets.generateManifest` (whose SRI covers
    /// the root index.html) and `ReleaseArtifacts.compress` (whose .gz sibling
    /// is what gzip_static actually serves).
    @discardableResult
    public static func write(outDir: String, shell: BootShell?) throws -> Bool {
        var config: BootConfig? = nil
        var versioned = false
        if let shell {
            guard let wasmName = WasmDigest.wasmName(inAppDir: outDir + "/app") else {
                throw ToolchainError.io("no .wasm in \(outDir)/app after assemble")
            }
            let stamp = WasmDigest.stamp(path: outDir + "/app/" + wasmName)
            versioned = stamp != nil
            let dir = entryDir
            let wasmURL = dir + wasmName
            // No stamp (an unreadable wasm) drops only the `?v=`: the URL still
            // resolves, the shim still boots, and the progress bar goes
            // indeterminate. Failing the build over a cache token would be worse.
            config = BootConfig(wasmURL: stamp.map { wasmURL + "?v=" + WasmDigest.version($0) } ?? wasmURL,
                                entryURL: entryURL,
                                shimURL: dir + "swiftwui-boot.js",
                                sizeBytes: stamp?.sizeBytes,
                                delayMS: shell.delayMS)
        }
        let index = outDir + "/index.html"
        let html = try String(contentsOfFile: index, encoding: .utf8)
        guard let spliced = apply(html: html, shell: shell, config: config) else {
            print("warning: \(index) has neither a \(open) marker nor a </head> — "
                + "left unmodified, so nothing starts the app")
            return false
        }
        try spliced.write(toFile: index, atomically: true, encoding: .utf8)
        return versioned
    }

    /// Replaces the paired marker region wholesale — idempotent across rebuilds,
    /// so a stale `?v=` cannot survive one. Falls back to the `</head>` anchor
    /// for projects scaffolded before the marker existed. nil = leave the file
    /// alone, so nothing starts the app.
    ///
    /// `shell` and `config` are nil together and mean "this project declared no
    /// boot UI": the region still gets the module script that boots the app, the
    /// same one the templates used to inline. Splicing only when a boot shell
    /// exists would leave every non-opted-in project with a blank page.
    public static func apply(html: String, shell: BootShell?, config: BootConfig?) -> String? {
        let block = open + render(shell: shell, config: config) + close
        if let o = html.range(of: open), let c = html.range(of: close), o.upperBound <= c.lowerBound {
            return html.replacingCharacters(in: o.lowerBound..<c.upperBound, with: block)
        }
        // The fallback only INSERTS, and a pre-marker index.html still inlines
        // the boot in <body> — so without this the wasm instantiates twice and
        // `mount()` appends a SECOND copy of the whole app (Runtime.mount never
        // replaces): doubled window listeners, every `.task` run twice, silently.
        // Only reached here: a document carrying the markers is current, and the
        // module script beside them is the author's own.
        let stripped = stripLegacyBoot(html)
        let source = stripped ?? html
        guard let head = source.range(of: "</head>", options: .caseInsensitive) else { return nil }
        if stripped != nil {
            print("note: replaced index.html's inline boot script with the generated boot block")
        }
        return source.replacingCharacters(in: head.lowerBound..<head.lowerBound, with: block)
    }

    /// Removes the `<script type="module">import { init } … await init();</script>`
    /// the templates inlined before the marker existed. nil = there was none.
    ///
    /// Both halves of the body are required, so a module script of the author's
    /// own — which is what every other `<script type="module">` in a project is —
    /// is left standing.
    static func stripLegacyBoot(_ html: String) -> String? {
        var from = html.startIndex
        while let open = html.range(of: "<script", options: .caseInsensitive, range: from..<html.endIndex) {
            guard let gt = html.range(of: ">", range: open.upperBound..<html.endIndex),
                  let close = html.range(of: "</script>", options: .caseInsensitive,
                                         range: gt.upperBound..<html.endIndex)
            else { return nil }
            let tag = html[open.lowerBound..<gt.upperBound]
            let body = html[gt.upperBound..<close.lowerBound]
            if tag.contains("module"), body.contains("import { init }"), body.contains("await init()") {
                return html.replacingCharacters(in: open.lowerBound..<close.upperBound, with: "")
            }
            from = close.upperBound
        }
        return nil
    }

    static func render(shell: BootShell?, config: BootConfig?) -> String {
        var out = "\n"
        if let shell, !shell.css.isEmpty {
            // Not `data-swiftwui`: that is the stylesheet DOMBackend adopts and
            // overwrites at mount, which would delete the veil rules mid-boot.
            out += "<style data-swui-boot>\n" + shell.css + "\n</style>\n"
        }
        if let config {
            // Every link below MUST stay under the import map the template keeps
            // above this region: processing a modulepreload disallows any later
            // import map, and the bundle's bare "@bjorn3/browser_wasi_shim"
            // import would then never resolve. `ToolchainResourceTests` pins the
            // template side of that ordering.
            //
            // No `sanitizeURL` pass, unlike DocumentSerializer's copy: these
            // three URLs are built here from the dist layout plus a file name
            // read out of `dist/app`, so they always begin "/app/" and cannot
            // carry a scheme. Attribute escaping still applies.
            let wasmURL = HTMLEscaping.text(config.wasmURL)
            let shimURL = HTMLEscaping.text(config.shimURL)
            let entry = HTMLEscaping.text(config.entryURL)
            if config.activation == .eager {
            out += "<link rel=\"preload\" as=\"fetch\" crossorigin fetchpriority=\"low\" href=\""
                + wasmURL + "\">\n"
            out += "<link rel=\"modulepreload\" href=\"" + shimURL + "\">\n"
            out += "<link rel=\"modulepreload\" href=\"" + entry + "\">\n"
            }
            // The shim owns the import + init() call the else-branch inlines;
            // emitting both would boot the app twice. `data-size` is omitted
            // outright when unknown — the shim reads a missing one as indeterminate.
            out += "<script type=\"module\" src=\"" + shimURL + "\" data-swui-boot-config"
            out += " data-wasm=\"" + wasmURL + "\""
            out += " data-entry=\"" + entry + "\""
            out += config.sizeBytes.map { " data-size=\"\($0)\"" } ?? ""
            out += " data-delay=\"\(config.delayMS)\""
            out += " data-activation=\"" + config.activation.rawValue + "\""
            out += config.activationSelector.map { " data-activation-selector=\"" + HTMLEscaping.text($0) + "\"" } ?? ""
            out += "></script>\n"
        } else {
            // Inline import, not src=: the PackageToJS bundle's index.js only
            // EXPORTS `init` — a bare `src=` script loads but never boots.
            out += "<script type=\"module\">import { init } from "
                + HTMLEscaping.scriptJSON(PWAAssets.jsonString(entryURL))
                + "; await window.__swiftwui_interop_ready; await init();</script>\n"
        }
        // The <template> rides along inert until the shim clones it. It lands in
        // <head> here, where the marker region lives; the shim inserts the clone
        // into <body> for exactly that case.
        out += shell?.html ?? ""
        return out
    }
}
