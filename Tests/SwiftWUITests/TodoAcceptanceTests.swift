import Testing
import Observation
import Foundation
@testable import SwiftWUI
@testable import SwiftWUIStatic

@Observable private final class TodoStore {
    struct Todo: Identifiable, Equatable { let id: Int; var title: String; var done: Bool }
    var todos: [Todo] = []
    var draft = ""
    private var nextID = 1
    var remaining: Int { todos.filter { !$0.done }.count }
    func add() {
        let title = draft.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        todos.append(Todo(id: nextID, title: title, done: false)); nextID += 1
        draft = ""
    }
    func toggle(_ id: Int) { if let i = todos.firstIndex(where: { $0.id == id }) { todos[i].done.toggle() } }
}
private struct StoreKey: EnvironmentKey { static let defaultValue = TodoStore() }
extension EnvironmentValues {
    fileprivate var todoStore: TodoStore { get { self[StoreKey.self] } set { self[StoreKey.self] = newValue } }
}
private enum Filter: String, CaseIterable {
    case all, active, completed
    var path: String { self == .all ? "/" : "/\(rawValue)" }
}

extension ColorToken {
    fileprivate static let accent  = ColorToken("accent")
    fileprivate static let surface = ColorToken("surface")
    fileprivate static let ink     = ColorToken("ink")
}

private final class Counters { var byLabel: [String: Int] = [:]
                               func bump(_ l: String) { byLabel[l, default: 0] += 1 } }

private struct TodoRow: Tag, Styled {
    let todo: TodoStore.Todo
    let counters: Counters
    @Environment(\.todoStore) var store
    @RulesBuilder var styles: [Rule] {
        Rule(class: "done") { s in
            s.textDecoration(.lineThrough)
            s.opacity(0.6)
        }
        Rule(class: "todo") { $0.color(.token(.ink)) }
    }
    var body: some Tag {
        counters.bump("row-\(todo.id)")
        return TupleTag(Input(checked: Binding(get: { todo.done }, set: { _ in store.toggle(todo.id) })),
                         Span(class: todo.done ? "done" : "todo") { todo.title })
    }
}
private struct RemainingLabel: Tag {
    @Environment(\.todoStore) var store
    var body: some Tag { P { "\(store.remaining) items left" } }
}

private struct TodoPage: Tag, Page, Styled {
    let filter: Filter
    let counters: Counters
    @Environment(\.todoStore) var store
    @Environment(\.setTheme) var setTheme
    @State var dark = false
    var title: String { "todos — \(filter.rawValue)" }
    var meta: [MetaTag] { [.description("SwiftWUI TodoMVC — \(filter.rawValue) todos")] }
    @RulesBuilder var styles: [Rule] {
        Rule(class: "filters", media: .maxWidth(.px(600))) { $0.flexDirection(.column) }
        Rule(element: "button") { s in
            s.cursor(.pointer)
            s.hover { $0.background(.token(.accent)) }
        }
    }
    var visible: [TodoStore.Todo] {
        switch filter {
        case .all: store.todos
        case .active: store.todos.filter { !$0.done }
        case .completed: store.todos.filter(\.done)
        }
    }
    var body: some Tag {
        Main {
            H1("todos").color(.token(.accent)).fontSize(.rem(2))
            Input(type: .text, value: Binding(get: { store.draft }, set: { store.draft = $0 }),
                  onKeyDown: { e in if e.key == "Enter" { store.add() } })
                .padding(.px(8))
                .width(.percent(100))
            Ul {
                ForEach(visible) { todo in
                    Li {
                        TodoRow(todo: todo, counters: counters)
                        Link("/todo/\(todo.id)") { Span { "→" } }
                    }
                }
            }
            .listStyle("none")
            RemainingLabel()
            Div(class: "filters") {
                ForEach(Filter.allCases, id: \.rawValue) { f in
                    Link(f.path) { Span { f.rawValue } }
                }
                Button("theme") { dark.toggle(); setTheme(dark ? "dark" : nil) }
            }
            .display(.flex)
            .gap(.px(8))
        }
        .background(.token(.surface))
    }
}

private struct TodoDetail: Tag, Page {
    let id: Int?
    @Environment(\.todoStore) var store
    var todo: TodoStore.Todo? { store.todos.first { $0.id == id } }
    var title: String { "todo #\(id.map(String.init) ?? "?")" }
    var body: some Tag {
        Main {
            if let todo {
                H1(todo.title)
                P { todo.done ? "done" : "active" }
                Button(todo.done ? "reopen" : "complete") { store.toggle(todo.id) }
            } else {
                H1("todo not found")
            }
            Link("/") { Span { "← back" } }
        }
    }
}

private struct TodoApp: Tag {
    let counters: Counters
    @State var store = TodoStore()
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { TodoPage(filter: .all, counters: counters) }
            Route("/active") { TodoPage(filter: .active, counters: counters) }
            Route("/completed") { TodoPage(filter: .completed, counters: counters) }
            Route("/todo/:id") { params in TodoDetail(id: params["id"].flatMap(Int.init)) }
        }
        .environment(\.todoStore, store)
        .task { store.todos = [.init(id: 1000, title: "seeded", done: false)] }
    }
}

@MainActor @Suite struct TodoAcceptanceTests {
    private func makeApp() -> (Runtime<MockBackend>, MockBackend, TestScheduler, Counters) {
        let backend = MockBackend(); let sched = TestScheduler(); let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TodoApp(counters: counters), scheduleMicrotask: sched.schedule,
                         globalStyles: [Rule(element: "body") { $0.margin(.zero) }],
                         themes: [ThemeDefinition { $0.set(ColorToken.accent, .hex("#e94560")) },
                                  ThemeDefinition(name: "dark") { $0.set(ColorToken.accent, .hex("#818cf8")) }])
        rt.mount()
        return (rt, backend, sched, counters)
    }

    /// Bounded wait (Task 9 convention): the `.task` seed runs on a detached
    /// `Task`, so give it up to 100 yields to complete and its dirty flush to
    /// be pumped — deterministic, no sleeps.
    private func waitUntil(_ sched: TestScheduler, _ condition: () -> Bool) async {
        var spins = 0
        while !condition() && spins < 100 { await Task.yield(); sched.pump(); spins += 1 }
    }

    /// Finds the footer filter `<a>` whose label span reads `label`.
    private func filterLink(_ backend: MockBackend, _ label: String) -> MockNode {
        findAll(backend.container, tag: "a").first { $0.children.contains { $0.children.first?.text == label } }!
    }

    @Test func addTodoViaControlledInputAndEnter() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }   // .task seeds one todo
        let input = findFirst(backend.container, tag: "input")!
        rt.dispatch(input.events["input"]!, payload: InputEvent(value: "buy milk"))
        sched.pump()
        rt.dispatch(input.events["keydown"]!, payload: KeyEvent(key: "Enter", repeated: false))
        sched.pump()
        #expect(findAll(backend.container, tag: "li").count == 2)
        #expect(input.props["value"] == .string(""))            // draft cleared
    }

    // NOTE on assertion choice (spec §2.1, brief-authorized alternative):
    // A subtree pass re-resolves the retained TAG for the dirtied owner (here
    // TodoApp, since its body reads `store.todos` via Observation) in one
    // `resolve()` call. That call recurses straight through `ForEach` into
    // every visible `TodoRow`'s body — there is no per-row memoization boundary
    // in phase 2, so toggling one row's checkbox re-runs every row's body
    // (SwiftUI-equivalent semantics: parent re-render reruns children).
    // Verified empirically below: with 3 rows mounted, toggling one bumps all
    // 3 "row-*" counters, not 1 — so `changedRows.count == 1` would be false.
    // The honest, still-meaningful assertions are: (a) pin the real behavior
    // (all rows re-evaluate) instead of asserting a false invariant, and
    // (b) assert what actually matters to users — DOM stability: the `li`
    // count is unchanged and exactly one row's class flips to "done".
    @Test func toggleReevaluatesAllRowsButKeepsDOMStable() async {
        let (rt, backend, sched, counters) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }
        let input = findFirst(backend.container, tag: "input")!
        for title in ["a", "b"] {
            rt.dispatch(input.events["input"]!, payload: InputEvent(value: title)); sched.pump()
            rt.dispatch(input.events["keydown"]!, payload: KeyEvent(key: "Enter", repeated: false)); sched.pump()
        }
        let liCountBefore = findAll(backend.container, tag: "li").count
        #expect(liCountBefore == 3)   // precondition: seed + "a" + "b" all mounted
        let before = counters.byLabel
        let checkbox = findAll(backend.container, tag: "input").first { $0.attrs["type"] == "checkbox" }!
        let toggledLi = checkbox.parent!
        // done/todo class now lives on TodoRow's inner Span (Li itself hosts row + detail Link).
        func rowSpanClass(_ li: MockNode) -> String? { li.children.first { $0.tag == "span" }?.attrs["class"] }
        #expect(rowSpanClass(toggledLi)?.hasPrefix("todo") == true)

        rt.dispatch(checkbox.events["change"]!, payload: ChangeEvent(value: "", checked: true))
        sched.pump()

        let after = counters.byLabel
        let allRowLabels = Set(before.keys).union(after.keys).filter { $0.hasPrefix("row-") }
        let changedRows = allRowLabels.filter { before[$0] != after[$0] }
        #expect(changedRows.count == allRowLabels.count)   // real finding: parent pass reruns EVERY row

        #expect(findAll(backend.container, tag: "li").count == liCountBefore)   // DOM stable: no li added/removed
        #expect(rowSpanClass(toggledLi)?.hasPrefix("done") == true)           // only the toggled row flips
        let otherLis = findAll(backend.container, tag: "li").filter { $0 !== toggledLi }
        #expect(otherLis.allSatisfy { (rowSpanClass($0) ?? "").hasPrefix("todo") })
        // …and the count label updated to the EXACT post-toggle count
        // (Observation: RemainingLabel read store.todos; 3 todos, 1 done → 2 remaining)
        let counts = findAll(backend.container, tag: "p")
        #expect(counts.contains { ($0.children.first?.text ?? "") == "2 items left" })
    }

    @Test func filterSwitchesVisibleRows() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) {
            findAll(backend.container, tag: "input").contains { $0.attrs["type"] == "checkbox" }
        }
        let checkbox = findAll(backend.container, tag: "input").first { $0.attrs["type"] == "checkbox" }!
        rt.dispatch(checkbox.events["change"]!, payload: ChangeEvent(value: "", checked: true))
        sched.pump()
        rt.dispatch(filterLink(backend, "completed").events["click"]!, payload: ClickEvent())
        sched.pump()
        #expect(findAll(backend.container, tag: "li").count == 1)
        rt.dispatch(filterLink(backend, "active").events["click"]!, payload: ClickEvent())
        sched.pump()
        #expect(findAll(backend.container, tag: "li").isEmpty)
    }

    @Test func filterCountsWithMixedTodos() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }
        let input = findFirst(backend.container, tag: "input")!
        for title in ["a", "b"] {   // seed + a + b = 3 todos
            rt.dispatch(input.events["input"]!, payload: InputEvent(value: title)); sched.pump()
            rt.dispatch(input.events["keydown"]!, payload: KeyEvent(key: "Enter", repeated: false)); sched.pump()
        }
        // mark exactly one done → mixed state: 2 active, 1 completed
        let checkbox = findAll(backend.container, tag: "input").first { $0.attrs["type"] == "checkbox" }!
        rt.dispatch(checkbox.events["change"]!, payload: ChangeEvent(value: "", checked: true))
        sched.pump()
        func tap(_ label: String) {
            rt.dispatch(filterLink(backend, label).events["click"]!, payload: ClickEvent()); sched.pump()
        }
        tap("completed"); #expect(findAll(backend.container, tag: "li").count == 1)
        tap("active");    #expect(findAll(backend.container, tag: "li").count == 2)
        tap("all");       #expect(findAll(backend.container, tag: "li").count == 3)
        let counts = findAll(backend.container, tag: "p")
        #expect(counts.contains { ($0.children.first?.text ?? "") == "2 items left" })
    }

    @Test func styledAcceptance() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }
        _ = rt   // silence unused if needed
        // inline style landed
        let h1 = findFirst(backend.container, tag: "h1")!
        #expect(h1.attrs["style"]?.contains("color: var(--accent)") == true)
        // stylesheet: globals, themes, scoped rule, hover, media
        let css = backend.stylesheetText ?? ""
        #expect(css.contains("body { margin: 0 }"))
        #expect(css.contains(":root { --accent: #e94560 }"))
        #expect(css.contains(#"[data-theme="dark"]"#))
        #expect(css.contains(".done."))                       // scoped marker attached
        #expect(css.contains("button.") && css.contains(":hover"))
        #expect(css.contains("@media (max-width: 600px)"))
        // scope marker present on elements of TodoPage's body
        #expect((findFirst(backend.container, tag: "main")!.attrs["class"] ?? "").contains("swui-s"))
    }
    @Test func themeToggleSetsAttribute() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }
        _ = rt
        let themeBtn = findAll(backend.container, tag: "button").first { $0.children.first?.text == "theme" }!
        rt.dispatch(themeBtn.events["click"]!); sched.pump()
        #expect(backend.container.attrs["data-theme"] == "dark")
        rt.dispatch(themeBtn.events["click"]!); sched.pump()
        #expect(backend.container.attrs["data-theme"] == nil)
    }

    @Test func filterRoutesFilterTheList() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }
        // seeded: 1 active (not done)
        rt.dispatch(filterLink(backend, "active").events["click"]!, payload: ClickEvent())
        sched.pump()
        #expect(backend.title == "todos — active")
        #expect(backend.historyStack.last == "/active")
    }
    @Test func detailRouteShowsTodoAndPreservesStoreOnReturn() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }
        rt.navigate(to: "/todo/1000")                       // seeded id
        sched.pump()
        #expect(backend.title == "todo #1000")
        #expect(backend.serializeHTML().contains("seeded"))
        rt.navigate(to: "/")
        sched.pump()
        #expect(backend.serializeHTML().contains("seeded"), "store above Router survives")
    }
    @Test func unknownRouteRenders404() {
        let (rt, backend, sched, _) = makeApp()
        rt.navigate(to: "/nope")
        sched.pump()
        #expect(backend.serializeHTML().contains("404"))
    }
    @Test func mountAtDeepPathWorks() async {
        // Same fixture but initialPath "/completed" — direct URL entry.
        let backend = MockBackend(); let sched = TestScheduler(); let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TodoApp(counters: counters), initialPath: "/completed",
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        _ = rt
        #expect(backend.title == "todos — completed")
    }
}

// MARK: - SSG acceptance (Task 14)
//
// The real Examples/TodoMVC app lives in a separate package and can't be
// imported here — this fixture mirrors its route shape (/, /active,
// /completed, /todo/:id, /about with a .staticTask loader) to exercise
// StaticSite.generate end-to-end the way the example's `ssg` entry does.

private struct SSGTodoPage: Tag, Page {
    let label: String
    var title: String { "todos — \(label)" }
    var body: some Tag { H1("todos \(label)") }
}
private struct SSGTodoDetail: Tag, Page {
    let id: String?
    var title: String { "todo #\(id ?? "?")" }
    var body: some Tag { H1("todo \(id ?? "?")") }
}
private struct SSGAboutPage: Tag, Page {
    @State var buildInfo = "not prerendered"
    var title: String { "About" }
    var body: some Tag {
        P { Text(buildInfo) }.staticTask { buildInfo = "prerendered-ssg" }
    }
}
private struct SSGApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/") { SSGTodoPage(label: "all") }
            Route("/active") { SSGTodoPage(label: "active") }
            Route("/completed") { SSGTodoPage(label: "completed") }
            Route("/todo/:id") { params in SSGTodoDetail(id: params["id"]) }
            Route("/about") { SSGAboutPage() }
        }
    }
}

@MainActor @Suite struct TodoSSGAcceptanceTests {
    private func tempDir() -> String { NSTemporaryDirectory() + "swiftwui-todomvc-ssg-\(UUID().uuidString)" }

    @Test func hydrateGeneratesAllRoutesAndExplicitTodoPages() async throws {
        let out = tempDir()
        let report = try await StaticSite.generate(SSGApp.self, config: .init(
            outDir: out, mode: .hydrate(wasmScriptPath: "/index.js"),
            paths: ["/todo/1", "/todo/2"]))
        #expect(report.pages.count == 6)
        #expect(Set(report.pages) == ["/", "/active", "/completed", "/todo/1", "/todo/2", "/about"])
        #expect(report.redirects.isEmpty)
        #expect(report.skippedPatterns.isEmpty)

        let home = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(home.contains("application/swiftwui-state"))
        #expect(home.contains("<script type=\"module\" src=\"/index.js\">"))

        let about = try String(contentsOfFile: out + "/about/index.html", encoding: .utf8)
        #expect(about.contains("prerendered-ssg"))
    }

    @Test func staticOnlyOmitsSnapshotAndModuleScript() async throws {
        let out = tempDir()
        _ = try await StaticSite.generate(SSGApp.self, config: .init(
            outDir: out, mode: .staticOnly, paths: ["/todo/1", "/todo/2"]))
        let home = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(!home.contains("application/swiftwui-state"))
        #expect(!home.contains("type=\"module\""))
    }
}
