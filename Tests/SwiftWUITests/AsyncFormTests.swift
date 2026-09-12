import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

@Suite @MainActor struct AsyncFormTests {
    @Test func retryRecoversFromFailure() async {
        var attempts = 0
        let resource = AsyncResource<Int> {
            attempts += 1
            if attempts == 1 { throw WebFetchError.network("offline") }
            return 42
        }
        await resource.load()
        guard case .failure = resource.state else { Issue.record("Expected failed resource"); return }
        await resource.load()
        guard case .success(let value) = resource.state else { Issue.record("Expected recovered resource"); return }
        #expect(value == 42)
    }

    @Test func resetPreventsLatePublication() async {
        var resume: CheckedContinuation<Int, Never>?
        let resource = AsyncResource<Int> { await withCheckedContinuation { resume = $0 } }
        let pending = Task { await resource.load() }
        while resume == nil { await Task.yield() }
        resource.reset(); resume?.resume(returning: 42)
        await pending.value
        guard case .idle = resource.state else { Issue.record("Stale result published"); return }
    }

    @Test func submissionPreservesFieldErrorsAndIgnoresCancelledResult() async {
        let form = FormSubmission<String>()
        var resume: CheckedContinuation<FormResult<String>, Never>?
        form.submit(SubmitEvent()) { _ in await withCheckedContinuation { resume = $0 } }
        while resume == nil { await Task.yield() }
        form.cancel()
        form.submit(SubmitEvent(fields: [("email", "bad")])) { _ in
            FormResult(fieldErrors: ["email": "Enter a valid email"])
        }
        while form.isPending { await Task.yield() }
        resume?.resume(returning: FormResult(value: "obsolete"))
        for _ in 0..<5 { await Task.yield() }
        #expect(form.result?.fieldErrors["email"] == "Enter a valid email")
        #expect(form.result?.value == nil)
    }

    @Test func formRendersNativeSubmissionContract() {
        let form = EnhancedForm(action: "/contact", submission: FormSubmission<String>(), onSubmit: { _ in
            FormResult(value: "ok")
        }) { _ in Input().attribute("name", "email") }
        let html = HTMLRenderer.render(form)
        #expect(html.contains("action=\"/contact\""))
        #expect(html.contains("method=\"post\""))
        #expect(html.contains("name=\"email\""))
    }
}
