// swift-format-ignore-file
// NOTICE: This is auto-generated code by BridgeJS from JavaScriptKit,
// DO NOT EDIT.
//
// To update this file, just rebuild your project or run
// `swift package bridge-js`.

@_spi(BridgeJS) import JavaScriptKit

@JSGetter(from: .global) var document: SWDocument

@JSClass struct SWDocument {
    @JSFunction func createElement(_ tag: String) throws(JSException) -> SWNode
    @JSFunction func createTextNode(_ data: String) throws(JSException) -> SWNode
}

@JSClass struct SWNode {
    @JSGetter var data: String
    @JSSetter func setData(_ value: String) throws(JSException)
    @JSFunction func appendChild(_ child: SWNode) throws(JSException) -> Void
    @JSFunction func insertBefore(_ node: SWNode, _ anchor: SWNode) throws(JSException) -> Void
    @JSFunction func removeChild(_ child: SWNode) throws(JSException) -> Void
    @JSFunction func setAttribute(_ name: String, _ value: String) throws(JSException) -> Void
    @JSFunction func removeAttribute(_ name: String) throws(JSException) -> Void
}
