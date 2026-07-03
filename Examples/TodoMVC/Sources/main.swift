import SwiftWUI
import SwiftWUIDOM
import Observation
#if arch(wasm32)
import JavaScriptKit
#endif

/// No Foundation in this target (spec: avoid Foundation on the wasm example) —
/// a tiny whitespace trim instead of `trimmingCharacters(in:)`.
private extension String {
    func trimmedWhitespace() -> String {
        var s = Substring(self)
        while let f = s.first, f.isWhitespace { s.removeFirst() }
        while let l = s.last, l.isWhitespace { s.removeLast() }
        return String(s)
    }
}

@Observable final class TodoStore {
    struct Todo: Identifiable, Equatable { let id: Int; var title: String; var done: Bool }
    var todos: [Todo] = []
    var draft = ""
    private var nextID = 1
    var remaining: Int { todos.filter { !$0.done }.count }
    func add() {
        let title = draft.trimmedWhitespace()
        guard !title.isEmpty else { return }
        todos.append(Todo(id: nextID, title: title, done: false)); nextID += 1
        draft = ""
    }
    func toggle(_ id: Int) { if let i = todos.firstIndex(where: { $0.id == id }) { todos[i].done.toggle() } }
    func load() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        todos = [Todo(id: 1, title: "Learn SwiftWUI", done: true),
                 Todo(id: 2, title: "Ship phase 2", done: false)]
        nextID = 3
    }
}
private struct StoreKey: EnvironmentKey { static let defaultValue = TodoStore() }
extension EnvironmentValues {
    fileprivate var todoStore: TodoStore { get { self[StoreKey.self] } set { self[StoreKey.self] = newValue } }
}
private enum Filter: String, CaseIterable { case all, active, completed }

extension ColorToken {
    static let accent  = ColorToken("accent")
    static let surface = ColorToken("surface")
    static let ink     = ColorToken("ink")
}
let lightTheme = ThemeDefinition { t in
    t.set(ColorToken.accent,  .hex("#e94560"))
    t.set(ColorToken.surface, .hex("#ffffff"))
    t.set(ColorToken.ink,     .hex("#1a1a2e"))
}
let darkTheme = ThemeDefinition(name: "dark") { t in
    t.set(ColorToken.surface, .hex("#16213e"))
    t.set(ColorToken.ink,     .hex("#eaeaea"))
}

private struct TodoRow: Tag, Styled {
    let todo: TodoStore.Todo
    @Environment(\.todoStore) var store
    @RulesBuilder var styles: [Rule] {
        Rule(class: "done") { s in
            s.textDecoration(.lineThrough)
            s.opacity(0.6)
        }
        Rule(class: "todo") { $0.color(.token(.ink)) }
    }
    var body: some Tag {
        Li(class: todo.done ? "done" : "todo") {
            Input(checked: Binding(get: { todo.done }, set: { _ in store.toggle(todo.id) }))
            Span { todo.title }
        }
    }
}
private struct RemainingLabel: Tag {
    @Environment(\.todoStore) var store
    var body: some Tag { P { "\(store.remaining) items left" } }
}
private struct TodoApp: Tag, Styled {
    @State var store = TodoStore()
    @State var filter: Filter = .all
    @State var dark = false
    @Environment(\.setTheme) var setTheme
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
                ForEach(visible) { TodoRow(todo: $0) }
            }
            .listStyle("none")
            RemainingLabel()
            Div(class: "filters") {
                ForEach(Filter.allCases, id: \.rawValue) { f in
                    Button(f.rawValue) { filter = f }
                }
                Button("theme") { dark.toggle(); setTheme(dark ? "dark" : nil) }
            }
            .display(.flex)
            .gap(.px(8))
        }
        .background(.token(.surface))
        .environment(\.todoStore, store)
        .task { await store.load() }
        .onChange(of: filter) { _, new in
            #if arch(wasm32)
            JSObject.global.document.title = .string("todos — \(new.rawValue)")
            #endif
        }
    }
}

@main
struct TodoMVCApp: App {
    @RulesBuilder static var globalStyles: [Rule] {
        Rule(element: "body") { s in
            s.margin(.zero)
            s.fontFamily("system-ui, sans-serif")
        }
    }
    static var themes: [ThemeDefinition] { [lightTheme, darkTheme] }
    var body: some Tag { TodoApp() }
}
