import SwiftWUI
import SwiftWUIDOM

// tutorial:begin counter
struct Counter: Tag {
    @State private var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("−") { count -= 1 }
            Button("+") { count += 1 }
            if count >= 10 { P { "Double digits." } }
        }
    }
}
// tutorial:end counter

struct BrowserAPIDemo: Tag {
    @Environment(\.colorScheme) var scheme
    @Environment(\.webSession) var session
    @AppStorage("demo.count") var count = 0
    @State var items: [String] = []
    @State var preview = ""

    struct Payload: Decodable { let items: [String] }

    var body: some Tag {
        Div {
            H2("Browser APIs (phase 8a)")
            P { "System scheme: \(scheme == .dark ? "dark" : "light")" }
            Button("Persisted count: \(count)") { count += 1 }
            Button("Load items") {
                Task {
                    if let p: Payload = try? await session.json(from: "/data.json") {
                        items = p.items
                    }
                }
            }
            Ul { ForEach(items, id: \.self) { item in Li { Text(item) } } }
            Input(type: .file, accept: ".txt,text/plain")
                .onFileSelection { files in
                    guard let f = files.first, f.size < 1_000_000 else { return }
                    Task { preview = (try? await f.text()) ?? "" }
                }
            Pre { Text(preview) }
        }
    }
}

@main
struct CounterApp: App {
    var body: some Tag {
        Div {
            Counter()
            BrowserAPIDemo()
        }
    }
}
