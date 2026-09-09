@MainActor
private final class _WebObjectURLCleanupState {
    nonisolated deinit { }

    private var value: String?
    private var cleanup: (@MainActor @Sendable () -> Void)?

    init(url: String, cleanup: @escaping @MainActor @Sendable () -> Void) {
        self.value = url
        self.cleanup = cleanup
    }

    var urlString: String? { value }
    var isRevoked: Bool { value == nil }

    func revoke() {
        guard let cleanup else { return }
        self.cleanup = nil
        value = nil
        cleanup()
    }
}

@MainActor
/// An identity-based temporary URL handle with explicit, idempotent cleanup.
public final class WebObjectURL: Equatable {
    nonisolated deinit {
        fallbackCleanup()
    }

    private let state: _WebObjectURLCleanupState
    private nonisolated let fallbackCleanup: @Sendable () -> Void

    package init(url: String, revoke: @escaping @MainActor @Sendable () -> Void) {
        let state = _WebObjectURLCleanupState(url: url, cleanup: revoke)
        self.state = state
        self.fallbackCleanup = {
            Task { @MainActor in
                state.revoke()
            }
        }
    }

    /// Whether this handle has been revoked. Reading this value does not schedule a render.
    public var isRevoked: Bool { state.isRevoked }
    package var urlString: String? { state.urlString }

    /// Revokes this temporary URL. Repeated calls have no effect.
    public func revoke() {
        state.revoke()
    }

    public static func == (lhs: WebObjectURL, rhs: WebObjectURL) -> Bool {
        lhs === rhs
    }
}
