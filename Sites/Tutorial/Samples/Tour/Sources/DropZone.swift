import SwiftWUI
import SwiftWUIDOM

/// Chapter: "Drag, drop and files". One asset board covering the four
/// surfaces — an OS-file well, a click-to-pick fallback for people who do
/// not drag, a typed in-app payload, and a reorderable list.

struct DropZoneDemo: Tag, Styled {
    @Environment(\.dragSession) private var session
    @State private var assets = ["moodboard.png", "hero.jpg", "type-scale.pdf"]
    @State private var wellTargeted = false
    @State private var shelfTargeted = false
    @State private var dragging = false
    @State private var picking = false

// tutorial:begin tour-dnd-board
    var body: some Tag {
        Main(class: "tour") {
            H1("Asset board")
            // OS files never fire an in-page dragstart, so \.dragSession is
            // the only way to know one is on its way in.
            if session.isActive {
                P(class: "hint") {
                    session.hasFiles ? "Drop the file on the well" : "Drop the chip on the shelf"
                }
            }
            well
            picker
            chip
            shelf
            rows
            Link("/") { Span { "Back to the tour" } }
        }
        // Without this, a file dropped beside a zone navigates the tab to it.
        .preventsAccidentalDropNavigation()
    }
// tutorial:end tour-dnd-board

// tutorial:begin tour-dnd-file-well
    /// `action` only ever sees files that passed `allowedTypes`; a drop where
    /// everything filters out never calls it. `isTargeted` ignores the
    /// dragenter/dragleave pairs fired by crossing the zone's own children.
    private var well: some Tag {
        Div(class: wellTargeted ? "zone targeted" : "zone") {
            P { wellTargeted ? "Release to add" : "Drop an image here" }
        }
        .dropDestination(for: WebFile.self, allowedTypes: [.image]) { files, _ in
            assets.append(contentsOf: files.map(\.name))
            return true
        } isTargeted: { wellTargeted = $0 }
    }
// tutorial:end tour-dnd-file-well

// tutorial:begin tour-dnd-importer
    /// The file dialog needs transient activation, so `picking` has to flip
    /// inside a real click handler — setting it from a task or a timer opens
    /// nothing.
    private var picker: some Tag {
        Button("Choose an image…", class: "pick") { picking = true }
            .fileImporter(isPresented: $picking,
                          allowedContentTypes: [.image],
                          allowsMultipleSelection: true) { files in
                assets.append(contentsOf: files.map(\.name))
            }
    }
// tutorial:end tour-dnd-importer

// tutorial:begin tour-dnd-payload
    /// Codable is the whole conformance. The content type defaults to
    /// "application/x-swiftwui.asset", and the encoded body rides in a DOM
    /// attribute the page can read — never put a secret in one.
    struct Asset: DragPayload, Codable, Equatable { let name: String }

    private var chip: some Tag {
        Div(class: dragging ? "chip dragging" : "chip") { P { "swatch.png" } }
            .draggable(Asset(name: "swatch.png")) { dragging = $0 }
    }

    /// The type argument is what makes the two ends fit: a drag carrying
    /// anything else never even reports as targeted here.
    private var shelf: some Tag {
        Div(class: shelfTargeted ? "zone targeted" : "zone") {
            P { shelfTargeted ? "Release to shelve" : "Shelf" }
        }
        .dropDestination(for: Asset.self) { dropped, _ in
            assets.append(dropped[0].name)
            return true
        } isTargeted: { shelfTargeted = $0 }
    }
// tutorial:end tour-dnd-payload

// tutorial:begin tour-dnd-reorder
    /// `onMove` hands you (fromIndex, toInsertionOffset) — SwiftUI's toOffset
    /// semantics with plain Ints, because `IndexSet` would drag all of
    /// Foundation into the wasm binary. Each row resolves to one element.
    private var rows: some Tag {
        Div(class: "rows") {
            ForEach(assets, id: \.self) { asset in
                Div(class: "row") { P { asset } }
            }
            .onMove { from, to in
                let moved = assets.remove(at: from)
                assets.insert(moved, at: from < to ? to - 1 : to)
            }
        }
    }
// tutorial:end tour-dnd-reorder

    @RulesBuilder var styles: [Rule] {
        Rule(class: "hint") { p in p.color(.hex("#0f766e")) }
        Rule(class: "zone") { p in
            p.padding(.px(24)); p.borderRadius(.px(12))
            p.border(.px(2), .dashed, .hex("#d6d3d1"))
            p.background(.hex("#ffffff"))
        }
        Rule(class: "targeted") { p in
            p.borderColor(.hex("#0f766e")); p.background(.hex("#ecfdf5"))
        }
        Rule(class: "chip") { p in
            p.display(.inlineBlock); p.cursor(.grab)
            p.padding(vertical: .px(4), horizontal: .px(14))
            p.borderRadius(.px(999)); p.background(.hex("#f5f5f4"))
        }
        Rule(class: "dragging") { p in p.opacity(0.4) }
        Rule(class: "rows") { p in
            p.display(.flex); p.flexDirection(.column); p.gap(.px(6))
        }
        Rule(class: "row") { p in
            p.cursor(.grab); p.padding(vertical: .px(2), horizontal: .px(12))
            p.borderRadius(.px(8)); p.background(.hex("#ffffff"))
        }
    }
}
