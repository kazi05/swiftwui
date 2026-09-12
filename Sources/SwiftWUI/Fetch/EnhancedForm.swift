import Observation

/// The host can return these errors with HTTP 422; their presentation remains
/// owned by the form, so labels and aria-describedby can match its controls.
public struct FormResult<Value: Sendable>: Sendable {
    public var value: Value?
    public var fieldErrors: [String: String]
    public var message: String?
    public init(value: Value? = nil, fieldErrors: [String: String] = [:], message: String? = nil) {
        self.value = value; self.fieldErrors = fieldErrors; self.message = message
    }
}
extension FormResult: Codable where Value: Codable { }

@Observable @MainActor public final class FormSubmission<Value: Sendable> {
    nonisolated deinit { }
    public private(set) var isPending = false
    public private(set) var result: FormResult<Value>?
    public private(set) var failure: String?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var operation: Task<Void, Never>?
    public init() { }
    public func submit(_ event: SubmitEvent, using action: @escaping @MainActor (SubmitEvent) async throws -> FormResult<Value>) {
        cancel()
        let current = generation
        isPending = true; failure = nil; result = nil
        operation = Task { [weak self] in
            do {
                let result = try await action(event)
                try Task.checkCancellation()
                guard let self, self.generation == current else { return }
                self.result = result; self.isPending = false; self.operation = nil
            } catch {
                guard let self, self.generation == current else { return }
                self.failure = Task.isCancelled ? nil : String(describing: error)
                self.isPending = false; self.operation = nil
            }
        }
    }
    public func cancel() {
        generation += 1; operation?.cancel(); operation = nil; isPending = false
    }
}

/// Ordinary HTML action/method before hydration, cancellable async submission
/// afterwards. The endpoint must accept the same successful controls in both
/// paths. Use named controls; textual fields are provided in SubmitEvent.
public struct EnhancedForm<Value: Sendable, Content: Tag>: Tag {
    private let url: String
    private let method: HTTPMethod
    private let submission: FormSubmission<Value>
    private let action: @MainActor (SubmitEvent) async throws -> FormResult<Value>
    private let content: (FormSubmission<Value>) -> Content
    public init(action url: String, method: HTTPMethod = .post,
                submission: FormSubmission<Value>,
                onSubmit: @escaping @MainActor (SubmitEvent) async throws -> FormResult<Value>,
                @TagBuilder content: @escaping (FormSubmission<Value>) -> Content) {
        precondition(method == .get || method == .post, "Native forms support GET or POST")
        self.url = url; self.method = method; self.submission = submission
        self.action = onSubmit; self.content = content
    }
    public var body: some Tag {
        Form(onSubmit: { submission.submit($0, using: action) }) { content(submission) }
            .attribute("action", HTMLEscaping.sanitizeURL(url))
            .attribute("method", method.rawValue.lowercased())
            .attribute("aria-busy", submission.isPending ? "true" : nil)
            .onDisappear { submission.cancel() }
    }
}
