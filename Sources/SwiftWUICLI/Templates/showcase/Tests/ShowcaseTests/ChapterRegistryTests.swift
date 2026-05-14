import Testing
@testable import {{PROJECT_NAME}}

@Suite("ChapterRegistry")
struct ChapterRegistryTests {
    @Test("Contains 12 chapters grouped in 3 sections")
    func count() {
        #expect(ChapterRegistry.all.count == 12)
        let groups = Set(ChapterRegistry.all.map(\.group))
        #expect(groups == ["Essentials", "Building UI", "Production"])
    }

    @Test("Each chapter has unique id and path")
    func unique() {
        let ids = ChapterRegistry.all.map(\.id)
        let paths = ChapterRegistry.all.map(\.path)
        #expect(Set(ids).count == ids.count)
        #expect(Set(paths).count == paths.count)
    }

    @Test("Path for id resolves both directions")
    func lookup() {
        let hello = ChapterRegistry.chapter(forID: "hello")
        #expect(hello?.path == "/learn/hello")
        let byPath = ChapterRegistry.chapter(forPath: "/learn/state")
        #expect(byPath?.id == "state")
    }
}
