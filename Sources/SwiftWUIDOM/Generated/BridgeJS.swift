// bridge-js: skip
// swift-format-ignore-file
// NOTICE: This is auto-generated code by BridgeJS from JavaScriptKit,
// DO NOT EDIT.
//
// To update this file, just rebuild your project or run
// `swift package bridge-js`.

@_spi(BridgeJS) import JavaScriptKit

#if arch(wasm32)
@_extern(wasm, module: "SwiftWUIDOM", name: "bjs_document_get")
fileprivate func bjs_document_get_extern() -> Int32
#else
fileprivate func bjs_document_get_extern() -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_document_get() -> Int32 {
    return bjs_document_get_extern()
}

func _$document_get() throws(JSException) -> SWDocument {
    let ret = bjs_document_get()
    if let error = _swift_js_take_exception() {
        throw error
    }
    return SWDocument.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "SwiftWUIDOM", name: "bjs_SWDocument_createElement")
fileprivate func bjs_SWDocument_createElement_extern(_ self: Int32, _ tagBytes: Int32, _ tagLength: Int32) -> Int32
#else
fileprivate func bjs_SWDocument_createElement_extern(_ self: Int32, _ tagBytes: Int32, _ tagLength: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_SWDocument_createElement(_ self: Int32, _ tagBytes: Int32, _ tagLength: Int32) -> Int32 {
    return bjs_SWDocument_createElement_extern(self, tagBytes, tagLength)
}

#if arch(wasm32)
@_extern(wasm, module: "SwiftWUIDOM", name: "bjs_SWDocument_createTextNode")
fileprivate func bjs_SWDocument_createTextNode_extern(_ self: Int32, _ dataBytes: Int32, _ dataLength: Int32) -> Int32
#else
fileprivate func bjs_SWDocument_createTextNode_extern(_ self: Int32, _ dataBytes: Int32, _ dataLength: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_SWDocument_createTextNode(_ self: Int32, _ dataBytes: Int32, _ dataLength: Int32) -> Int32 {
    return bjs_SWDocument_createTextNode_extern(self, dataBytes, dataLength)
}

func _$SWDocument_createElement(_ self: JSObject, _ tag: String) throws(JSException) -> SWNode {
    let selfValue = self.bridgeJSLowerParameter()
    let ret0 = tag.bridgeJSWithLoweredParameter { (tagBytes, tagLength) in
        let ret = bjs_SWDocument_createElement(selfValue, tagBytes, tagLength)
        return ret
    }
    let ret = ret0
    if let error = _swift_js_take_exception() {
        throw error
    }
    return SWNode.bridgeJSLiftReturn(ret)
}

func _$SWDocument_createTextNode(_ self: JSObject, _ data: String) throws(JSException) -> SWNode {
    let selfValue = self.bridgeJSLowerParameter()
    let ret0 = data.bridgeJSWithLoweredParameter { (dataBytes, dataLength) in
        let ret = bjs_SWDocument_createTextNode(selfValue, dataBytes, dataLength)
        return ret
    }
    let ret = ret0
    if let error = _swift_js_take_exception() {
        throw error
    }
    return SWNode.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "SwiftWUIDOM", name: "bjs_SWNode_data_get")
fileprivate func bjs_SWNode_data_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_SWNode_data_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_SWNode_data_get(_ self: Int32) -> Int32 {
    return bjs_SWNode_data_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "SwiftWUIDOM", name: "bjs_SWNode_data_set")
fileprivate func bjs_SWNode_data_set_extern(_ self: Int32, _ newValueBytes: Int32, _ newValueLength: Int32) -> Void
#else
fileprivate func bjs_SWNode_data_set_extern(_ self: Int32, _ newValueBytes: Int32, _ newValueLength: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_SWNode_data_set(_ self: Int32, _ newValueBytes: Int32, _ newValueLength: Int32) -> Void {
    return bjs_SWNode_data_set_extern(self, newValueBytes, newValueLength)
}

#if arch(wasm32)
@_extern(wasm, module: "SwiftWUIDOM", name: "bjs_SWNode_appendChild")
fileprivate func bjs_SWNode_appendChild_extern(_ self: Int32, _ child: Int32) -> Void
#else
fileprivate func bjs_SWNode_appendChild_extern(_ self: Int32, _ child: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_SWNode_appendChild(_ self: Int32, _ child: Int32) -> Void {
    return bjs_SWNode_appendChild_extern(self, child)
}

#if arch(wasm32)
@_extern(wasm, module: "SwiftWUIDOM", name: "bjs_SWNode_insertBefore")
fileprivate func bjs_SWNode_insertBefore_extern(_ self: Int32, _ node: Int32, _ anchor: Int32) -> Void
#else
fileprivate func bjs_SWNode_insertBefore_extern(_ self: Int32, _ node: Int32, _ anchor: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_SWNode_insertBefore(_ self: Int32, _ node: Int32, _ anchor: Int32) -> Void {
    return bjs_SWNode_insertBefore_extern(self, node, anchor)
}

#if arch(wasm32)
@_extern(wasm, module: "SwiftWUIDOM", name: "bjs_SWNode_removeChild")
fileprivate func bjs_SWNode_removeChild_extern(_ self: Int32, _ child: Int32) -> Void
#else
fileprivate func bjs_SWNode_removeChild_extern(_ self: Int32, _ child: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_SWNode_removeChild(_ self: Int32, _ child: Int32) -> Void {
    return bjs_SWNode_removeChild_extern(self, child)
}

#if arch(wasm32)
@_extern(wasm, module: "SwiftWUIDOM", name: "bjs_SWNode_setAttribute")
fileprivate func bjs_SWNode_setAttribute_extern(_ self: Int32, _ nameBytes: Int32, _ nameLength: Int32, _ valueBytes: Int32, _ valueLength: Int32) -> Void
#else
fileprivate func bjs_SWNode_setAttribute_extern(_ self: Int32, _ nameBytes: Int32, _ nameLength: Int32, _ valueBytes: Int32, _ valueLength: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_SWNode_setAttribute(_ self: Int32, _ nameBytes: Int32, _ nameLength: Int32, _ valueBytes: Int32, _ valueLength: Int32) -> Void {
    return bjs_SWNode_setAttribute_extern(self, nameBytes, nameLength, valueBytes, valueLength)
}

#if arch(wasm32)
@_extern(wasm, module: "SwiftWUIDOM", name: "bjs_SWNode_removeAttribute")
fileprivate func bjs_SWNode_removeAttribute_extern(_ self: Int32, _ nameBytes: Int32, _ nameLength: Int32) -> Void
#else
fileprivate func bjs_SWNode_removeAttribute_extern(_ self: Int32, _ nameBytes: Int32, _ nameLength: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_SWNode_removeAttribute(_ self: Int32, _ nameBytes: Int32, _ nameLength: Int32) -> Void {
    return bjs_SWNode_removeAttribute_extern(self, nameBytes, nameLength)
}

func _$SWNode_data_get(_ self: JSObject) throws(JSException) -> String {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_SWNode_data_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return String.bridgeJSLiftReturn(ret)
}

func _$SWNode_data_set(_ self: JSObject, _ newValue: String) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    newValue.bridgeJSWithLoweredParameter { (newValueBytes, newValueLength) in
        bjs_SWNode_data_set(selfValue, newValueBytes, newValueLength)
    }
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$SWNode_appendChild(_ self: JSObject, _ child: SWNode) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let childValue = child.bridgeJSLowerParameter()
    bjs_SWNode_appendChild(selfValue, childValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$SWNode_insertBefore(_ self: JSObject, _ node: SWNode, _ anchor: SWNode) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let nodeValue = node.bridgeJSLowerParameter()
    let anchorValue = anchor.bridgeJSLowerParameter()
    bjs_SWNode_insertBefore(selfValue, nodeValue, anchorValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$SWNode_removeChild(_ self: JSObject, _ child: SWNode) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let childValue = child.bridgeJSLowerParameter()
    bjs_SWNode_removeChild(selfValue, childValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$SWNode_setAttribute(_ self: JSObject, _ name: String, _ value: String) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    name.bridgeJSWithLoweredParameter { (nameBytes, nameLength) in
        value.bridgeJSWithLoweredParameter { (valueBytes, valueLength) in
            bjs_SWNode_setAttribute(selfValue, nameBytes, nameLength, valueBytes, valueLength)
        }
    }
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$SWNode_removeAttribute(_ self: JSObject, _ name: String) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    name.bridgeJSWithLoweredParameter { (nameBytes, nameLength) in
        bjs_SWNode_removeAttribute(selfValue, nameBytes, nameLength)
    }
    if let error = _swift_js_take_exception() {
        throw error
    }
}