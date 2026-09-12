import JavaScriptKit

/// Stable application-facing API over BridgeJS-generated internal declarations.
/// Regenerate `Generated/` after editing bridge-js.d.ts; do not edit its ABI glue.
public enum AppInterop {
    public static func greet(_ name: String) throws(JSException) -> String {
        try _$interopGreet(name)
    }

    public static func greeting(_ name: String) async throws(JSException) -> String {
        try await _$interopGreetingAsync(name)
    }

    /// Retains the JavaScript callback until `dispose()` or deinitialization.
    public static func subscribe(_ receive: @escaping (String) -> Void) throws(JSException) -> Subscription {
        let callback = JSClosure { values in
            receive(values.first?.string ?? "")
            return .undefined
        }
        let token = try _$interopSubscribe(callback)
        return Subscription(token: token, callback: callback)
    }

    public final class Subscription {
        private var token: Double?
        private var callback: JSClosure?

        fileprivate init(token: Double, callback: JSClosure) {
            self.token = token; self.callback = callback
        }

        /// Stops JavaScript delivery and releases the retained Swift callback.
        public func dispose() throws(JSException) {
            guard let token else { return }
            try _$interopUnsubscribe(token)
            self.token = nil
            #if JAVASCRIPTKIT_WITHOUT_WEAKREFS
            callback?.release()
            #endif
            callback = nil
        }

        deinit {
            // Deinit cannot surface a JavaScript exception. Explicit dispose is
            // preferable where delivery failures need to be handled.
            if let token { try? _$interopUnsubscribe(token) }
            #if JAVASCRIPTKIT_WITHOUT_WEAKREFS
            callback?.release()
            #endif
        }
    }
}
