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

    /// Overwrite dist/nginx.conf (dist is build output; not user-owned).
    public static func writeNginxConf(distDir: String) throws {
        try nginxConf.write(toFile: distDir + "/nginx.conf", atomically: true, encoding: .utf8)
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
        # Deploying under versioned paths? Switch to "public, max-age=31536000, immutable".
        add_header Cache-Control "no-cache";

        location = /nginx.conf { return 404; }  # this file ships inside dist/

        # WebAssembly MIME type — instantiateStreaming requires it; distro
        # mime.types before nginx 1.21.4 lack the entry.
        location ~ \\.wasm$ {
            types {}
            default_type application/wasm;
        }

        # SPA fallback; `swiftwui ssg` per-route prerenders are served via $uri/.
        location / { try_files $uri $uri/ /index.html; }
    }

    """
}
