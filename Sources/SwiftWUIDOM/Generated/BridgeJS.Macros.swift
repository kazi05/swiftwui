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
    @JSGetter var __swuid: Double
    @JSSetter func set__swuid(_ value: Double) throws(JSException)
    @JSGetter var nodeType: Double
    @JSGetter var tagName: String
    @JSGetter var childNodes: SWNodeList
    @JSGetter var style: SWStyle
    @JSFunction func appendChild(_ child: SWNode) throws(JSException) -> Void
    @JSFunction func insertBefore(_ node: SWNode, _ anchor: SWNode) throws(JSException) -> Void
    @JSFunction func removeChild(_ child: SWNode) throws(JSException) -> Void
    @JSFunction func setAttribute(_ name: String, _ value: String) throws(JSException) -> Void
    @JSFunction func removeAttribute(_ name: String) throws(JSException) -> Void
}

@JSClass struct SWNodeList {
    @JSGetter var length: Double
    @JSFunction func item(_ index: Double) throws(JSException) -> SWNode
}

@JSClass struct SWStyle {
    @JSFunction func setProperty(_ name: String, _ value: String) throws(JSException) -> Void
    @JSFunction func removeProperty(_ name: String) throws(JSException) -> String
}

@JSFunction(from: .global) func fetch(_ url: String, _ options: JSValue) async throws(JSException) -> SWResponse

@JSClass struct SWResponse {
    @JSGetter var status: Double
    @JSFunction func arrayBuffer() async throws(JSException) -> JSValue
}
