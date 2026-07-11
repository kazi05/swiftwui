#if arch(wasm32)
import JavaScriptKit
import JavaScriptFoundationCompat
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// ArrayBuffer → Data. `fetch()`'s `response.arrayBuffer()` yields a raw
/// ArrayBuffer, not a typed array, so it's wrapped in a Uint8Array first;
/// `Data.construct(from:)` (JavaScriptFoundationCompat) then does the bulk
/// copy — never a per-byte boxed loop.
@MainActor
func _dataFromArrayBuffer(_ buffer: JSValue) -> Data {
    guard let bufObject = buffer.object,
          let u8Object = JSObject.global.Uint8Array.function?.new(bufObject),
          let typed = JSTypedArray<UInt8>(from: u8Object) else { return Data() }
    return Data.construct(from: typed)
}
#endif
