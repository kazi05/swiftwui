// Clipboard.swift - Browser Clipboard API wrapper

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

/// Provides access to the browser clipboard via the async Clipboard API.
///
/// ```swift
/// Button(onclick: { ClipboardManager.writeText("Copied!") }) {
///     Text("Copy to Clipboard")
/// }
/// ```
public enum ClipboardManager: Sendable {
    /// Write text to the clipboard.
    ///
    /// On non-WASM platforms this is a no-op.
    ///
    /// - Parameter text: The string to place on the clipboard.
    public static func writeText(_ text: String) {
        #if arch(wasm32)
        let clipboard = JSObject.global.navigator.object!.clipboard.object!
        _ = clipboard.writeText!(text)
        #endif
    }

    /// Read text from the clipboard.
    ///
    /// On non-WASM platforms the completion is called synchronously with `nil`.
    ///
    /// - Parameter completion: Called with the clipboard text, or `nil`
    ///   if the read fails (e.g. permission denied).
    public static func readText(completion: @escaping @Sendable (String?) -> Void) {
        #if arch(wasm32)
        let clipboard = JSObject.global.navigator.object!.clipboard.object!
        let promise = clipboard.readText!()
        let thenClosure = JSOneshotClosure { args in
            completion(args[0].string)
            return .undefined
        }
        let catchClosure = JSOneshotClosure { _ in
            completion(nil)
            return .undefined
        }
        _ = promise.object!.then!(thenClosure).object!.catch!(catchClosure)
        #else
        completion(nil)
        #endif
    }
}
