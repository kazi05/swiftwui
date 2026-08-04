import Foundation
import SwiftWUI

public enum DevInjection {
    /// Gates `?swui-boot=` in the shim. Dev-served documents only: in a built
    /// dist/ a forced `failed` on a real URL is a dead page with the site's own
    /// content veiled behind its error UI.
    static let devFlag = #"<script>window.__swiftwui_dev = true;</script>"#

    /// The flag script MUST run before the app module loads — injection right
    /// after <head> guarantees it (module scripts are deferred by spec).
    static let snippet = devFlag + #"<script src="/__swiftwui/dev-client.js"></script>"#

    /// `swiftwui dev` never runs `boot-shell`: on localhost the boot finishes
    /// inside the delay so a shell would never be shown, and a host compile per
    /// rebuild would roughly double hot-reload latency. So the config travels
    /// with an EMPTY shell — the shim runs, `?swui-boot=` works, and nothing is
    /// rendered until an author's own shell arrives via `swiftwui build`.
    static let devDelayMS = 300

    private nonisolated(unsafe) static var warnedNoAnchor = false

    /// `nil` wasmURL (no build yet, or a failed first build) falls back to the
    /// inline `import { init }` the templates used to carry: `index.js` then
    /// fetches the binary itself, relative to its own URL. The page still boots,
    /// only without progress — better than naming a wasm we could not find.
    public static func inject(into html: String, wasmURL: String? = nil) -> String {
        let config = wasmURL.map {
            BootConfig(wasmURL: $0, entryURL: BootSplice.entryURL,
                       // Dev serves the shim from its own handler, at the path
                       // the entry's directory implies (`DevSession.shimPath`).
                       shimURL: DevSession.shimPath, sizeBytes: nil, delayMS: devDelayMS)
        }
        // Same emitter as `swiftwui build`, so dev and dist cannot drift on the
        // shim's contract — and it lands in the template's marker region, the
        // one spot guaranteed to sit BELOW the import map. Processing a
        // modulepreload disallows any later map, and the bundle's bare
        // "@bjorn3/browser_wasi_shim" import would then never resolve.
        //
        // nil = a document with neither the marker nor a </head>, which has no
        // import map either and so could not boot whatever we injected. Said
        // out loud, like `BootSplice.write` does for the same shape: a page
        // that silently never boots is the failure this whole path exists to end.
        var booted = html
        if let spliced = BootSplice.apply(html: html, shell: nil, config: config) { booted = spliced }
        else if !warnedNoAnchor {
            // Once per process — the index is re-injected on every request, and
            // one line per page load would bury itself. A torn write costs a
            // duplicate warning, which is why this needs no lock.
            warnedNoAnchor = true
            print("warning: index.html has neither a \(BootSplice.open) marker nor a </head> — "
                + "nothing starts the app")
        }
        return insertAfterHead(snippet, into: booted)
    }

    /// After `<head>` — above the import map, which is fine for these two
    /// classic scripts and load-bearing for the flag: it has to be set before
    /// any module runs.
    static func insertAfterHead(_ s: String, into html: String) -> String {
        guard let range = html.range(of: "<head>", options: .caseInsensitive) else {
            return s + html   // headless documents: prepend (spec §6)
        }
        var out = html
        out.insert(contentsOf: s, at: range.upperBound)
        return out
    }

    /// `swiftwui serve --boot-debug`: the dev flag, and nothing else, over a
    /// built dist/ so `?swui-boot=slow|fail|stall` can be previewed against a
    /// real build. Wraps the static handler rather than special-casing
    /// index.html — an ssg dist keeps a document per route and the boot states
    /// are worth previewing on all of them.
    public static func bootDebugFlag(wrapping handler: @escaping HTTPHandler) -> HTTPHandler {
        { request in
            guard var response = handler(request) else { return nil }
            guard response.headers["Content-Type"]?.hasPrefix("text/html") == true else { return response }
            let html = insertAfterHead(devFlag, into: String(decoding: response.body, as: UTF8.self))
            response.body = Array(html.utf8)
            return response
        }
    }

    /// Single-line JSON string literal for SSE data frames.
    public static func jsonStringLiteral(_ s: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [s])
        guard let data, var text = String(data: data, encoding: .utf8) else { return "\"\"" }
        text.removeFirst()   // strip the array brackets: ["..."] → "..."
        text.removeLast()
        return text
    }
}
