import SwiftWUI
import SwiftWUIDOM

struct TaskCard: DragPayload, Equatable, Codable { let id: Int; let title: String }

@main
struct DragDropDemo: App {
    var body: some Tag { DemoPage().preventsAccidentalDropNavigation() }
}

struct DemoPage: Tag {
    @Environment(\.dragSession) private var session
    @State private var log: [String] = []
    @State private var fileZoneTargeted = false
    @State private var cardZoneTargeted = false
    @State private var dragging = false
    @State private var showPicker = false
    @State private var items = ["Alpha", "Beta", "Gamma", "Delta"]

    var body: some Tag {
        Div(class: "page") {
            H1("SwiftWUI DnD acceptance")
            if session.isActive {
                Div(class: "overlay") { P { session.hasFiles ? "Drop files anywhere-zone below" : "Dragging…" } }
            }
            // 1. file zone (images only → rejected state with e.g. .zip)
            Div(class: fileZoneTargeted ? "zone targeted" : "zone") {
                P { "Drop images here" }
            }
            .dropDestination(for: WebFile.self, allowedTypes: [.image]) { files, _ in
                for f in files { log.append("file: \(f.name) (\(f.size) B)") }
                return true
            } isTargeted: { fileZoneTargeted = $0 }
            // 2. click-to-pick
            Button("Pick files…") { showPicker = true }
                .fileImporter(isPresented: $showPicker,
                              allowedContentTypes: [.image, .pdf],
                              allowsMultipleSelection: true) { files in
                    for f in files { log.append("picked: \(f.name)") }
                }
            // 3. custom payload source + zone
            Div(class: dragging ? "card dragging" : "card") { P { "Drag me" } }
                .draggable(TaskCard(id: 1, title: "Drag me")) { dragging = $0 }
            Div(class: cardZoneTargeted ? "zone targeted" : "zone") { P { "Card target" } }
                .dropDestination(for: TaskCard.self) { cards, _ in
                    log.append("card: \(cards[0].title)"); return true
                } isTargeted: { cardZoneTargeted = $0 }
            // 4. sortable
            Div(class: "list") {
                ForEach(items, id: \.self) { item in
                    Div(class: "row") { P { item } }
                }
                .onMove { from, to in items.moveElement(from: from, toOffset: to) }
            }
            Div(class: "log") { ForEach(log, id: \.self) { line in P { line } } }
        }
    }
}

extension Array {
    /// Local reorder helper (move(fromOffsets:toOffset:) availability varies off-Darwin).
    mutating func moveElement(from source: Int, toOffset destination: Int) {
        let value = remove(at: source)
        insert(value, at: source < destination ? destination - 1 : destination)
    }
}
