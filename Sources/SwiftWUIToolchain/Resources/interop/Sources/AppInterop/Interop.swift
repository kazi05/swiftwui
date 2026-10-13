import JavaScriptKit

// Declared here, not in bridge-js.global.d.ts: TS2Swift lowers a TS function type to
// JSObject, and only a JSTypedClosure can be released by dispose().
@JSFunction(from: .global) func interopSubscribe(_ callback: JSTypedClosure<(String) -> Void>) throws(JSException) -> Double

/// Stable application-facing API over BridgeJS-generated internal declarations.
/// Regenerate `Generated/` after editing bridge-js.global.d.ts or a `@JSFunction`
/// declaration; do not edit its ABI glue.
public enum AppInterop {
    public static func greet(_ name: String) throws(JSException) -> String {
        try _$interopGreet(name)
    }

    public static func greeting(_ name: String) async throws(JSException) -> String {
        try await _$interopGreetingAsync(name)
    }

    /// Retains the JavaScript callback until `dispose()` or deinitialization.
    public static func subscribe(_ receive: @escaping (String) -> Void) throws(JSException) -> Subscription {
        let callback = JSTypedClosure<(String) -> Void>(receive)
        do {
            return Subscription(token: try _$interopSubscribe(callback), callback: callback)
        } catch {
            callback.release()
            throw error
        }
    }

    public final class Subscription {
        private var token: Double?
        private var callback: JSTypedClosure<(String) -> Void>?   // nil after dispose(): frees what receive captured

        fileprivate init(token: Double, callback: JSTypedClosure<(String) -> Void>) {
            self.token = token; self.callback = callback
        }

        /// Stops JavaScript delivery and releases the retained Swift callback.
        public func dispose() throws(JSException) {
            guard let token else { return }
            try _$interopUnsubscribe(token)
            self.token = nil
            callback?.release()
            callback = nil
        }

        deinit {
            // Deinit cannot surface a JavaScript exception. Explicit dispose is
            // preferable where delivery failures need to be handled.
            if let token { try? _$interopUnsubscribe(token) }
            callback?.release()
        }
    }
}
