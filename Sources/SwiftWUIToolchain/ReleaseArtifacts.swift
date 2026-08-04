import Foundation

/// Release-build extras: precompressed .gz/.br siblings for dist files and a
/// ready-to-deploy dist/nginx.conf (spec 2026-07-15-release-artifacts.md).
public enum ReleaseArtifacts {
    /// Extensions worth precompressing (allowlist; already-compressed formats —
    /// png/webp/woff2/zip/… — are excluded by omission).
    static let compressibleExtensions: Set<String> =
        ["wasm", "js", "mjs", "css", "html", "json", "svg", "txt", "xml", "map", "ts", "webmanifest"]
    static let minSize = 1024  // below this, compression headers outweigh savings

    public struct Summary {
        public var gzipped: Int
        public var brotlied: Int
        public var brotliAvailable: Bool
    }

    /// A `.gz`/`.br` file is FRAMEWORK-OWNED iff its base name's extension is in
    /// `compressibleExtensions`. `index.html.gz` → ours; a user asset
    /// `foo.tar.gz` copied from public/ → never touched (tar ∉ set).
    static func isOwnedCompressed(relPath: String) -> Bool {
        let ns = relPath as NSString
        guard ns.pathExtension == "gz" || ns.pathExtension == "br" else { return false }
        let baseExt = (ns.deletingPathExtension as NSString).pathExtension
        return compressibleExtensions.contains(baseExt)
    }

    /// 1. Remove framework-owned .gz/.br whose base file no longer exists.
    /// 2. For every eligible file regenerate `.gz` (always) and `.br` (when
    ///    brotli is installed) — unconditional regeneration, no mtime compare
    ///    (stale-sibling bugs beat a few wasted seconds).
    /// Never fails the build: missing gzip → warn+skip; missing brotli → hint.
    @discardableResult
    public static func compress(distDir: String, runner: ProcessRunner) throws -> Summary {
        let fm = FileManager.default
        let files = distFiles(distDir)

        // Drop framework-owned orphans (base file gone → stale sibling).
        for rel in files where isOwnedCompressed(relPath: rel) {
            let base = (rel as NSString).deletingPathExtension
            if !fm.fileExists(atPath: distDir + "/" + base) {
                try? fm.removeItem(atPath: distDir + "/" + rel)
            }
        }

        let brotli = toolAvailable("brotli", runner: runner)
        var summary = Summary(gzipped: 0, brotlied: 0, brotliAvailable: brotli)

        guard toolAvailable("gzip", runner: runner) else {
            print("warning: gzip not found — skipping precompression (dist ships uncompressed).")
            return summary
        }
        if !brotli {
            print("hint: brotli not found — shipping gzip only. Install brotli for smaller .br artifacts: `brew install brotli` (macOS) or your distro's brotli package (Linux).")
        }

        for rel in files where isEligible(relPath: rel, distDir: distDir) {
            let full = distDir + "/" + rel
            // -n → no name/timestamp header → byte-identical output across runs.
            if let r = try? runner.run("gzip", ["-kfn9", full], cwd: nil, streamOutput: false), r.exitCode == 0 {
                summary.gzipped += 1
            }
            if brotli, let r = try? runner.run("brotli", ["-f", "-q", "11", full], cwd: nil, streamOutput: false), r.exitCode == 0 {
                summary.brotlied += 1
            }
        }
        return summary
    }

    /// Remove ALL framework-owned .gz/.br (debug builds call this so a stale
    /// release-compressed sibling never shadows a fresh debug file).
    public static func clean(distDir: String) throws {
        let fm = FileManager.default
        for rel in distFiles(distDir) where isOwnedCompressed(relPath: rel) {
            try? fm.removeItem(atPath: distDir + "/" + rel)
        }
    }

    /// True when dist contains any framework-owned .gz/.br — `ssg` uses this to
    /// decide whether to refresh compression after rewriting index.html files.
    public static func hasCompressedArtifacts(distDir: String) -> Bool {
        distFiles(distDir).contains { isOwnedCompressed(relPath: $0) }
    }

    /// Does every document in dist name the wasm with the version the binary in
    /// `dist/app` actually hashes to?
    ///
    /// This is the precondition for an immutable cache header, and it is a
    /// property of the whole dist, not of the last file written. `swiftwui build`
    /// rewrites only the root index.html: any per-route prerender left over from
    /// an earlier `swiftwui ssg` still names the previous `?v=`, and pinning that
    /// URL for a year against a binary that has since changed is the worst
    /// outcome this feature can produce — no later deploy can dislodge it,
    /// because the stale document never stops asking for the stale token.
    ///
    /// - Returns: `versioned` — at least one document carries the current token
    ///   and none carries a different one; `stale` — the dist-relative paths that
    ///   disagree, for the caller to name in a warning.
    public static func auditWasmVersions(distDir: String) -> (versioned: Bool, stale: [String]) {
        guard let name = WasmDigest.wasmName(inAppDir: distDir + "/app"),
              let stamp = WasmDigest.stamp(path: distDir + "/app/" + name) else { return (false, []) }
        let expected = WasmDigest.version(stamp)
        var current = false
        var stale: [String] = []
        for rel in distFiles(distDir) where (rel as NSString).lastPathComponent == "index.html" {
            guard let html = try? String(contentsOfFile: distDir + "/" + rel, encoding: .utf8),
                  let token = wasmVersion(inHTML: html) else { continue }
            if token == expected { current = true } else { stale.append(rel) }
        }
        return (current && stale.isEmpty, stale.sorted())
    }

    /// The `?v=` token a document stamps on the wasm URL, or nil when it names no
    /// wasm (a project without a boot UI) or names it without a version — both of
    /// which the map already answers with `no-cache`, so neither is "stale".
    /// Reads `data-wasm`, the attribute both emitters write: `BootSplice.render`
    /// for the SPA document and `DocumentSerializer.render` for the prerenders.
    static func wasmVersion(inHTML html: String) -> String? {
        guard let attr = html.range(of: "data-wasm=\""),
              let end = html.range(of: "\"", range: attr.upperBound..<html.endIndex) else { return nil }
        let url = html[attr.upperBound..<end.lowerBound]
        guard let q = url.range(of: "?v=") else { return nil }
        return String(url[q.upperBound...])
    }

    /// Overwrite dist/nginx.conf (dist is build output; not user-owned).
    /// A `.negotiated` site descriptor adds cookie/Accept-Language rewriting;
    /// every other site gets byte-for-byte the config it always got.
    ///
    /// `wasmVersioned` is `auditWasmVersions(distDir:).versioned` — read it from
    /// there rather than guessing, and never leave the default at a call site
    /// that could be looking at a versioned dist: false only weakens caching,
    /// but a build followed by an `ssg` that passes the default silently strips
    /// the header the build just wrote.
    public static func writeNginxConf(distDir: String, site: LocaleNegotiation.Site? = nil,
                                      wasmVersioned: Bool = false) throws {
        try nginxConfText(site: site, wasmVersioned: wasmVersioned)
            .write(toFile: distDir + "/nginx.conf", atomically: true, encoding: .utf8)
    }

    /// The generated config, so tests can read it without a temp directory.
    static func nginxConfText(site: LocaleNegotiation.Site? = nil, wasmVersioned: Bool = false) -> String {
        // `map` is only legal in the http block, `location` only inside
        // `server` — hence separate anchors rather than one.
        var maps = ""
        var location = defaultLocationBlock
        if let site, site.isNegotiated, !site.locales.isEmpty {
            maps = negotiationMaps(site: site) + "\n"
            location = negotiationLocation
        }
        // The map defines $swui_wasm_cc; emitting the location block without it
        // makes nginx refuse to start on an unknown variable, so the two are one
        // decision. Unversioned dists get byte-for-byte the block they got before.
        if wasmVersioned { maps += wasmCacheMap + "\n" }
        var text = nginxConf
        text = text.replacingOccurrences(of: mapsAnchor, with: maps)
        text = text.replacingOccurrences(of: locationAnchor, with: location)
        text = text.replacingOccurrences(of: wasmAnchor,
                                         with: wasmVersioned ? versionedWasmBlocks : plainWasmBlock)
        return text
    }

    // Anchors include their own newline so an unused one leaves no blank line.
    static let mapsAnchor = "#__SWIFTWUI_MAPS__\n"
    static let locationAnchor = "#__SWIFTWUI_LOCATION__"
    static let wasmAnchor = "#__SWIFTWUI_WASM__"

    /// `$arg_v` is the empty string when the URL carries no `?v=`, and `~.`
    /// needs one character — so only a stamped request is ever pinned.
    static let wasmCacheMap = """
    # Cache policy for the versioned wasm URL the boot shim requests.
    map $arg_v $swui_wasm_cc {
        default "no-cache";
        "~."    "public, max-age=31536000, immutable";
    }
    """

    /// MIME only — what every build shipped before versioned boot URLs, and what
    /// a dist whose documents carry no `?v=` still gets.
    static let plainWasmBlock = """
    # WebAssembly MIME type — instantiateStreaming requires it; distro
        # mime.types before nginx 1.21.4 lack the entry.
        location ~ \\.wasm$ {
            types {}
            default_type application/wasm;
        }
    """

    /// Same MIME rule, plus a year on the bundle's binary when — and only when —
    /// the request names a version.
    ///
    /// The ORDER of the two blocks is the whole design. nginx serves the first
    /// matching regex location and a regex beats any prefix location outright,
    /// so the `/app/` rule has to be the first wasm regex in the file: a second
    /// one added below is unreachable, and a `location /app/ { }` prefix block
    /// never runs at all. Both mistakes look fine in a smoke test, because
    /// `no-cache` revalidates to a 304.
    static let versionedWasmBlocks = """
    # WebAssembly MIME type — instantiateStreaming requires it; distro
        # mime.types before nginx 1.21.4 lack the entry.
        #
        # Cache-Control comes from $swui_wasm_cc: a request without ?v= did not
        # boot through the shim (a hand-written index.html, or a build with
        # nowhere to splice) and must not be pinned for a year.
        #
        # A location-level add_header REPLACES every inherited one, so a
        # `.negotiated` site's `Vary: Accept-Language, Cookie` does not reach
        # here. That is deliberate: /app/ is the same bytes for every locale.
        #
        # Only the wasm is immutable. The rest of /app/ — index.js, runtime.js,
        # bridge-js.js, ~25 KB — stays no-cache, because index.js imports
        # ./instantiate.js relatively and a query is not inherited: pinning the
        # bundle would strand half of it in caches permanently.
        location ~ ^/app/.*\\.wasm$ {
            types {}
            default_type application/wasm;
            add_header Cache-Control $swui_wasm_cc;
        }

        # User wasm copied from public/ — MIME only, no caching claim.
        location ~ \\.wasm$ {
            types {}
            default_type application/wasm;
        }
    """

    static let defaultLocationBlock = """
    # SPA fallback; `swiftwui ssg` per-route prerenders are served via $uri/.
        location / { try_files $uri $uri/ /index.html; }
    """

    static let negotiationLocation = """
    add_header Vary "Accept-Language, Cookie";
        # $uri first: root-level assets are never locale-prefixed.
        location / { try_files $uri /$swui_locale$uri/index.html /$swui_locale/index.html /index.html; }
    """

    /// The http-block half of the negotiation: cookie first, then the first tag
    /// of `Accept-Language`, then the default locale.
    static func negotiationMaps(site: LocaleNegotiation.Site) -> String {
        let ordered = LocaleNegotiation.regexOrdered(site.locales)
        let alternatives = ordered.joined(separator: "|")
        var out = """
        # Locale negotiation (.negotiated strategy): cookie wins, then Accept-Language.
        # These map regexes are first-match, so the "first tag in the header" rules
        # all come before the "somewhere later in the header" ones — an approximation
        # of q-ordering. The cookie, written after an explicit user choice, is exact.
        map $http_cookie $swui_cookie_locale {
            default "";
            "~*(?:^|;\\s*)\(LocaleNegotiation.cookieName)=(?<l>\(alternatives))(?:;|$)" $l;
        }
        map $http_accept_language $swui_al_locale {
            default "\(site.defaultLocale)";

        """
        // `\\s` in a plain string literal is one backslash — what PCRE wants.
        for locale in ordered { out += "    \"~*^\\s*\(locale)\" \"\(locale)\";\n" }
        for locale in ordered { out += "    \"~*,\\s*\(locale)\" \"\(locale)\";\n" }
        out += """
        }
        map "$swui_cookie_locale:$swui_al_locale" $swui_locale {
            default            "\(site.defaultLocale)";
            "~^:(?<al>.+)$"    $al;
            "~^(?<c>[^:]+):"   $c;
        }
        """
        return out
    }

    /// `which <tool>` via runner; used for wasm-opt/brotli/gzip probes.
    public static func toolAvailable(_ tool: String, runner: ProcessRunner) -> Bool {
        guard let r = try? runner.run("which", [tool], cwd: nil, streamOutput: false) else { return false }
        return r.exitCode == 0
    }

    // Eligible for compression: real file, ext ∈ set, ≥ minSize, not itself a
    // compressed sibling, not nginx.conf, not a dotfile.
    static func isEligible(relPath: String, distDir: String) -> Bool {
        let ns = relPath as NSString
        let name = ns.lastPathComponent
        if name.hasPrefix(".") || name == "nginx.conf" { return false }
        let ext = ns.pathExtension
        if ext == "gz" || ext == "br" { return false }
        guard compressibleExtensions.contains(ext) else { return false }
        let attrs = try? FileManager.default.attributesOfItem(atPath: distDir + "/" + relPath)
        return ((attrs?[.size] as? NSNumber)?.intValue ?? 0) >= minSize
    }

    // Recursive relative paths of regular files under distDir (directories and
    // symlinked dirs skipped; symlinked-dir hard-error stays PWA-only, spec).
    static func distFiles(_ distDir: String) -> [String] {
        let fm = FileManager.default
        guard let en = fm.enumerator(atPath: distDir) else { return [] }
        var out: [String] = []
        while let rel = en.nextObject() as? String {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: distDir + "/" + rel, isDirectory: &isDir), !isDir.boolValue {
                out.append(rel)
            }
        }
        return out
    }

    static let nginxConf = """
    # Generated by `swiftwui build -c release` — regenerated on every release build.
    # Deploy: copy dist/ to the server, set `root` below, then place this file at
    # /etc/nginx/conf.d/<app>.conf (or include it from your nginx.conf http block).
    #__SWIFTWUI_MAPS__
    server {
        listen 80;
        listen [::]:80;
        server_name _;

        root /var/www/app;  # <-- set to the deployed dist/ path
        index index.html;

        gzip_static on;      # serve the .gz artifacts emitted by the release build
        #brotli_static on;   # serve the .br artifacts — requires the ngx_brotli module

        gzip on;             # runtime fallback for responses without a precompressed sibling
        gzip_types application/wasm application/javascript text/css application/json image/svg+xml;
        gzip_min_length 1024;

        # Bundle file names are not content-hashed -> always revalidate (ETag/304).
        # Do NOT give this server-level header a long max-age: it covers
        # index.html and the /app/ JS, none of which carry a version, and
        # index.js imports ./instantiate.js relatively. The one asset that IS
        # versioned — the wasm — overrides this from its own location below.
        add_header Cache-Control "no-cache";

        location = /nginx.conf { return 404; }  # this file ships inside dist/

        #__SWIFTWUI_WASM__

        #__SWIFTWUI_LOCATION__
    }

    """
}
