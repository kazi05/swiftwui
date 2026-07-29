import SwiftWUI
import SwiftWUIDOM

/// The tutorial's second sample app: one runnable tour of everything the
/// later chapters teach. Each chapter pins its code panels to the
/// `// tutorial:begin …` regions in this package, so a panel that drifts from
/// compiled source fails ExcerptSyncTests.

struct TourIndex: Tag, Page {
    var title: String { "SwiftWUI Tour" }
    var body: some Tag {
        Main(class: "tour") {
            H1("SwiftWUI Tour")
            P { "One app per chapter, all compiled together." }
            Ul {
                Li { Link("/responsive") { Span { "Responsive layout" } } }
                Li { Link("/bindings") { Span { "Bindings and events" } } }
                Li { Link("/dropzone") { Span { "Drag, drop and files" } } }
                Li { Link("/motion") { Span { "Keyframes and view transitions" } } }
                Li { Link("/data") { Span { "Data and dependencies" } } }
                Li { Link("/product/nimbus-7") { Span { "Prerendered product page" } } }
            }
        }
    }
}

struct TourRoot: Tag {
    var body: some Tag {
// tutorial:begin tour-routes
        Router(notFound: { Main { H1("404"); Link("/") { Span { "Back to the tour" } } } }) {
            Route("/") { TourIndex() }
            Route("/responsive") { ResponsiveDemo() }
            Route("/bindings") { BindingsDemo() }
            Route("/dropzone") { DropZoneDemo() }
            Route("/motion") { MotionDemo() }

            // Client-only: a signed-in dashboard has nothing to prerender.
            Route("/data") { DataDemo() }
                .prerender(.never)

            // Dynamic pattern: `.build` alone would yield nothing, so the
            // route enumerates its own paths. `.allowingOnDemand()` lets a
            // render server fill in products added after the build.
            Route("/product/:id") { ProductPage() }
                .prerender(.paths { await Catalog.allSlugs() }
                             .allowingOnDemand()
                             .revalidate(.seconds(3600)))
        }
        .pageTransition(.fade)
// tutorial:end tour-routes
    }
}

struct TourApp: App {
    var body: some Tag { TourRoot() }

    @RulesBuilder static var globalStyles: [Rule] {
        Rule(element: "body") { p in
            p.margin(.zero)
            p.fontFamily("system-ui, sans-serif")
            p.background(.hex("#faf9f7"))
            p.color(.hex("#1c1917"))
        }
        Rule(class: "tour") { p in
            p.maxWidth(.px(720))
            p.margin(vertical: .zero, horizontal: .auto)
            p.padding(.px(32))
        }
    }
}

#if canImport(SwiftWUIStatic)
import Foundation
import SwiftWUIStatic

@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "ssg" else {
            print("usage: Tour ssg --out <dir> [--static] [--path <path>] [--no-prerender]")
            return
        }
        args.removeFirst()
        var out = "dist"
        var mode = StaticSiteMode.hydrate(wasmScriptPath: "/app/index.js")
        var onlyPath: String? = nil
// tutorial:begin tour-killswitch
        var prerenderEnabled = PrerenderSwitch.enabled(
            fromEnvironment: ProcessInfo.processInfo.environment[PrerenderSwitch.environmentKey])
// tutorial:end tour-killswitch
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out":
                guard i + 1 < args.count else { print("--out needs a value"); return }
                i += 1; out = args[i]
            case "--static": mode = .staticOnly
            case "--path":
                guard i + 1 < args.count else { print("--path needs a value"); return }
                i += 1; onlyPath = args[i]
            case "--no-prerender": prerenderEnabled = false
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        if let onlyPath {
            // render(path:) is policy-blind on purpose: it renders exactly what
            // it is asked for. Only generate()'s enumeration reads .prerender.
            let page = try await StaticSite.render(TourApp.self, path: onlyPath,
                                                   config: .init(outDir: out, mode: mode,
                                                                 prerenderEnabled: prerenderEnabled))
            switch page.outcome {
            case .page:
                try StaticSite.writeDocument(page.html, path: page.path, outDir: out,
                                             subdir: page.subdir)
                print("rendered \(onlyPath)")
            case .redirect(let target, _): print("\(onlyPath) redirects to \(target); nothing written")
            case .notFound: print("\(onlyPath) matched no route; nothing written")
            case .error(let m): print("render failed: \(m)"); return
            }
            return
        }
// tutorial:begin tour-ssg-config
        let report = try await StaticSite.generate(TourApp.self, config: .init(
            outDir: out,
            mode: mode,
            siteURL: "https://tour.swiftwui.dev",   // canonical links + sitemap.xml
            defaultPrerender: .build,               // for routes that say nothing
            prerenderEnabled: prerenderEnabled))
        print("generated \(report.pages.count) pages, \(report.sitemapFiles.count) sitemap file(s)")
        print("left to a render server: \(report.onDemandPatterns)")
// tutorial:end tour-ssg-config
    }
}
#else
@main enum Entry {
    static func main() { TourApp.main() }
}
#endif
