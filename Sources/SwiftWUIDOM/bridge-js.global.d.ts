// SwiftWUI structural DOM subset for BridgeJS (spec §1.2 hybrid boundary).
// Per-node hot paths (uid stamp and read, inline style, hydration reads) are
// typed: a dynamic JSObject member access retains and releases its name string
// in JavaScriptKit's object table, which slows as live references grow. Event
// listeners, nullable getters (getElementById) and named property writes
// (DOMBackend.setProperty) stay on dynamic JSObject.
type SWNode = {
    // CharacterData.data — used by setText on text nodes only.
    data: string
    // DOMBackend's per-node id expando; reads NaN until stamped.
    __swuid: number
    readonly nodeType: number
    // Element.tagName — read only when nodeType == 1.
    readonly tagName: string
    readonly childNodes: SWNodeList
    readonly style: SWStyle
    appendChild(child: SWNode): void
    insertBefore(node: SWNode, anchor: SWNode): void
    removeChild(child: SWNode): void
    setAttribute(name: string, value: string): void
    removeAttribute(name: string): void
}

type SWNodeList = {
    readonly length: number
    item(index: number): SWNode
}

type SWStyle = {
    setProperty(name: string, value: string): void
    removeProperty(name: string): string
}

type SWDocument = {
    createElement(tag: string): SWNode
    createTextNode(data: string): SWNode
}

export const document: SWDocument

// fetch() typed entry (spec §1.2) — options/response bodies stay `any`;
// headers iteration and AbortController stay dynamic (hybrid boundary).
type SWResponse = {
    readonly status: number
    arrayBuffer(): Promise<any>
}
export function fetch(url: string, options: any): Promise<SWResponse>
