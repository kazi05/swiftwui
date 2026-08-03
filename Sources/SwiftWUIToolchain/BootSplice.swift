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

    /// Splices `<outDir>/index.html` — never the project's own, which is
    /// user-owned. Returns whether the document ends up naming the wasm with a
    /// `?v=` digest; false also means "no immutable cache header over the
    /// binary", since nothing then busts it.
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
            // The entry's OWN directory, not a hardcoded "/app/" — the same
            // derivation the SSG makes, so the two never disagree about where
            // the shim just copied above is served from.
            let dir = entryURL.lastIndex(of: "/").map { String(entryURL[...$0]) } ?? "/app/"
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
                + "left unmodified, so nothing starts the app. The boot shim was not copied "
                + "either, so any ssg-prerendered page will fail into its boot failure UI.")
            return false
        }
        // After the guard, never before: on the nowhere-to-splice path nothing
        // names the shim, and an orphan in dist/app would still be precached.
        if shell != nil { try DistLayout.copyBootShim(outDir: outDir) }
        try spliced.write(toFile: index, atomically: true, encoding: .utf8)
        return versioned
    }

    /// Replaces the paired marker region wholesale — idempotent across rebuilds,
    /// so a stale `?v=` cannot survive one. Falls back to the `</head>` anchor
    /// for projects scaffolded before the marker existed. nil = leave the file
    /// alone (the caller then also suppresses the immutable wasm header, since
    /// nothing will carry `?v=`).
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
        guard let head = html.range(of: "</head>", options: .caseInsensitive) else { return nil }
        return html.replacingCharacters(in: head.lowerBound..<head.lowerBound, with: block)
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
            out += "<link rel=\"preload\" as=\"fetch\" crossorigin fetchpriority=\"low\" href=\""
                + wasmURL + "\">\n"
            out += "<link rel=\"modulepreload\" href=\"" + shimURL + "\">\n"
            out += "<link rel=\"modulepreload\" href=\"" + entry + "\">\n"
            // The shim owns the import + init() call the else-branch inlines;
            // emitting both would boot the app twice. `data-size` is omitted
            // outright when unknown — the shim reads a missing one as indeterminate.
            out += "<script type=\"module\" src=\"" + shimURL + "\" data-swui-boot-config"
            out += " data-wasm=\"" + wasmURL + "\""
            out += " data-entry=\"" + entry + "\""
            out += config.sizeBytes.map { " data-size=\"\($0)\"" } ?? ""
            out += " data-delay=\"\(config.delayMS)\"></script>\n"
        } else {
            // Inline import, not src=: the PackageToJS bundle's index.js only
            // EXPORTS `init` — a bare `src=` script loads but never boots.
            out += "<script type=\"module\">import { init } from "
                + HTMLEscaping.scriptJSON(PWAAssets.jsonString(entryURL))
                + "; await init();</script>\n"
        }
        // The <template> rides along inert until the shim clones it. It lands in
        // <head> here, where the marker region lives; the shim inserts the clone
        // into <body> for exactly that case.
        out += shell?.html ?? ""
        return out
    }
}
