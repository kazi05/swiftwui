#if STATIC_DUMP
import Testing
import Foundation
import SwiftWUI
import SwiftWUIRuntime
import SwiftWUIStyles
@testable import Showcase

@Suite("Static dump")
struct StaticDumpTests {
    @Test func dumpAllRoutesToStaticHTML() throws {
        let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("static-dump")
        try? FileManager.default.removeItem(at: outDir)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let routes: [(String, AnyTag)] = [
            ("index.html",           AnyTag(HomePage())),
            ("learn-hello.html",     AnyTag(HelloPage())),
            ("learn-state.html",     AnyTag(StatePage())),
            ("learn-modifiers.html", AnyTag(ModifiersPage())),
            ("learn-lists.html",     AnyTag(ListsPage())),
            ("learn-forms.html",     AnyTag(FormsPage())),
            ("learn-routing.html",   AnyTag(RoutingPage())),
            ("learn-async.html",     AnyTag(AsyncPage())),
            ("learn-theming.html",   AnyTag(ThemingPage())),
            ("learn-a11y.html",      AnyTag(A11yPage())),
            ("learn-errors.html",    AnyTag(ErrorsPage())),
            ("learn-ssr.html",       AnyTag(SSRPage())),
            ("learn-pwa.html",       AnyTag(PWAPage())),
        ]

        let css = ThemeCSS.definitions(light: ShowcaseTheme.light, dark: ShowcaseTheme.dark)
        let renderer = StaticRenderer()

        for (filename, tag) in routes {
            let body = renderer.renderFragment(tag)
            let doc = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>SwiftWUI Showcase — \(filename)</title>
                <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/styles/atom-one-dark.min.css">
                <script src="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/lib/core.min.js"></script>
                <script src="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/languages/swift.min.js"></script>
                <style>
                    html, body { margin: 0; padding: 0; }
                    body { font-family: var(--font-text, system-ui), sans-serif; }
                    \(css)
                </style>
                <script>
                    (function() {
                        try {
                            var t = localStorage.getItem("swui-theme");
                            if (t === "light" || t === "dark") {
                                document.documentElement.dataset.theme = t;
                            }
                        } catch (_) {}
                    })();
                </script>
            </head>
            <body>
                <div id="app">\(body)</div>
                <script>
                    if (window.hljs) { hljs.highlightAll(); }
                    // Rewrite SPA-style hrefs to flat HTML files so navigation
                    // works when serving from a flat directory via http.server.
                    document.querySelectorAll('a[href^="/learn/"]').forEach(function(a) {
                        var path = a.getAttribute('href').slice(1).replace(/\\//g, '-');
                        a.setAttribute('href', path + '.html');
                    });
                    document.querySelectorAll('a[href="/"]').forEach(function(a) {
                        a.setAttribute('href', 'index.html');
                    });
                </script>
            </body>
            </html>
            """
            let url = outDir.appendingPathComponent(filename)
            try doc.write(to: url, atomically: true, encoding: .utf8)
        }

        let manifest = routes.map { $0.0 }.joined(separator: "\n")
        try manifest.write(
            to: outDir.appendingPathComponent("MANIFEST.txt"),
            atomically: true,
            encoding: .utf8
        )

        print("Wrote \(routes.count) static HTML files to: \(outDir.path)")
    }
}
#endif
