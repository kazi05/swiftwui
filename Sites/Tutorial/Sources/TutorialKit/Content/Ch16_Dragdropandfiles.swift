/// Chapter 16 — Drag, drop, and files (authored sections; no Figma reference).
/// Code panels are the marked regions of the Tour sample — byte-identical incl.
/// indentation; ExcerptSyncTests fails on any drift.
public enum Ch16 {
    static let boardCode = #"""
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
"""#

    static let wellCode = #"""
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
"""#

    static let importerCode = #"""
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
"""#

    static let payloadCode = #"""
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
"""#

    static let reorderCode = #"""
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
"""#

    public static let chapter = Chapter(
        slug: "drag-drop-and-files", track: .interact, kicker: "CHAPTER · INTERACT",
        title: "Drag, drop, and files",
        tagline: "Files from the desktop, payloads between components, rows that reorder.",
        minutes: 20, kind: .chapter,
        sections: [
            Section(anchor: "dnd-files", kicker: "01 · FILES",
                    title: "Files from the desktop",
                    intro: "A drop zone is one modifier on the element that already draws the target. It filters what lands there and hands you the files that survived.",
                    steps: [
                        Step("Attach .dropDestination(for: WebFile.self, allowedTypes:) to the element that draws the zone.",
                             detail: "It writes attributes on that element — there is no wrapper node — so a second dropDestination on the same element overwrites the first one's accepted types."),
                        Step("Read the files in action; it only ever sees what passed allowedTypes.",
                             detail: "A drop where everything filters out never calls action at all, so there is nothing to re-check inside it."),
                        Step("Drive the hover class from isTargeted.",
                             detail: "It ignores the dragenter/dragleave pairs the cursor fires crossing the zone's own children, and a drag of the wrong type never reports targeted in the first place."),
                        Step("Treat name, size, and mimeType as claims from the client, and check size before calling data() or text().",
                             detail: "Both buffer the whole file into memory. Never build a filesystem path from name and never gate a security decision on mimeType — validate the bytes on the server."),
                        Step("Add a button for people who do not drag: .fileImporter opens the OS dialog.",
                             detail: "Flip isPresented inside a real click handler — the dialog needs transient activation, so setting it from a task or a timer opens nothing.",
                             panel: .code(CodePanel(file: "DropZone.swift", code: importerCode,
                                                    origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/DropZone.swift",
                                                                    marker: "tour-dnd-importer")))),
                    ],
                    panel: .code(CodePanel(file: "DropZone.swift", code: wellCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/DropZone.swift",
                                                           marker: "tour-dnd-file-well")))),
            Section(anchor: "dnd-payloads", kicker: "02 · PAYLOADS",
                    title: "Payloads between components",
                    intro: "Anything Codable can ride an in-app drag. Conform it to DragPayload, hand a value to .draggable at the source, and name the same type at the destination.",
                    steps: [
                        Step("Conform your struct to DragPayload — Codable is the whole requirement.",
                             detail: "You get a content type of application/x-swiftwui.<typename> and JSON encode/decode for free. String and URL already conform."),
                        Step("Mark the source with .draggable(_:isDragged:).",
                             detail: "isDragged mirrors the dragging state, which is enough to dim the chip while it travels."),
                        Step("Name the type at the destination: .dropDestination(for: Asset.self).",
                             detail: "A drag carrying anything else never reports as targeted there, so the two ends cannot quietly drift apart."),
                        Step("The encoded payload rides in a DOM attribute the page can read. Never put a secret in one.",
                             detail: "Bodies over 1 MiB and bodies that fail to decode are ignored without calling action — a pasteboard-bomb guard, not an error you can report."),
                        Step("A custom drop carries exactly one item.",
                             detail: "The array handed to action holds a single element; multi-item custom drags are out of scope."),
                    ],
                    panel: .code(CodePanel(file: "DropZone.swift", code: payloadCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/DropZone.swift",
                                                           marker: "tour-dnd-payload")))),
            Section(anchor: "dnd-session", kicker: "03 · SESSION",
                    title: "The drag session as ambient state",
                    intro: "Files coming in from Finder never fire an in-page dragstart, so none of your source modifiers run. The drag session is the window-level view of what is in flight.",
                    steps: [
                        Step("Read @Environment(\\.dragSession) inside a body to get DragSessionInfo.",
                             detail: "isActive, hasFiles, and the raw list of types. Outside a live runtime it is .none, so prerendered HTML ships the idle branch."),
                        Step("Branch on hasFiles to tell an incoming file apart from an in-page chip."),
                        Step("Repeated identical values do not re-evaluate your body.",
                             detail: "DragSessionInfo is Equatable and the writes are equality-guarded, so the dragenter storm bubbling out of a zone's children costs nothing."),
                        Step("Use it for the page-wide hint, not for the drop.",
                             detail: "Each zone's own isTargeted still owns its local hover state."),
                    ],
                    panel: .code(CodePanel(file: "DropZone.swift", code: boardCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/DropZone.swift",
                                                           marker: "tour-dnd-board")))),
            Section(anchor: "dnd-reorder", kicker: "04 · REORDER",
                    title: "Reordering with onMove",
                    intro: "onMove decorates the rows a ForEach already produces. It moves nothing on its own — you get two indices and mutate the array yourself.",
                    steps: [
                        Step("Call .onMove(perform:) on the ForEach, not on a row."),
                        Step("The closure takes (fromIndex, toInsertionOffset) — plain Ints with SwiftUI's toOffset semantics.",
                             detail: "There is no IndexSet overload: IndexSet needs full Foundation, which pulls roughly 40 MB of ICU into the wasm binary."),
                        Step("Do the move: remove at from, then insert at to - 1 when from < to.",
                             detail: "The offset is a slot in the array before the removal, and the framework ships no move helper."),
                        Step("Each row has to resolve to exactly one root element node.",
                             detail: "Debug builds assert on it."),
                        Step("Reordering is same-list only.",
                             detail: "A row dragged onto a different list shows a droppable cursor and then does nothing. Avoid a .draggable that fills an entire sortable row — both dragstarts fire and the transfer carries both types."),
                    ],
                    panel: .code(CodePanel(file: "DropZone.swift", code: reorderCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/DropZone.swift",
                                                           marker: "tour-dnd-reorder")))),
            Section(anchor: "dnd-safety", kicker: "05 · SAFETY",
                    title: "The safety net",
                    intro: "The browser's default for a file dropped on a page is to navigate the tab to that file, losing whatever the user was doing. One modifier turns that off everywhere outside your zones.",
                    steps: [
                        Step("Mount .preventsAccidentalDropNavigation() once, near the app root.",
                             detail: "It works on any Tag, and anywhere in the tree is fine — the guard is window-level."),
                        Step("Drops inside a real drop zone are untouched.",
                             detail: "Only the space between zones stops navigating."),
                        Step("The guard arms and disarms on mount-count transitions, not on every render.",
                             detail: "Reconciles that leave it mounted write nothing."),
                        Step("Check the whole surface natively.",
                             detail: "Drag and drop is decoded from attributes and events, so the contract holds up under the native test suite without a browser."),
                    ],
                    panel: .terminal(title: "zsh — SwiftWUI", lines: [
                        TermLine(.command, "swift test --filter DropNavigationGuardTests"),
                        TermLine(.output, "Test cancelAllTearsDownDropGuard() passed after 0.001 seconds."),
                        TermLine(.output, "Test guardFollowsMountLifecycle() passed after 0.002 seconds."),
                        TermLine(.output, "Test guardOnlyFiresOnEmptinessTransition() passed after 0.002 seconds."),
                        TermLine(.note, "> Test run with 3 tests in 1 suite passed."),
                    ])),
        ],
        quiz: Quiz(questions: [
            Question(
                prompt: "A list holds [a, b, c] and onMove hands you from = 0, to = 2. What should the array look like afterwards?",
                options: [
                    "[b, a, c] — to is an insertion offset into the array before the removal, so a lands at index 1",
                    "[b, c, a] — to is the final index of the moved element",
                    "[a, b, c] — moving an element down by two slots cancels out",
                ],
                correctIndex: 0,
                explanation: "onMove uses SwiftUI's toOffset semantics: the offset names a slot in the pre-removal array, so after remove(at: from) you insert at to - 1 whenever from < to. The signature is (Int, Int) rather than (IndexSet, Int) because IndexSet needs full Foundation, and that costs about 40 MB of ICU in a wasm binary."),
            Question(
                prompt: "You flip the .fileImporter binding from a timer that runs a second after the user's click. What opens?",
                options: [
                    "The dialog, a second late — the binding is all that matters",
                    "Nothing — the file dialog needs transient activation, which only a genuine user-gesture handler carries",
                    "The dialog immediately, because isPresented is read once at mount",
                ],
                correctIndex: 1,
                explanation: "The importer is a hidden file input that gets clicked on your behalf, and browsers allow that only while transient activation is live. Flip isPresented inside the click handler itself; the microtask flush is timed to preserve the activation. Cancelling is handled for you on browsers that fire the input's cancel event."),
            Question(
                prompt: "A drag carrying a 4 MiB encoded payload lands on .dropDestination(for: Asset.self). What does action see?",
                options: [
                    "An empty array, so you can report the failure",
                    "One Asset decoded from the first 1 MiB of the body",
                    "Nothing — action is never called",
                ],
                correctIndex: 2,
                explanation: "Inbound bodies are capped at 1 MiB as a pasteboard-bomb guard; oversized, malformed, and foreign-typed bodies are all ignored silently and action is skipped. The other side of an attribute-carried payload is that it is readable in the DOM, so a drag payload is never the place for a secret."),
        ]))
}
