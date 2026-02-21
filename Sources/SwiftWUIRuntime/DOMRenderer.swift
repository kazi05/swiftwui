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
    private let styleSheetManager: StyleSheetManager

    /// Active JS observers (IntersectionObserver, ResizeObserver, MutationObserver)
    /// keyed by the ObjectIdentifier of the DOM element.
    private var activeObservers: [ObjectIdentifier: [JSObject]] = [:]

    /// Unmount callback IDs keyed by the ObjectIdentifier of the DOM element.
    private var unmountCallbacks: [ObjectIdentifier: [EventListenerID]] = [:]

    public init(container: JSObject) {
        self.bridge = DOMBridge()
        self.reconciler = Reconciler()
        self.container = container
        self.styleSheetManager = StyleSheetManager(bridge: bridge)
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

        // Pre-register all responsive CSS rules before reconciliation
        // so that .updateClasses patches can rely on rules existing
        preRegisterResponsiveStyles(newTree)

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

            // Set event listeners from the global registry (tracked, with typed event data)
            for (event, listenerID) in element.eventListeners {
                attachEventListener(domElement, event: event, listenerID: listenerID)
            }

            // Apply responsive styles as CSS classes
            for (cssQuery, rStyles) in element.responsiveStyles {
                let className = styleSheetManager.ensureClass(mediaQuery: cssQuery, styles: rStyles)
                bridge.addClass(domElement, className: className)
            }

            // Attach web observers
            if !element.observers.isEmpty {
                createObservers(for: domElement, observers: element.observers)
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
            cleanupObservers(for: element, fireUnmount: true)
            if let parent = element.parentNode.object {
                bridge.removeChild(parent, child: element)
            }

        case .replaceNode(let newNode):
            cleanupObservers(for: element, fireUnmount: true)
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
                attachEventListener(element, event: event, listenerID: listenerID)
            }

        case .updateObservers(let newObservers):
            cleanupObservers(for: element, fireUnmount: false)
            if !newObservers.isEmpty {
                createObservers(for: element, observers: newObservers)
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

    // MARK: - Typed Event Handling

    /// Attach a typed event listener that extracts data from the JS event object.
    /// Events like "input", "scroll", "keydown", "keyup", "paste", "submit" receive
    /// special handling to populate the corresponding EventContext before calling the handler.
    private func attachEventListener(_ element: JSObject, event: String, listenerID: EventListenerID) {
        guard let handler = EventHandlerRegistry.handler(for: listenerID) else { return }

        switch event {
        case "input":
            bridge.setTrackedEventListenerWithEvent(element, event: event) { jsEvent in
                let value = jsEvent.object?["target"].object?["value"].string ?? ""
                InputEventContext.currentValue = value
                handler()
                InputEventContext.currentValue = nil
            }
        case "scroll":
            bridge.setTrackedEventListenerWithEvent(element, event: event) { jsEvent in
                let target = jsEvent.object?["target"].object
                let scrollLeft = target?["scrollLeft"].number ?? 0
                let scrollTop = target?["scrollTop"].number ?? 0
                ScrollEventContext.currentOffset = ScrollOffset(x: scrollLeft, y: scrollTop)
                handler()
                ScrollEventContext.currentOffset = nil
            }
        case "keydown", "keyup":
            bridge.setTrackedEventListenerWithEvent(element, event: event) { jsEvent in
                let obj = jsEvent.object
                let key = obj?["key"].string ?? ""
                let code = obj?["code"].string ?? ""
                let ctrlKey = obj?["ctrlKey"].boolean ?? false
                let shiftKey = obj?["shiftKey"].boolean ?? false
                let altKey = obj?["altKey"].boolean ?? false
                let metaKey = obj?["metaKey"].boolean ?? false
                KeyEventContext.currentKey = KeyInfo(
                    key: key, code: code,
                    ctrlKey: ctrlKey, shiftKey: shiftKey,
                    altKey: altKey, metaKey: metaKey
                )
                handler()
                KeyEventContext.currentKey = nil
            }
        case "paste":
            bridge.setTrackedEventListenerWithEvent(element, event: event) { jsEvent in
                let text = jsEvent.object?["clipboardData"].object?["getData"].function?("text/plain").string ?? ""
                PasteEventContext.currentText = text
                handler()
                PasteEventContext.currentText = nil
            }
        case "submit":
            bridge.setTrackedEventListenerWithEvent(element, event: event) { jsEvent in
                _ = jsEvent.object?["preventDefault"]?()
                handler()
            }
        default:
            bridge.setTrackedEventListener(element, event: event, handler: handler)
        }
    }

    // MARK: - Observer Management

    /// Create JS observers for the given element based on the WebObserver descriptors.
    private func createObservers(for element: JSObject, observers: [WebObserver]) {
        let elementID = ObjectIdentifier(element)
        var jsObservers: [JSObject] = []

        for observer in observers {
            switch observer {
            case .intersection(let threshold, let callbackID):
                guard let handler = EventHandlerRegistry.handler(for: callbackID) else { continue }
                // threshold == -1 means onDisappear (fires when isIntersecting becomes false)
                let isDisappear = threshold < 0
                let actualThreshold = isDisappear ? 0.0 : threshold
                let jsObserver = bridge.createIntersectionObserver(element, threshold: actualThreshold) { isIntersecting, ratio in
                    if isDisappear {
                        if !isIntersecting { handler() }
                    } else {
                        IntersectionContext.currentRatio = ratio
                        handler()
                        IntersectionContext.currentRatio = nil
                    }
                }
                jsObservers.append(jsObserver)

            case .resize(let callbackID):
                guard let handler = EventHandlerRegistry.handler(for: callbackID) else { continue }
                let jsObserver = bridge.createResizeObserver(element) { [weak self] width, height in
                    // Set both size and rect contexts — the handler uses whichever it needs
                    ResizeEventContext.currentSize = ElementSize(width: width, height: height)
                    if let self = self {
                        let rect = self.bridge.getBoundingClientRect(element)
                        FrameChangeContext.currentRect = ElementRect(
                            x: rect.x, y: rect.y, width: rect.width, height: rect.height
                        )
                    }
                    handler()
                    ResizeEventContext.currentSize = nil
                    FrameChangeContext.currentRect = nil
                }
                jsObservers.append(jsObserver)

            case .mutation(let options, let callbackID):
                guard let handler = EventHandlerRegistry.handler(for: callbackID) else { continue }
                let jsObserver = bridge.createMutationObserver(
                    element,
                    childList: options.childList,
                    attributes: options.attributes,
                    subtree: options.subtree,
                    callback: handler
                )
                jsObservers.append(jsObserver)

            case .lifecycle(let event, let callbackID):
                switch event {
                case .mount:
                    // Fire mount callback immediately (element just created / observers just attached)
                    if let handler = EventHandlerRegistry.handler(for: callbackID) {
                        handler()
                    }
                case .unmount:
                    // Store for later — will fire when element is removed
                    var callbacks = unmountCallbacks[elementID] ?? []
                    callbacks.append(callbackID)
                    unmountCallbacks[elementID] = callbacks
                }
            }
        }

        if !jsObservers.isEmpty {
            activeObservers[elementID] = jsObservers
        }
    }

    /// Disconnect all observers for the given element and optionally fire unmount callbacks.
    private func cleanupObservers(for element: JSObject, fireUnmount: Bool) {
        let elementID = ObjectIdentifier(element)

        // Disconnect JS observers
        if let observers = activeObservers.removeValue(forKey: elementID) {
            for observer in observers {
                bridge.disconnectObserver(observer)
            }
        }

        // Fire unmount callbacks if requested
        if fireUnmount, let callbacks = unmountCallbacks.removeValue(forKey: elementID) {
            for callbackID in callbacks {
                if let handler = EventHandlerRegistry.handler(for: callbackID) {
                    handler()
                }
            }
        } else {
            unmountCallbacks.removeValue(forKey: elementID)
        }
    }

    // MARK: - Responsive Style Pre-registration

    /// Walks the TagNode tree and pre-registers all responsive CSS rules
    /// with the StyleSheetManager. This ensures that when the Reconciler
    /// produces `.updateClasses` patches, the corresponding `@media` CSS
    /// rules already exist in the `<style>` element.
    private func preRegisterResponsiveStyles(_ node: TagNode) {
        switch node {
        case .element(let el):
            for (cssQuery, rStyles) in el.responsiveStyles {
                _ = styleSheetManager.ensureClass(mediaQuery: cssQuery, styles: rStyles)
            }
            for child in el.children {
                preRegisterResponsiveStyles(child)
            }
        case .fragment(let children):
            for child in children {
                preRegisterResponsiveStyles(child)
            }
        case .text:
            break
        }
    }

    #else
    // Non-WASM stub
    public init() {}
    public func render(_ rootTag: some Tag) {}
    public func update(_ rootTag: some Tag, animation: Animation? = nil) {}
    #endif
}
