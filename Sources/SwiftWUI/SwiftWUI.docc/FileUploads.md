# File uploads and previews

Upload a selected file and display a temporary preview without buffering the
entire file in WebAssembly memory.

## Overview

``WebFile`` provides explicit full reads through `data()` and `text()`. For an
upload or preview, use `try await file.blob()` instead. The browser-backed
``WebBlob`` retains the original File. Wrapping it, slicing it, making a
temporary URL, and uploading it do not read its bytes into Swift memory.

``WebSession`` sends a blob with `upload(for:from:)`:

```swift
let blob = try await file.blob()
var request = WebRequest(url: "/api/uploads")
request.method = .put
let (responseData, response) = try await session.upload(for: request, from: blob)
```

The blob is the raw request body. Configure the endpoint to accept that format;
this API does not construct multipart form data. GET and HEAD throw
`WebUploadError.invalidMethod`. A non-nil `request.body`, including empty Data,
throws `WebUploadError.conflictingBody`.

If no Content-Type header is supplied, the session uses the blob's nonempty
MIME type. Header matching is case-insensitive, and an explicit header wins.
Non-2xx responses are returned normally; check `response.isSuccess` as you would
with `data(for:)`.

### Reading and uploading a range

Ranges use byte offsets relative to the current blob. Slices preserve MIME type
and can themselves be sliced. Empty ranges are valid; negative or out-of-bounds
ranges throw `WebBlobError.invalidRange`.

```swift
let blob = try await file.blob()
let prefix = try blob.slice(0..<min(blob.size, 512))
let header = try await prefix.data() // Copies only this range into Swift memory.
```

Uploading `prefix` sends only its range. In the browser, slicing delegates to
Blob.slice without first reading the entire file. The browser controls its own
internal buffering. Explicit `data()` reads can allocate the entire selected
range and do not promise interruption of an already-started arrayBuffer read.

### Temporary URLs

`try blob.makeObjectURL()` returns an opaque ``WebObjectURL``. Pass the handle
directly to ``Img``, ``Video``, ``Audio``, or ``A``:

```swift
let preview = try blob.makeObjectURL()
Img(src: preview, alt: "Selected image")
Video(src: preview, controls: true)
Audio(src: preview, controls: true)
A(href: preview) { Text("Open attachment") }
```

Use the element matching the selected content. The same overloads are available
through `.source(preview)` on Img/Video/Audio and `.destination(preview)` on A.
String URL initializers retain their normal sanitization. A resource handle has
no public URL-string getter or constructor from an arbitrary URL.

Each `makeObjectURL()` call creates a distinct URL. `revoke()` immediately
invalidates that mapping and is safe to call repeatedly. It affects every alias
of that handle, but does not affect another URL made from the same blob or an
upload using the blob directly.

Elements retain their resource while mounted, including during an exit
transition. Removing one of several consumers releases only its reference.
When all owners release a handle, cleanup eventually revokes its URL. Use
explicit `revoke()` when the application has finished with every consumer and
needs timely cleanup.

`revoke()` does not schedule a render or erase already-decoded media. Also clear
the state holding the preview to remove it from the UI. The next render omits
revoked handles. Browser requests started before revocation may finish.

### Keep preview state separate from hydratable state

Blob and object URL handles are not Codable and never appear in generated HTML
or state snapshots. A component containing any non-encodable state slot loses
its entire snapshot row, including when an optional resource is nil. Put
transient attachment state in a child component so the parent's chat draft can
still be restored during hydration.

```swift
struct ChatComposer: Tag {
    @State private var draft = ""

    var body: some Tag {
        Div {
            Textarea(text: $draft)
            AttachmentUpload()
        }
    }
}

struct AttachmentUpload: Tag {
    @Environment(\.webSession) private var session
    @State private var preview: WebObjectURL? = nil
    @State private var uploading = false
    @State private var status = ""

    var body: some Tag {
        Div {
            Input(type: .file, disabled: uploading, accept: "image/*")
                .onFileSelection { files in
                    guard !uploading, let file = files.first else { return }
                    uploading = true
                    Task { @MainActor in
                        defer { uploading = false }
                        do {
                            let blob = try await file.blob()
                            let nextPreview = try blob.makeObjectURL()
                            preview?.revoke()
                            preview = nextPreview
                            var request = WebRequest(url: "/api/uploads")
                            request.method = .put
                            let (_, response) = try await session.upload(for: request, from: blob)
                            status = response.isSuccess ? "Uploaded" : "Upload rejected"
                        } catch {
                            status = "Upload failed"
                        }
                    }
                }
            if let preview {
                Img(src: preview, alt: "Selected attachment")
                Button("Remove preview") {
                    preview.revoke()
                    self.preview = nil
                }
            }
            P { Text(status) }
        }
    }
}
```

Here the preview has one consumer, so explicit revocation on removal is safe.
The upload retains the blob independently and continues if the preview is
removed. Cancelling the Task running `upload` cancels that upload; removing an
element does not implicitly cancel an unrelated Task.

### Platform support

| Blob source | Read/slice | Upload | Temporary URL |
| --- | --- | --- | --- |
| Browser-selected File | Browser | Browser, original Blob body | Browser |
| `WebBlob(data:mimeType:)` | Native and browser | Native and browser | Unsupported |

The Data initializer is useful for native code and tests. MIME types are
normalized to ASCII lowercase; invalid non-printable/non-ASCII types become
empty. The constructor preserves value semantics if the caller later mutates
its Data. Byte-backed browser uploads copy the selected bytes into JavaScript;
the no-full-file-read path starts with the browser's `WebFile.blob()`.

Browser URL creation is a storage capability. Data-backed blobs throw
`WebFetchError.unsupported` from `makeObjectURL()`, including on WASM. Existing
custom readers and transports remain source-compatible; they opt into
`_FileBlobProviding` or `_BlobUploadingTransport` to support these operations.
Missing capabilities throw unsupported without a fallback full read.

The DOM transport aborts both upload and response reading on cancellation or
its total-operation timeout. The native transport uses URLSession's inactivity
timeout. Both report `WebFetchError.cancelled` and `.timeout`; these timeout
settings are not equivalent deadlines.

File names, sizes, and MIME types are client claims. Continue validating content
and upload limits on the receiving server.
