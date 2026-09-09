# Drag and drop

Dropping OS files onto a zone, picking them from a dialog instead, dragging
typed payloads between elements, and reordering a list — HTML5 drag and drop
behind a SwiftUI-shaped API.

## Overview

Four surfaces, all independent of each other: ``WebFile`` drop zones for
files the user drags in from the desktop, `.fileImporter` for the users who
would rather click, ``DragPayload`` for typed in-app drags, and
`ForEach.onMove` for drag-to-reorder. `@Environment(\.dragSession)` reports
whether anything is being dragged over the page at all.

`.draggable`, both `.dropDestination` overloads, and `onMove` are
`HTMLTag`-only — they write into the element's own attribute bag and add no
wrapper node, so they attach to `Div`, `Li`, `Img`, and friends, not to a
custom component. `.fileImporter` and `.preventsAccidentalDropNavigation`
work on any ``Tag``.

None of this works on touch devices. HTML5 drag and drop has no touch
equivalent, and SwiftWUI does not emulate one — a mobile visitor sees the
zone and cannot drag anything into it. Every drag path that matters needs a
click-driven alternative alongside it, which is what `.fileImporter` is for.

### Dropping files

`.dropDestination(for: WebFile.self, allowedTypes:action:isTargeted:)` turns
an element into a file drop zone. `allowedTypes` is a list of ``FileType``
values (defaulting to `[]`, which means any file); `isTargeted` mirrors the
hover state so you can style it.

```swift
struct Uploads: Tag {
    @State private var isTargeted = false
    @State private var names: [String] = []

    var body: some Tag {
        Div(class: isTargeted ? "well well--targeted" : "well") {
            P { "Drop images here" }
        }
        .dropDestination(for: WebFile.self, allowedTypes: [.image]) { files, _ in
            names += files.map(\.name)
            return true
        } isTargeted: { isTargeted = $0 }
    }
}
```

The `files` array reaching `action` is already filtered by `allowedTypes` —
drop three files where one is an image and the closure sees one file. If
every file filters out, the closure is not called at all, so a rejected drop
is silent by construction; render the rejection from `isTargeted` if you
want the user to see one. The second parameter is a ``DropLocation``, the
drop point in client coordinates. The `Bool` return exists for SwiftUI
parity and is discarded — returning `false` does not undo anything.

`isTargeted(true)` means "a file drag is over this zone", not "this zone
accepts it". The zone advertises its `allowedTypes` to the browser, so the
cursor honestly shows copy or not-allowed while a wrong-type file hovers,
but the enter event carries no mime information a Swift handler could read,
and the highlight fires for any file drag. The filter at drop time is the
authoritative one.

The resulting files support `try await file.blob()` for direct uploads and
temporary media previews. See <doc:FileUploads> for the upload and lifetime APIs.

Enter and leave events that fire when the cursor crosses between the zone's
own children are ignored, so `isTargeted` does not flicker off as the
pointer moves over nested content. A drag carrying no files never targets
the zone at all — no `false` event fires either, which matters if you drive
anything off the callback beyond a boolean.

One drop zone per element. A second `.dropDestination` on the same element
overwrites the acceptance attribute the first one set, and only the last one
takes effect for the browser's cursor and the guard below — the handlers
themselves compose, which makes the mistake look half-working. Put two zones
on two elements.

### Picking files without a drag

`.fileImporter` is the click path: a `Binding<Bool>` you flip to open the
OS file dialog, with the selection delivered to `onCompletion`.

```swift
struct PickerButton: Tag {
    @State private var showPicker = false
    @State private var names: [String] = []

    var body: some Tag {
        Div {
            Button("Choose images…") { showPicker = true }
                .fileImporter(isPresented: $showPicker,
                              allowedContentTypes: [.image, .pdf],
                              allowsMultipleSelection: true) { files in
                    names += files.map(\.name)
                }
            Ul { ForEach(names, id: \.self) { name in Li { Text(name) } } }
        }
    }
}
```

**Flip `isPresented` from a genuine user-gesture handler.** File dialogs
require transient activation: the browser only opens one if it can trace the
call back to a click, keypress, or similar within the activation window.
Setting the binding from a `.task`, a timer, a fetch completion, or anything
after an `await` produces no dialog and no error — the call is dropped
silently. SwiftWUI's render flush is microtask-deferred specifically so that
a write from a `Button`'s handler still lands inside the activation, but
nothing can recover an activation that was already spent.

On dismissal, modern browsers fire a `cancel` event and the binding resets
itself. Older ones fire nothing, leaving the binding `true` — and since the
dialog is driven by the binding *changing*, a second press of the same
button writes `true` over `true` and opens nothing. Test the cancel-then-
retry path on your browser floor before relying on it.

`allowedContentTypes` populates the input's `accept` attribute. It filters
what the dialog offers, and a determined user can still pick around it, so
treat it as ergonomics and validate what arrives.

For a visible file input rather than a hidden one, use
`Input(type:accept:multiple:)` with ``FileType`` values plus
`.onFileSelection` — see <doc:BrowserAPIs>, and note that a plain `.onChange`
handler on a file input never fires.

### Custom payloads

``DragPayload`` is the `Transferable` analog: conform a `Codable` type and
it gets a content type, an encoder, and a decoder for free. `.draggable`
makes an element a source, and `.dropDestination(for:)` on the payload type
makes a matching target.

```swift
struct TaskCard: DragPayload, Codable, Equatable { let id: Int; let title: String }

struct Board: Tag {
    @State private var dragging = false
    @State private var isTargeted = false
    @State private var done: [TaskCard] = []

    var body: some Tag {
        Div {
            Div(class: dragging ? "card card--dragging" : "card") { P { "Ship the docs" } }
                .draggable(TaskCard(id: 1, title: "Ship the docs")) { dragging = $0 }

            Div(class: isTargeted ? "lane lane--targeted" : "lane") { P { "Done" } }
                .dropDestination(for: TaskCard.self) { cards, _ in
                    done += cards
                    return true
                } isTargeted: { isTargeted = $0 }
        }
    }
}
```

The default `dragContentType` is `application/x-swiftwui.<lowercased type
name>`, and the default body is JSON with sorted keys. `String` and `URL`
already conform, as `text/plain` and `text/uri-list`, so a zone declared for
`String.self` accepts text dragged in from any other application. Override
`dragContentType` when you need to interoperate with a specific format;
browsers lowercase `DataTransfer` format strings, and SwiftWUI lowercases at
every use site to match, so an uppercase override still resolves at drop
time.

Unlike the file zone, `isTargeted` here does track acceptance: the payload's
content type is visible in the drag's type list, so a drag of the wrong type
never targets the zone.

Typed drops are single-item. The array handed to `action` always holds
exactly one value; its shape is SwiftUI parity, not a promise of batching.

### Ambient drag state

Files dragged in from the desktop never fire an in-page `dragstart`, so
there is no source element to hang state on. `@Environment(\.dragSession)`
is the window-level signal for that case: it reports whether a drag is in
flight anywhere over the page, whether it carries files, and which content
types it advertises.

```swift
struct DropOverlay: Tag {
    @Environment(\.dragSession) private var session

    var body: some Tag {
        Div {
            if session.isActive && session.hasFiles {
                Div(class: "overlay") { P { "Drop the file anywhere" } }
            }
        }
    }
}
```

Like every reactive environment signal, it is tracked **only when read
inside a component's `body`** — a read in an event handler or a `.task`
closure triggers no re-render. Writes are equality-guarded, so the enter
events bubbling up from a zone's children do not re-evaluate the reading
component once per child. Outside a live runtime — native tests, SSG — it is
``DragSessionInfo/none``, which is what keeps a prerendered page from
shipping a drag overlay baked into the HTML.

### Reordering a list

`ForEach.onMove` decorates each row of a `ForEach` with drag handling and a
live preview: the source dims, the rows between the source and the insertion
point shift by one row extent, and the styles exist only while a drag is
running.

```swift
struct Playlist: Tag {
    @State private var tracks = ["Alpha", "Beta", "Gamma", "Delta"]

    var body: some Tag {
        Div(class: "list") {
            ForEach(tracks, id: \.self) { track in
                Div(class: "row") { P { track } }
            }
            .onMove { from, to in tracks.moveElement(from: from, toOffset: to) }
        }
    }
}

extension Array {
    mutating func moveElement(from source: Int, toOffset destination: Int) {
        let value = remove(at: source)
        insert(value, at: source < destination ? destination - 1 : destination)
    }
}
```

**The signature is `(Int, Int)`, not SwiftUI's `(IndexSet, Int)`, on
purpose.** `IndexSet` lives in full Foundation, and linking full Foundation
pulls ICU into the wasm bundle — roughly 40 MB — for a type that would never
hold more than one index here, because an HTML5 drag carries one item.
`onMove` is not the only place this shows up: SwiftWUI ships no
`move(fromOffsets:toOffset:)` analog either, which is why the snippet above
carries its own three-line helper.

The two parameters keep SwiftUI's `toOffset` semantics: `from` is the source
index and `to` is an insertion offset in the list *before* the removal,
which is where the `destination - 1` adjustment for downward moves comes
from. Copy the helper rather than deriving it again at each call site.

Three constraints, all debug-asserted or documented rather than enforced:

- **Each row must resolve to exactly one root node, and that root must be an
  element.** A row whose closure returns two siblings, or nothing but text,
  trips an assertion in a debug build and silently loses its drag handling
  in a release one.
- **`onMove` owns the drag events on row roots.** It installs `dragstart`,
  `dragover`, `drop`, and `dragend` on each row's root element, overwriting
  drag modifiers you put on the same element. In particular, a `.draggable`
  element filling an entire row means both drag sources fire at once and the
  transfer carries both payload types — put the `.draggable` on a smaller
  child, or drop one of the two.
- **Reordering is same-list only.** Every sortable list shares one internal
  content type, so dragging a row from another list shows a droppable cursor
  and then does nothing on drop. Cross-list moves need a
  ``DragPayload`` of your own.

### Guarding against accidental navigation

A file dropped on a page with no drop zone under the cursor makes the
browser navigate the tab to that file, discarding the entire app state. Mount
`.preventsAccidentalDropNavigation()` once, anywhere in the tree, to stop
that:

```swift
@main
struct MyApp: App {
    var body: some Tag { Board().preventsAccidentalDropNavigation() }
}
```

It only suppresses the default for drops that land outside every declared
drop zone; drops inside a zone are untouched. It is a whole-window guard, so
one mount covers the app — mounting it in several places is harmless but
buys nothing.

### What a drag payload is safe to carry

A payload is encoded into a plain DOM attribute at render time, before any
drag starts. It is readable in devtools by anyone looking at the page, it
travels over the OS drag pasteboard to other applications and other tabs,
and it is not scrubbed when the drag ends. **Never put a token, a session
identifier, a price you only show to some users, or anything else secret in
a `DragPayload`** — carry an id and look the rest up.

Inbound bodies are the mirror image: untrusted foreign data that any page or
application can hand you. Two protections apply, both silent:

- **Bodies over 1 MiB are dropped** — a cap against a pasteboard bomb. The
  action is never called.
- **Bodies that fail to decode are dropped** — malformed JSON, a foreign
  format that happens to share a content type, a payload from an older
  version of your app whose shape no longer matches. Again, the action is
  never called.

Neither case logs anything or produces an error path you can hook. A drop
that appears to do nothing when you know the drag was correct is almost
always one of these two, and the way to tell them apart is to check the body
size and then round-trip the payload through `JSONDecoder` yourself. In a
debug build, a payload that fails to *encode* on the source side trips an
assertion at the `.draggable` call, which catches the shape mismatch before
it becomes a silent drop.

Files come with their own trust rules, unchanged from <doc:BrowserAPIs>:
``WebFile``'s `name`, `mimeType`, `size`, and `lastModified` are claims made
by the client, not verified facts. Never build a filesystem path from `name`,
never gate a security decision on `mimeType`, and check `size` before
calling `data()` or `text()` — both buffer the whole file into memory.

``FileType`` matching inherits that: it compares the claimed mime when the
file states one, and falls back to the filename extension only when the mime
is empty *and* the name actually contains a dot. A file named `photo` with
no extension and no mime matches nothing, including `.any` — which is
correct for a filter and useless as a gate. It filters for the user's
convenience; the real validation happens on your bytes, server-side.

### See it running

`Examples/DragDrop` is the acceptance app: a file zone with an
`allowedTypes` filter, a `.fileImporter` behind a button, a custom
`DragPayload` used as both source and target, a sortable list, and the
navigation guard around all of it. `Examples/DragDrop/ACCEPTANCE.md` is the
manual browser checklist that goes with it, including the states — rejected
cursor, cross-tab drop, touch — that no native test can cover.
