/// Ordered curriculum (spec §3). Content tasks replace stub entries with the
/// full `ChXX.chapter` definitions; slugs/order/kinds are FINAL here.
public enum Curriculum {
    /// Reading order. Track grouping on the overview comes from `Track.allCases`,
    /// so this array and that enum's declaration order have to agree.
    public static let chapters: [Chapter] = [
        Ch01.chapter,   // overview
        Ch02.chapter,   // welcome
        Ch03.chapter,
        Ch04.chapter,   // explore
        Ch05.chapter,
        Ch06.chapter,   // styles
        Ch14.chapter,
        Ch07.chapter,
        Ch15.chapter,   // interact
        Ch16.chapter,
        Ch08.chapter,   // routing
        Ch09.chapter,
        Ch12.chapter,   // motion
        Ch17.chapter,
        Ch18.chapter,   // data
        Ch10.chapter,   // ship
        Ch19.chapter,
        Ch20.chapter,
        Ch11.chapter,
        Ch13.chapter,
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
