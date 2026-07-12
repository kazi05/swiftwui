/// PWA update action (spec 2026-07-12): activates a waiting service worker
/// (SKIP_WAITING) and reloads, or plain-reloads when none is waiting.
private struct ReloadToUpdateKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Activate the waiting app version and reload. No-op default outside a runtime.
    public var reloadToUpdate: () -> Void {
        get { self[ReloadToUpdateKey.self] }
        set { self[ReloadToUpdateKey.self] = newValue }
    }
}
