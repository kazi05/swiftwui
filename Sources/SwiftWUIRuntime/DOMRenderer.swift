// DOMRenderer.swift - Renders TagNode trees to the real DOM

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

import SwiftWUICore
import SwiftWUIStyles

/// Renders virtual DOM trees (TagNode) into real browser DOM elements.
/// Handles initial rendering and subsequent updates via reconciliation.
/// - Note: Not isolated to an actor — WASM is single-threaded.
public final class DOMRenderer {

    #if canImport(JavaScriptKit)
    private let bridge: DOMBridge
    private let reconciler: Reconciler
    private var container: JSObject
    private var currentTree: TagNode?
    /// The root DOM node created during render(). Patches are applied to this
    /// node (not the container) because the virtual tree corresponds 1:1 with it.
    private var rootDOMNode: JSObject?

    public init(container: JSObject) {
        self.bridge = DOMBridge()
        self.reconciler = Reconciler()
        self.container = container
    }

    // MARK: - Public API

    /// Perform initial render of a tag tree.
    public func render(_ rootTag: some Tag) {
        EventHandlerRegistry.clear()
        let newTree = TagNode.fragment(resolveTagBody(rootTag))
        let domNode = createDOMNode(newTree)
        bridge.removeAllChildren(container)
        if let domNode {
            bridge.appendChild(container, child: domNode)
            rootDOMNode = domNode
        }
        currentTree = newTree
    }

    /// Update the DOM with a new tag tree (re-render).
    /// - Parameter animation: Optional animation to apply CSS transitions during style updates.
    public func update(_ rootTag: some Tag, animation: Animation? = nil) {
        EventHandlerRegistry.clear()
        let newTree = TagNode.fragment(resolveTagBody(rootTag))

        if let patch = reconciler.diff(old: currentTree, new: newTree),
           let root = rootDOMNode {
            applyPatch(patch, to: root, animation: animation)
        }

        currentTree = newTree
    }

    // MARK: - DOM Node Creation

    private func createDOMNode(_ node: TagNode) -> JSObject? {
        switch node {
        case .text(let text):
            return bridge.createTextNode(text)

        case .element(let element):
            let domElement = bridge.createElement(element.tagName)

            // Set attributes
            for (key, value) in element.attributes {
                bridge.setAttribute(domElement, name: key, value: value)
            }

            // Set classes
            for cls in element.classes {
                bridge.addClass(domElement, className: cls)
            }

            // Set styles
            for (property, value) in element.styles {
                bridge.setStyle(domElement, property: property, value: value)
            }

            // Set event listeners from the global registry (tracked for proper cleanup)
            for (event, listenerID) in element.eventListeners {
                if let handler = EventHandlerRegistry.handler(for: listenerID) {
                    bridge.setTrackedEventListener(domElement, event: event, handler: handler)
                }
            }

            // Create and append children
            for child in element.children {
                if let childDOM = createDOMNode(child) {
                    bridge.appendChild(domElement, child: childDOM)
                }
            }

            return domElement

        case .fragment(let children):
            let fragment = bridge.createElement("div")
            bridge.setAttribute(fragment, name: "data-swiftwui-fragment", value: "true")
            for child in children {
                if let childDOM = createDOMNode(child) {
                    bridge.appendChild(fragment, child: childDOM)
                }
            }
            return fragment
        }
    }

    // MARK: - Patch Application

    private func applyPatch(_ patch: Patch, to element: JSObject, animation: Animation? = nil) {
        switch patch {
        case .createNode(let node):
            if let domNode = createDOMNode(node) {
                bridge.appendChild(element, child: domNode)
            }

        case .removeNode:
            if let parent = element.parentNode.object {
                bridge.removeChild(parent, child: element)
            }

        case .replaceNode(let newNode):
            if let newDOM = createDOMNode(newNode),
               let parent = element.parentNode.object {
                bridge.replaceChild(parent, newChild: newDOM, oldChild: element)
            }

        case .updateText(let text):
            bridge.setTextContent(element, text: text)

        case .updateAttributes(let add, let remove):
            for key in remove {
                bridge.removeAttribute(element, name: key)
            }
            for (key, value) in add {
                bridge.setAttribute(element, name: key, value: value)
            }

        case .updateStyles(let add, let remove):
            // If animation is active, set CSS transition before applying style changes
            if let animation {
                let changedProperties = Array(add.keys) + remove
                if !changedProperties.isEmpty {
                    let transitionValue = animation.cssTransitionValue(for: changedProperties)
                    bridge.setStyle(element, property: "transition", value: transitionValue)
                }
            }
            for property in remove {
                bridge.removeStyle(element, property: property)
            }
            for (property, value) in add {
                bridge.setStyle(element, property: property, value: value)
            }

        case .updateClasses(let add, let remove):
            for cls in remove {
                bridge.removeClass(element, className: cls)
            }
            for cls in add {
                bridge.addClass(element, className: cls)
            }

        case .updateEventListeners(let add, let remove):
            for event in remove {
                bridge.removeTrackedEventListener(element, event: event)
            }
            for (event, listenerID) in add {
                if let handler = EventHandlerRegistry.handler(for: listenerID) {
                    bridge.setTrackedEventListener(element, event: event, handler: handler)
                }
            }

        case .patchChildren(let childPatches):
            for childPatch in childPatches {
                if childPatch.index == -1 {
                    // Apply to self
                    applyPatch(childPatch.patch, to: element, animation: animation)
                } else if let childElement = bridge.childNode(element, at: childPatch.index) {
                    applyPatch(childPatch.patch, to: childElement, animation: animation)
                } else if case .createNode(let node) = childPatch.patch {
                    if let domNode = createDOMNode(node) {
                        bridge.appendChild(element, child: domNode)
                    }
                }
            }
        }
    }

    #else
    // Non-WASM stub
    public init() {}
    public func render(_ rootTag: some Tag) {}
    public func update(_ rootTag: some Tag, animation: Animation? = nil) {}
    #endif
}
