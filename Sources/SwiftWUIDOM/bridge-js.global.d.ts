// SwiftWUI structural DOM subset for BridgeJS (spec §1.2 hybrid boundary).
// Event listeners, nullable getters (getElementById), dynamic property
// writes (setProperty, __swuid) and hydration reads stay on dynamic JSObject.
type SWNode = {
    // CharacterData.data — used by setText on text nodes only.
    data: string
    appendChild(child: SWNode): void
    insertBefore(node: SWNode, anchor: SWNode): void
    removeChild(child: SWNode): void
    setAttribute(name: string, value: string): void
    removeAttribute(name: string): void
}

type SWDocument = {
    createElement(tag: string): SWNode
    createTextNode(data: string): SWNode
}

export const document: SWDocument
