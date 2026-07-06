/// Ordered curriculum (spec §3). Content tasks replace stub entries with the
/// full `ChXX.chapter` definitions; slugs/order/kinds are FINAL here.
public enum Curriculum {
    public static let chapters: [Chapter] = [
        Ch01.chapter,
        Ch02.chapter,
        Ch03.chapter,
        Ch04.chapter,
        Ch05.chapter,
        Ch06.chapter,
        Ch07.chapter,
        Chapter(slug: "route-between-pages", track: .routing, kicker: "CHAPTER · ROUTING",
                title: "Route between pages",
                tagline: "Declare routes as data, render a Tag per path, and let the framework drive browser history.",
                minutes: 20, kind: .chapter),
        Chapter(slug: "wrap-up-routing", track: .routing, kicker: "WRAP-UP · ROUTING",
                title: "Wrap-up: Routing",
                tagline: "Routes, links, and identity — recapped.",
                minutes: 5, kind: .wrapUp),
        Chapter(slug: "prerender-and-hydrate", track: .ship, kicker: "CHAPTER · SHIP",
                title: "Prerender and hydrate",
                tagline: "Static HTML at build time for instant first paint; the WASM runtime hydrates it into a live app.",
                minutes: 20, kind: .chapter),
        Chapter(slug: "deploy-with-docker", track: .ship, kicker: "CHAPTER · SHIP",
                title: "Deploy with Docker",
                tagline: "One reproducible image: build the wasm bundle, prerender, export static files.",
                minutes: 15, kind: .chapter),
        Chapter(slug: "wrap-up-ship", track: .ship, kicker: "WRAP-UP · SHIP",
                title: "Wrap-up: Ship",
                tagline: "SSG, hydration, and deployment — recapped.",
                minutes: 5, kind: .wrapUp),
    ]

    public static func chapter(slug: String) -> Chapter? {
        chapters.first { $0.slug == slug && $0.kind != .overview }
    }

    public static var overview: Chapter { chapters[0] }

    /// Next chapter in curriculum order; the LAST page wraps to the overview
    /// ("Explore more tutorials", spec §3). The overview itself has no next.
    public static func next(after chapter: Chapter) -> Chapter? {
        guard chapter.kind != .overview,
              let i = chapters.firstIndex(where: { $0.slug == chapter.slug }) else { return nil }
        return i + 1 < chapters.count ? chapters[i + 1] : overview
    }

    /// The 11 dynamic ssg paths (overview excluded — it is the static "/" route, spec §11).
    public static var ssgPaths: [String] {
        chapters.filter { $0.kind != .overview }.map(\.path)
    }
}
