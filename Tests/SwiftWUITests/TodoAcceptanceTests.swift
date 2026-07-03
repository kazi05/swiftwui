import Testing
import Observation
import Foundation
@testable import SwiftWUI

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
private enum Filter: String, CaseIterable { case all, active, completed }

private final class Counters { var byLabel: [String: Int] = [:]
                               func bump(_ l: String) { byLabel[l, default: 0] += 1 } }

private struct TodoRow: Tag {
    let todo: TodoStore.Todo
    let counters: Counters
    @Environment(\.todoStore) var store
    var body: some Tag {
        counters.bump("row-\(todo.id)")
        return Li(class: todo.done ? "done" : "todo") {
            Input(checked: Binding(get: { todo.done }, set: { _ in store.toggle(todo.id) }))
            Span { todo.title }
        }
    }
}
private struct RemainingLabel: Tag {
    @Environment(\.todoStore) var store
    var body: some Tag { P { "\(store.remaining) items left" } }
}
private struct TodoApp: Tag {
    let counters: Counters
    @State var store = TodoStore()
    @State var filter: Filter = .all
    var visible: [TodoStore.Todo] {
        switch filter {
        case .all: store.todos
        case .active: store.todos.filter { !$0.done }
        case .completed: store.todos.filter(\.done)
        }
    }
    var body: some Tag {
        Main {
            H1("todos")
            Input(type: .text, value: Binding(get: { store.draft }, set: { store.draft = $0 }),
                  onKeyDown: { e in if e.key == "Enter" { store.add() } })
            Ul {
                ForEach(visible) { TodoRow(todo: $0, counters: counters) }
            }
            RemainingLabel()
            Div(class: "filters") {
                ForEach(Filter.allCases, id: \.rawValue) { f in
                    Button(f.rawValue) { filter = f }
                }
            }
        }
        .environment(\.todoStore, store)
        .task { store.todos = [.init(id: 1000, title: "seeded", done: false)] }
    }
}

@MainActor @Suite struct TodoAcceptanceTests {
    private func makeApp() -> (Runtime<MockBackend>, MockBackend, TestScheduler, Counters) {
        let backend = MockBackend(); let sched = TestScheduler(); let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TodoApp(counters: counters), scheduleMicrotask: sched.schedule)
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
    // count is unchanged and exactly one `li` flips to the "done" class.
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
        #expect(toggledLi.attrs["class"] == "todo")

        rt.dispatch(checkbox.events["change"]!, payload: ChangeEvent(value: "", checked: true))
        sched.pump()

        let after = counters.byLabel
        let allRowLabels = Set(before.keys).union(after.keys).filter { $0.hasPrefix("row-") }
        let changedRows = allRowLabels.filter { before[$0] != after[$0] }
        #expect(changedRows.count == allRowLabels.count)   // real finding: parent pass reruns EVERY row

        #expect(findAll(backend.container, tag: "li").count == liCountBefore)   // DOM stable: no li added/removed
        #expect(toggledLi.attrs["class"] == "done")                            // only the toggled row flips
        let otherLis = findAll(backend.container, tag: "li").filter { $0 !== toggledLi }
        #expect(otherLis.allSatisfy { $0.attrs["class"] == "todo" })
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
        let completedBtn = findAll(backend.container, tag: "button").first { $0.children.first?.text == "completed" }!
        rt.dispatch(completedBtn.events["click"]!)
        sched.pump()
        #expect(findAll(backend.container, tag: "li").count == 1)
        let activeBtn = findAll(backend.container, tag: "button").first { $0.children.first?.text == "active" }!
        rt.dispatch(activeBtn.events["click"]!)
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
            let btn = findAll(backend.container, tag: "button").first { $0.children.first?.text == label }!
            rt.dispatch(btn.events["click"]!); sched.pump()
        }
        tap("completed"); #expect(findAll(backend.container, tag: "li").count == 1)
        tap("active");    #expect(findAll(backend.container, tag: "li").count == 2)
        tap("all");       #expect(findAll(backend.container, tag: "li").count == 3)
        let counts = findAll(backend.container, tag: "p")
        #expect(counts.contains { ($0.children.first?.text ?? "") == "2 items left" })
    }
}
