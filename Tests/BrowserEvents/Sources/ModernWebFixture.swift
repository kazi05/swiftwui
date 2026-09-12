import SwiftWUI
import SwiftWUIDOM
import JavaScriptKit

nonisolated struct WorkerInput: Codable, Sendable { let value: Int }
nonisolated struct WorkerOutput: Codable, Sendable { let value: Int }

struct ModernWebFixture: Tag {
    var body: some Tag {
        Router {
            Route("/modern") { ModernFirstPage() }
            Route("/modern/second") { ModernSecondPage() }
        }
    }
}
struct ModernFirstPage: Tag, Page {
    var title: String { "First modern page" }
    @State private var form = FormSubmission<String>()
    @State private var workerResult = "idle"
    @State private var workerChecks = "idle"
    @State private var island: DOMIsland? = nil
    var body: some Tag {
        Main {
            H1 { Text("First modern page") }
            Link("/modern/second") { Text("Next page") }
            EnhancedForm(action: "/__modern/form", submission: form, onSubmit: { event in
                FormResult(value: event.fields.first(where: { $0.name == "name" })?.value ?? "missing")
            }) { form in
                Input().attribute("name", "name").attribute("value", "Ada").id("modern-name")
                Button(type: .submit) { Text("Submit") }
                Span(id: "form-result") { Text(form.result?.value ?? "idle") }
            }
            Button("Compute") {
                Task { @MainActor in
                    do {
                        let worker = try ComputeWorker<WorkerInput, WorkerOutput>(moduleURL: "/modern-worker.js")
                        defer { worker.close() }
                        workerResult = String(try await worker.call(WorkerInput(value: 21)).value.value)
                    } catch { workerResult = "error: \(error)" }
                }
            }.id("compute")
            Span(id: "worker-result") { Text(workerResult) }
            Button("Check worker failures") {
                Task { @MainActor in
                    do {
                        let worker = try ComputeWorker<WorkerInput, WorkerOutput>(moduleURL: "/modern-worker.js")
                        defer { worker.close() }
                        let storage = JSObject.global.ArrayBuffer.function!.new(16)
                        let buffer = WorkerBuffer(takingArrayBuffer: storage)
                        do {
                            _ = try await worker.call(WorkerInput(value: 1), transferring: [buffer, buffer])
                            workerChecks = "duplicate transfer accepted"; return
                        } catch { }
                        guard !buffer.isTransferred, storage.byteLength.number == 16 else {
                            workerChecks = "failed transfer consumed buffer"; return
                        }
                        _ = try await worker.call(WorkerInput(value: 1), transferring: [buffer])
                        guard buffer.isTransferred, storage.byteLength.number == 0 else {
                            workerChecks = "successful transfer retained buffer"; return
                        }
                        let broken = try ComputeWorker<WorkerInput, WorkerOutput>(moduleURL: "/broken-worker.js")
                        defer { broken.close() }
                        do {
                            _ = try await broken.call(WorkerInput(value: 1))
                            workerChecks = "broken worker responded"; return
                        } catch { }
                        do {
                            _ = try await broken.call(WorkerInput(value: 2))
                            workerChecks = "closed worker responded"
                        } catch ComputeWorkerError.closed { workerChecks = "passed" }
                    } catch { workerChecks = "error: \(error)" }
                }
            }.id("worker-checks")
            Span(id: "worker-checks-result") { Text(workerChecks) }
            Div(id: "virtual-list") {
                VirtualForEach(Array(0..<10_000), id: \.self, rowHeight: 30, viewportHeight: 180,
                               initialItemCount: 10, accessibilityLabel: "Large collection") { index in
                    Div { Text("Row \(index)") }.attribute("data-row", String(index))
                }
            }
            Div().attribute("style", "height:1500px")
        }
        .onAppear {
            let host = JSObject.global.document.object!.createElement!("div").object!
            _ = host.setAttribute?("id", "separate-island")
            host.textContent = .string("Static island")
            _ = JSObject.global.document.body.object?.appendChild?(host)
            island = try? DOMRuntime.mountIsland({ IslandCounter() }, selector: "#separate-island", activation: .interaction)
        }
        .onDisappear {
            island?.dispose()
            _ = JSObject.global.document.object?.getElementById?("separate-island").object?.remove?()
        }
    }
}
struct ModernSecondPage: Tag, Page {
    var title: String { "Second modern page" }
    var body: some Tag { Main { H1 { Text("Second modern page") }; Link("/modern") { Text("Back") } } }
}
struct IslandCounter: Tag, ExplicitComponentRegistration {
    @State private var count = 0
    static let componentIdentifier = "browser-fixture.island-counter.v1"
    func registerProperties(_ properties: inout ComponentProperties) {
        properties.state(_count, stableID: "count")
    }
    var body: some Tag { Button("Island \(count)") { count += 1 }.id("island-counter") }
}
