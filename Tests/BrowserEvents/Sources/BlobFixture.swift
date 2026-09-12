import JavaScriptKit
import SwiftWUI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// This component deliberately owns only transient browser state. Keeping it
/// separate prevents these non-Codable values from excluding neighboring rows.
struct BlobFixture: Tag {
    @Environment(\.webSession) private var session
    @State private var blob: WebBlob?
    @State private var preview: WebObjectURL?
    @State private var independent: WebObjectURL?
    @State private var imageMounted = true
    @State private var mode = 0
    @State private var status = "empty"
    @State private var result = ""
    @State private var operation: Task<Void, Never>?

    var body: some Tag {
        Div(id: "blob-fixture") {
            Input(type: .file, id: "blob-file").onFileSelection { files in
                guard let file = files.first else { return }
                Task { @MainActor in
                    do {
                        let selected = try await file.blob()
                        blob = selected
                        preview = try selected.makeObjectURL()
                        status = "ready"
                        result = "\(selected.size):\(selected.mimeType)"
                    } catch { status = failure(error) }
                }
            }
            Span(id: "blob-status") { Text(status) }
            Span(id: "blob-result") { Text(result) }
            if let preview {
                if imageMounted { image(preview) }
                Video(src: preview, id: "blob-video").attribute("preload", "none")
                Audio(src: preview, id: "blob-audio").attribute("preload", "none")
                A(href: preview, id: "blob-link") { Text("Download") }.attribute("download", "fixture.bin")
            }
            if let independent {
                Img(src: independent, alt: "Independent", id: "blob-independent")
            }
            Button("Read slice") {
                guard let blob else { return }
                Task { @MainActor in
                    do {
                        let slice = try blob.slice(2..<7)
                        result = String(decoding: try await slice.data(), as: UTF8.self)
                        status = "read"
                    } catch { status = failure(error) }
                }
            }.id("blob-read")
            Button("Upload original") { start("/__blob/echo") }.id("blob-upload")
            Button("Upload byte slice") { start("/__blob/echo", byteSlice: true) }.id("blob-bytes")
            Button("Upload native slice") { start("/__blob/echo", nativeSlice: true) }.id("blob-native-slice")
            Button("Send existing Data body") { start("/__blob/echo", oldData: true) }.id("blob-data")
            Button("Already cancelled") { start("/__blob/echo", preCancelled: true) }.id("blob-pre-cancel")
            Button("Wait for headers") { start("/__blob/slow-headers") }.id("blob-slow")
            Button("Wait for response body") { start("/__blob/slow-body") }.id("blob-slow-body")
            Button("Time out headers") { start("/__blob/slow-headers", timeout: .milliseconds(80)) }.id("blob-timeout")
            Button("Time out response body") { start("/__blob/slow-body", timeout: .milliseconds(80)) }.id("blob-timeout-body")
            Button("Cancel upload") { operation?.cancel() }.id("blob-cancel")
            Button("Unmount shared image") { imageMounted = false }.id("blob-unmount-image")
            Button("Use plain src") { mode = 1 }.id("blob-plain")
            Button("Use resource src") { mode = 0 }.id("blob-resource")
            Button("Use uppercase raw src") { mode = 2 }.id("blob-upper")
            Button("Use resource after uppercase") { mode = 3 }.id("blob-after-upper")
            Button("Use localized src") { mode = 4 }.id("blob-localized")
            Button("Make independent URL") {
                do { independent = try blob?.makeObjectURL() }
                catch { status = failure(error) }
            }.id("blob-independent-create")
            Button("Revoke preview twice") {
                preview?.revoke()
                preview?.revoke()
                status = "revoked"
            }.id("blob-revoke")
            Button("Clear previews") {
                preview = nil
                independent = nil
            }.id("blob-clear")
        }
    }

    private func image(_ url: WebObjectURL) -> Img {
        let typed = Img(src: url, alt: "Preview", id: "blob-image")
        switch mode {
        case 1: return Img(src: "/__blob/plain-image", alt: "Preview", id: "blob-image")
        case 2: return typed.attribute("SRC", "/__blob/uppercase-image")
        case 3: return Img(src: "/__blob/plain-image", alt: "Preview", id: "blob-image")
                .attribute("SRC", "/__blob/uppercase-image").source(url)
        case 4: return typed.attribute("SRC", LocalizedText.verbatim("/__blob/localized-image"))
        default: return typed
        }
    }

    private func start(_ path: String, byteSlice: Bool = false, nativeSlice: Bool = false, oldData: Bool = false,
                       preCancelled: Bool = false, timeout: Duration? = nil) {
        guard let blob else { return }
        status = "pending"
        operation = Task { @MainActor in
            if preCancelled { withUnsafeCurrentTask { $0?.cancel() } }
            do {
                var request = WebRequest(url: path)
                request.method = .put
                request.timeout = timeout
                let response: (_FoundationData, WebResponse)
                if oldData {
                    request.body = _FoundationData("old-data".utf8)
                    response = try await session.data(for: request)
                } else if byteSlice {
                    let bytes = WebBlob(data: _FoundationData("ABCDEFGHIJ".utf8), mimeType: "TEXT/PLAIN")
                    response = try await session.upload(for: request, from: bytes.slice(3..<7))
                } else if nativeSlice {
                    let slice = try blob.slice(2..<7)
                    let temporary = try slice.makeObjectURL()
                    temporary.revoke()
                    response = try await session.upload(for: request, from: slice)
                } else {
                    response = try await session.upload(for: request, from: blob)
                }
                result = String(decoding: response.0, as: UTF8.self)
                status = "uploaded:\(response.1.status)"
            } catch { status = failure(error) }
        }
    }

    private func failure(_ error: any Error) -> String {
        switch error {
        case WebFetchError.cancelled: return "cancelled"
        case WebFetchError.timeout: return "timeout"
        case WebFetchError.unsupported: return "unsupported"
        default: return "error:\(error)"
        }
    }
}
