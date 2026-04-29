import Testing
@testable import SwiftWUIState

private struct LoginValues {
    var email: String = ""
    var password: String = ""
    var rememberMe: Bool = false
}

@Suite("FormState")
struct FormStateTests {
    @Test("init seeds the values dictionary")
    func initSeedsValues() {
        let form = FormState(values: LoginValues(email: "user@example.com"))
        #expect(form.values.email == "user@example.com")
        #expect(form.values.password == "")
        #expect(form.errors.isEmpty)
        #expect(form.isSubmitting == false)
    }

    @Test("bind(_:) round-trips value changes through the schema")
    func bindRoundTrip() {
        let form = FormState(values: LoginValues())
        let emailBinding = form.bind(\.email)
        emailBinding.wrappedValue = "new@example.com"
        #expect(form.values.email == "new@example.com")
        #expect(emailBinding.wrappedValue == "new@example.com")
    }

    @Test("bind(_:) supports Bool fields too")
    func bindBool() {
        let form = FormState(values: LoginValues())
        let toggle = form.bind(\.rememberMe)
        toggle.wrappedValue = true
        #expect(form.values.rememberMe == true)
    }

    @Test("setError(_:for:) and error(for:) round-trip")
    func errorRoundTrip() {
        let form = FormState(values: LoginValues())
        form.setError("invalid", for: \.email)
        #expect(form.error(for: \.email) == "invalid")
        form.setError(nil, for: \.email)
        #expect(form.error(for: \.email) == nil)
    }

    @Test("clearErrors wipes both errors and submitError")
    func clearErrorsResets() {
        struct Boom: Error {}
        let form = FormState(values: LoginValues())
        form.setError("x", for: \.email)
        form.submitError = Boom()
        form.clearErrors()
        #expect(form.errors.isEmpty)
        #expect(form.submitError == nil)
    }

    @Test("submit toggles isSubmitting around a successful operation")
    func submitSuccessFlow() async {
        let form = FormState(values: LoginValues())
        await form.submit { /* no-op success */ }
        #expect(form.isSubmitting == false)
        #expect(form.submitError == nil)
    }

    @Test("submit captures thrown errors into submitError instead of re-throwing")
    func submitFailureCapturesError() async {
        struct Boom: Error {}
        let form = FormState(values: LoginValues())
        await form.submit { throw Boom() }
        #expect(form.isSubmitting == false)
        #expect(form.submitError != nil)
    }

    @Test("submit refuses concurrent calls (re-entrancy guard)")
    func submitNoReentrance() async {
        let form = FormState(values: LoginValues())
        // Set isSubmitting manually to simulate an in-flight call; the
        // second submit should be a no-op rather than mutating state.
        form.isSubmitting = true
        await form.submit { Issue.record("operation should not run while another submit is in flight") }
        // Restore.
        form.isSubmitting = false
    }
}
