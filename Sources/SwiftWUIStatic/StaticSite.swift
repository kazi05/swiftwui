import Foundation
import SwiftWUI

public enum StaticSiteMode {
    case hydrate(wasmScriptPath: String)
    case staticOnly
}

public struct StaticSiteConfig {
    public var outDir: String
    public var mode: StaticSiteMode
    public var paths: [String]
    public var cssFile: Bool
    public init(outDir: String, mode: StaticSiteMode, paths: [String] = [], cssFile: Bool = false) {
        self.outDir = outDir
        self.mode = mode
        self.paths = paths
        self.cssFile = cssFile
    }
}

public enum StaticSiteError: Error, CustomStringConvertible {
    case buildTaskOverflow(page: String, iterations: Int)
    case io(path: String, underlying: String)
    public var description: String {
        switch self {
        case .buildTaskOverflow(let page, let iterations):
            return "StaticSite: page '\(page)' never quiesced after \(iterations) build-task iterations"
        case .io(let path, let underlying):
            return "StaticSite: failed writing '\(path)': \(underlying)"
        }
    }
}

public struct StaticSiteReport {
    public var pages: [String]                    // generated page paths
    public var redirects: [String: String]        // page → target (stub emitted)
    public var skippedPatterns: [String]          // dynamic patterns with no explicit path
}

public enum StaticSite {
    /// Renders one page per enumerated path (spec §5): a fresh native
    /// Runtime<MockBackend> per page — guards, redirects, effects and state
    /// behave exactly as in the browser.
    @MainActor
    public static func generate<A: App>(_ app: A.Type,
                                        config: StaticSiteConfig) async throws -> StaticSiteReport {
        // --- enumerate ---
        let probeBackend = MockBackend()
        let probe = Runtime(backend: probeBackend, container: probeBackend.container,
                            root: A().body, scheduleMicrotask: { $0() },
                            globalStyles: A.globalStyles, themes: A.themes)
        probe._effects._buildMode = true      // enumeration must not run "/"'s effects for real
        probe.mount()
        let patterns = probe._collectRoutes()
        var pagePaths: [String] = []
        var skipped: [String] = []
        var claimed = Set<String>()
        for pattern in patterns {
            if pattern.isStatic {
                pagePaths.append(pattern.raw)
            } else {
                let matching = config.paths.filter { pattern.match($0) != nil && !claimed.contains($0) }
                if matching.isEmpty {
                    skipped.append(pattern.raw)
                } else {
                    pagePaths.append(contentsOf: matching)
                    claimed.formUnion(matching)          // first-match-wins, like the Router
                }
            }
        }

        // --- render each page ---
        var report = StaticSiteReport(pages: [], redirects: [:], skippedPatterns: skipped)
        // cssFile mode: union at PAGE-TEXT granularity — registry text is not
        // guaranteed line-per-rule (media blocks), so we dedup whole page
        // registries in first-seen order. Overlap duplicates rules, which is
        // harmless (CSS is idempotent) — optimize only if it ever matters.
        var cssUnion: [String] = []
        var cssSeen = Set<String>()
        var documents: [(path: String, html: String)] = []

        for path in pagePaths {
            let (html, css, redirect) = try await renderPage(A.self, path: path, config: config)
            if let redirect {
                report.redirects[path] = redirect
                documents.append((path, redirectStub(to: redirect)))
                continue
            }
            report.pages.append(path)
            if config.cssFile, !css.isEmpty, cssSeen.insert(css).inserted {
                cssUnion.append(css)
            }
            documents.append((path, html))
        }

        // --- write files ---
        let fm = FileManager.default
        for (path, html) in documents {
            // Query strings (e.g. "/todo?f=active") are not distinct SSG
            // outputs — strip to the path for the directory (documented
            // limitation: query-variant pages collapse to one output).
            let cleanPath = path.firstIndex(of: "?").map { String(path[..<$0]) } ?? path
            let dir = cleanPath == "/" ? config.outDir : config.outDir + cleanPath
            do {
                try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try html.write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
            } catch {
                throw StaticSiteError.io(path: dir + "/index.html", underlying: "\(error)")
            }
        }
        if config.cssFile {
            let cssPath = config.outDir + "/styles.css"
            do { try cssUnion.joined(separator: "\n").write(toFile: cssPath, atomically: true, encoding: .utf8) }
            catch { throw StaticSiteError.io(path: cssPath, underlying: "\(error)") }
        }
        return report
    }

    /// Meta-refresh stub for guard-redirected pages (spec D4).
    static func redirectStub(to target: String) -> String {
        "<!doctype html>\n<meta http-equiv=\"refresh\" content=\"0; url="
            + HTMLEscaping.text(target) + "\">\n"
    }

    @MainActor
    private static func renderPage<A: App>(_ app: A.Type, path: String,
                                           config: StaticSiteConfig) async throws
        -> (html: String, css: String, redirect: String?) {
        // Immediate-drain scheduler: microtasks run synchronously in order.
        var queue: [() -> Void] = []
        var draining = false
        func pump() {
            guard !draining else { return }
            draining = true
            while !queue.isEmpty { queue.removeFirst()() }
            draining = false
        }
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: A().body, initialPath: path,
                              scheduleMicrotask: { queue.append($0) },
                              globalStyles: A.globalStyles, themes: A.themes)
        runtime._effects._buildMode = true
        runtime.mount()
        pump()                                     // guards/redirect hops settle here

        // Build-task loop (spec §6, D5): cap mirrors the redirect-hop cap.
        var iterations = 0
        while true {
            let pending = runtime._effects._drainBuildTasks()
            if pending.isEmpty { break }
            iterations += 1
            guard iterations <= 10 else {
                throw StaticSiteError.buildTaskOverflow(page: path, iterations: iterations)
            }
            for task in pending {
                await task.action()               // awaited sequentially, MainActor
                runtime._effects._recordBuildCompleted(task.id)
            }
            pump()                                 // state writes → re-render → possibly new tasks
        }

        // Redirect detection: the runtime settled on a different location.
        // _locationPath is query-stripped by Runtime; compare like-for-like or
        // query paths misclassify as self-redirect stubs (infinite refresh).
        let settled = runtime._locationPath
        let requestedPath = path.firstIndex(of: "?").map { String(path[..<$0]) } ?? path
        if settled != RouteURL._normalize(requestedPath) {
            return ("", "", settled)
        }

        guard case .component(let rootComponent)? = runtime._currentTree else {
            return ("", runtime._registryText, nil)     // empty page (no route matched)
        }
        let body = HTMLRenderer._render(rootComponent.children)
        let css = runtime._registryText
        var snapshot: String? = nil
        if case .hydrate = config.mode {
            let rows = runtime._store._encodeSnapshotRows(SnapshotJSON.encodeSlot)
            snapshot = SnapshotJSON.assemble(version: 1, path: settled, rows: rows,
                                             tasks: runtime._effects._completedBuildKeys)
        }
        var wasmPath: String? = nil
        if case .hydrate(let p) = config.mode { wasmPath = p }
        let doc = DocumentSerializer.render(.init(
            bodyHTML: body,
            css: config.cssFile ? nil : css,
            cssHref: config.cssFile ? "/styles.css" : nil,
            head: runtime._pageHead,
            snapshotJSON: snapshot,
            wasmScriptPath: wasmPath))
        return (doc, css, nil)
    }
}
