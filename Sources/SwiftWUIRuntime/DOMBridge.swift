// DOMBridge.swift - Bridge between Swift and browser DOM via JavaScriptKit

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

#if !arch(wasm32)
import Foundation
#endif

import SwiftWUICore

/// Provides a Swift-friendly wrapper around browser DOM operations via JavaScriptKit.
/// All DOM manipulation goes through this bridge.
/// - Note: Not isolated to an actor — WASM is single-threaded.
public final class DOMBridge {

    #if canImport(JavaScriptKit)
    /// The JavaScript `document` global object.
    private let document: JSObject

    /// Storage for active JSClosure instances to prevent deallocation.
    private var closures: [String: JSClosure] = [:]

    public init() {
        self.document = JSObject.global.document.object!
    }

    // MARK: - Element Creation

    /// Create a DOM element with the given tag name.
    public func createElement(_ tagName: String) -> JSObject {
        document.createElement!(tagName).object!
    }

    /// Create a text node.
    public func createTextNode(_ text: String) -> JSObject {
        document.createTextNode!(text).object!
    }

    // MARK: - Element Manipulation

    /// Set an attribute on a DOM element.
    public func setAttribute(_ element: JSObject, name: String, value: String) {
        _ = element.setAttribute!(name, value)
    }

    /// Remove an attribute from a DOM element.
    public func removeAttribute(_ element: JSObject, name: String) {
        _ = element.removeAttribute!(name)
    }

    /// Set inline style property on a DOM element.
    public func setStyle(_ element: JSObject, property: String, value: String) {
        element.style.object![property] = .string(value)
    }

    /// Remove inline style property.
    public func removeStyle(_ element: JSObject, property: String) {
        element.style.object![property] = .string("")
    }

    /// Add a CSS class to an element.
    public func addClass(_ element: JSObject, className: String) {
        _ = element.classList.object!.add!(className)
    }

    /// Remove a CSS class from an element.
    public func removeClass(_ element: JSObject, className: String) {
        _ = element.classList.object!.remove!(className)
    }

    /// Set the text content of an element.
    public func setTextContent(_ element: JSObject, text: String) {
        element.textContent = .string(text)
    }

    // MARK: - Tree Operations

    /// Append a child to a parent element.
    public func appendChild(_ parent: JSObject, child: JSObject) {
        _ = parent.appendChild!(child)
    }

    /// Insert a child before a reference node.
    public func insertBefore(_ parent: JSObject, newChild: JSObject, referenceChild: JSObject?) {
        if let ref = referenceChild {
            _ = parent.insertBefore!(newChild, ref)
        } else {
            _ = parent.appendChild!(newChild)
        }
    }

    /// Remove a child from a parent element. Also cleans up any tracked event
    /// listeners on the subtree being removed so the `closures` dictionary
    /// does not retain orphaned `JSClosure` instances after the DOM nodes go
    /// away. Failing to do this leaks one closure per tracked listener per
    /// removal, which adds up quickly during route changes and hot reloads.
    public func removeChild(_ parent: JSObject, child: JSObject) {
        cleanupTrackedListenersInSubtree(child)
        _ = parent.removeChild!(child)
    }

    /// Replace a child element. Cleans up tracked listeners on the discarded
    /// subtree (see `removeChild`).
    public func replaceChild(_ parent: JSObject, newChild: JSObject, oldChild: JSObject) {
        cleanupTrackedListenersInSubtree(oldChild)
        _ = parent.replaceChild!(newChild, oldChild)
    }

    /// Remove all children from an element. Walks every descendant first,
    /// removes any `__swev_*` closure IDs from the bridge-owned `closures`
    /// dictionary, and then truncates the DOM with `replaceChildren()`. This
    /// preserves `JSClosure` ownership invariants — the only place
    /// `JSClosure` instances live is `closures`, and orphaning them there
    /// would prevent the JS garbage collector from reclaiming the wrapped
    /// JS function objects.
    public func removeAllChildren(_ element: JSObject) {
        if let childNodes = element.childNodes.object {
            let length = Int(childNodes.length.number ?? 0)
            for i in 0..<length {
                if let child = childNodes[i].object {
                    cleanupTrackedListenersInSubtree(child)
                }
            }
        }
        if element.replaceChildren.function != nil {
            _ = element.replaceChildren!()
        } else {
            element.innerHTML = .string("")
        }
    }

    /// Walk a DOM subtree and remove every tracked-listener closure ID
    /// (`__swev_<event>`) we previously installed on its elements. Each ID
    /// removed from the `closures` dictionary releases the corresponding
    /// `JSClosure`, which in turn lets the JS-side garbage collector reclaim
    /// the wrapping function. Closures registered for observers
    /// (`io-`/`ro-`/`mo-` prefixes) live independently in `closures` and are
    /// torn down by `disconnectObserver` callers in `DOMRenderer`.
    private func cleanupTrackedListenersInSubtree(_ element: JSObject) {
        // Discover event property keys (`__swev_*`) on this element via Object.keys.
        if let keysFn = JSObject.global.Object.keys.function,
           let keysArray = keysFn(element).object {
            let keyCount = Int(keysArray.length.number ?? 0)
            for i in 0..<keyCount {
                guard let key = keysArray[i].string, key.hasPrefix("__swev_") else { continue }
                if let id = element[key].string {
                    closures.removeValue(forKey: id)
                }
            }
        }

        // Recurse into element children. Use `children` (Element nodes only) —
        // text nodes cannot host tracked listeners.
        if let kids = element.children.object {
            let length = Int(kids.length.number ?? 0)
            for i in 0..<length {
                if let child = kids[i].object {
                    cleanupTrackedListenersInSubtree(child)
                }
            }
        }
    }

    // MARK: - Query

    /// Get element by ID.
    public func getElementById(_ id: String) -> JSObject? {
        document.getElementById!(id).object
    }

    /// Get child nodes count.
    public func childNodesCount(_ element: JSObject) -> Int {
        Int(element.childNodes.object!.length.number!)
    }

    /// Get child node at index.
    public func childNode(_ element: JSObject, at index: Int) -> JSObject? {
        element.childNodes.object![index].object
    }

    // MARK: - Event Handling

    /// Monotonic counter feeding `nextClosureID()`. WASM is single-threaded
    /// so plain mutation is safe; on native we wrap in an `NSLock` (only
    /// used by tests / SSR).
    private var closureIDCounter: UInt64 = 0
    #if !arch(wasm32)
    private let closureIDLock = NSLock()
    #endif

    /// Generate a unique closure ID for a tracked listener. WASM uses a
    /// monotonic counter (no Foundation dependency, no UUID heap allocation).
    /// Native uses UUIDs to remain race-free under parallel test execution
    /// where multiple bridge instances or threads could collide on a counter.
    private func nextClosureID(prefix: String) -> String {
        #if arch(wasm32)
        closureIDCounter &+= 1
        return "\(prefix)-\(closureIDCounter)"
        #else
        closureIDLock.lock()
        closureIDCounter &+= 1
        let n = closureIDCounter
        closureIDLock.unlock()
        return "\(prefix)-\(n)-\(UUID().uuidString)"
        #endif
    }

    /// Add an event listener to a DOM element.
    /// Returns an ID that can be used to remove the listener.
    public func addEventListener(
        _ element: JSObject,
        event: String,
        handler: @escaping () -> Void
    ) -> String {
        let id = nextClosureID(prefix: event)
        let closure = JSClosure { _ in
            handler()
            return .undefined
        }
        closures[id] = closure
        _ = element.addEventListener!(event, closure)
        return id
    }

    /// Remove an event listener by its ID.
    public func removeEventListener(_ element: JSObject, event: String, id: String) {
        if let closure = closures.removeValue(forKey: id) {
            _ = element.removeEventListener!(event, closure)
        }
    }

    /// Set an event handler on a DOM element, replacing any previous handler for the same event.
    /// Uses a data attribute to track the closure ID for proper cleanup.
    public func setTrackedEventListener(
        _ element: JSObject,
        event: String,
        handler: @escaping () -> Void
    ) {
        let dataKey = "__swev_\(event)"
        // Remove previous listener for this event if present
        if let oldId = element[dataKey].string {
            removeEventListener(element, event: event, id: oldId)
        }
        let id = addEventListener(element, event: event, handler: handler)
        element[dataKey] = .string(id)
    }

    /// Remove a tracked event listener from a DOM element.
    public func removeTrackedEventListener(_ element: JSObject, event: String) {
        let dataKey = "__swev_\(event)"
        if let oldId = element[dataKey].string {
            removeEventListener(element, event: event, id: oldId)
            element[dataKey] = .undefined
        }
    }

    // MARK: - Typed Event Listeners

    /// Add an event listener that receives the raw JSValue event object.
    public func addEventListenerWithEvent(
        _ element: JSObject,
        event: String,
        handler: @escaping (JSValue) -> Void
    ) -> String {
        let id = nextClosureID(prefix: event)
        let closure = JSClosure { args in
            let jsEvent = args.count > 0 ? args[0] : .undefined
            handler(jsEvent)
            return .undefined
        }
        closures[id] = closure
        _ = element.addEventListener!(event, closure)
        return id
    }

    /// Set a tracked event listener that receives the raw JS event object.
    public func setTrackedEventListenerWithEvent(
        _ element: JSObject,
        event: String,
        handler: @escaping (JSValue) -> Void
    ) {
        let dataKey = "__swev_\(event)"
        if let oldId = element[dataKey].string {
            removeEventListener(element, event: event, id: oldId)
        }
        let id = addEventListenerWithEvent(element, event: event, handler: handler)
        element[dataKey] = .string(id)
    }

    // MARK: - Web Observers

    /// Create an IntersectionObserver for the given element.
    public func createIntersectionObserver(
        _ element: JSObject,
        threshold: Double,
        callback: @escaping (Bool, Double) -> Void
    ) -> JSObject {
        let jsClosure = JSClosure { args in
            guard let entries = args.first?.object else { return .undefined }
            let length = entries["length"].number.map(Int.init) ?? 0
            for i in 0..<length {
                if let entry = entries[i].object {
                    let isIntersecting = entry["isIntersecting"].boolean ?? false
                    let ratio = entry["intersectionRatio"].number ?? 0
                    callback(isIntersecting, ratio)
                }
            }
            return .undefined
        }
        let options = JSObject.global.Object.function!.new()
        options["threshold"] = .number(threshold < 0 ? 0 : threshold)
        let observer = JSObject.global.IntersectionObserver.function!.new(jsClosure, options)
        closures[nextClosureID(prefix: "io")] = jsClosure
        _ = observer.observe!(element)
        return observer
    }

    /// Create a ResizeObserver for the given element.
    public func createResizeObserver(
        _ element: JSObject,
        callback: @escaping (Double, Double) -> Void
    ) -> JSObject {
        let jsClosure = JSClosure { args in
            guard let entries = args.first?.object else { return .undefined }
            let length = entries["length"].number.map(Int.init) ?? 0
            for i in 0..<length {
                if let entry = entries[i].object,
                   let contentRect = entry["contentRect"].object {
                    let width = contentRect["width"].number ?? 0
                    let height = contentRect["height"].number ?? 0
                    callback(width, height)
                }
            }
            return .undefined
        }
        let observer = JSObject.global.ResizeObserver.function!.new(jsClosure)
        closures[nextClosureID(prefix: "ro")] = jsClosure
        _ = observer.observe!(element)
        return observer
    }

    /// Create a MutationObserver for the given element.
    public func createMutationObserver(
        _ element: JSObject,
        childList: Bool,
        attributes: Bool,
        subtree: Bool,
        callback: @escaping () -> Void
    ) -> JSObject {
        let jsClosure = JSClosure { _ in
            callback()
            return .undefined
        }
        let observer = JSObject.global.MutationObserver.function!.new(jsClosure)
        let config = JSObject.global.Object.function!.new()
        config["childList"] = .boolean(childList)
        config["attributes"] = .boolean(attributes)
        config["subtree"] = .boolean(subtree)
        closures[nextClosureID(prefix: "mo")] = jsClosure
        _ = observer.observe!(element, config)
        return observer
    }

    /// Disconnect a JS observer (IntersectionObserver, ResizeObserver, MutationObserver).
    public func disconnectObserver(_ observer: JSObject) {
        _ = observer.disconnect?()
    }

    /// Get the bounding client rect of a DOM element.
    public func getBoundingClientRect(_ element: JSObject) -> (x: Double, y: Double, width: Double, height: Double) {
        guard let rect = element.getBoundingClientRect?().object else {
            return (0, 0, 0, 0)
        }
        return (
            x: rect["x"].number ?? 0,
            y: rect["y"].number ?? 0,
            width: rect["width"].number ?? 0,
            height: rect["height"].number ?? 0
        )
    }

    // MARK: - History API

    /// Push a new state to the browser history.
    public func pushState(path: String) {
        _ = JSObject.global.history.object!.pushState!(JSValue.null, "", path)
    }

    /// Replace the current state in the browser history.
    public func replaceState(path: String) {
        _ = JSObject.global.history.object!.replaceState!(JSValue.null, "", path)
    }

    /// Get the current pathname.
    public func currentPathname() -> String {
        JSObject.global.location.object!.pathname.string ?? "/"
    }

    /// Listen for popstate events (back/forward navigation).
    public func onPopState(handler: @escaping (String) -> Void) {
        let closure = JSClosure { _ in
            let path = JSObject.global.location.object!.pathname.string ?? "/"
            handler(path)
            return .undefined
        }
        closures["popstate"] = closure
        _ = JSObject.global.addEventListener!("popstate", closure)
    }

    // MARK: - Document

    /// Set the document title.
    public func setTitle(_ title: String) {
        document.title = .string(title)
    }

    // MARK: - Web Animations API

    /// Animate an element using the Web Animations API (element.animate()).
    /// - Parameters:
    ///   - element: The DOM element to animate.
    ///   - keyframes: Array of keyframe dictionaries (e.g., [["opacity": "0"], ["opacity": "1"]]).
    ///   - duration: Animation duration in milliseconds.
    ///   - easing: CSS easing function string (e.g., "ease-in-out").
    ///   - fill: Fill mode ("none", "forwards", "backwards", "both").
    /// - Returns: The Animation object (JSObject) or nil.
    @discardableResult
    public func animate(
        _ element: JSObject,
        keyframes: [[String: String]],
        duration: Double,
        easing: String = "ease",
        fill: String = "none"
    ) -> JSObject? {
        // Convert Swift keyframe dicts to JS array of objects
        let jsKeyframes = keyframes.map { frame -> JSObject in
            let obj = JSObject.global.Object.function!.new()
            for (key, value) in frame {
                obj[key] = .string(value)
            }
            return obj
        }

        let jsArray = JSObject.global.Array.function!.new()
        for (i, kf) in jsKeyframes.enumerated() {
            jsArray[i] = .object(kf)
        }

        let options = JSObject.global.Object.function!.new()
        options["duration"] = .number(duration)
        options["easing"] = .string(easing)
        options["fill"] = .string(fill)

        return element.animate?(jsArray, options).object
    }

    /// Request animation frame (browser requestAnimationFrame wrapper).
    /// - Parameter callback: The callback to invoke on the next frame.
    public func requestAnimationFrame(_ callback: @escaping () -> Void) {
        let closure = JSOneshotClosure { _ in
            callback()
            return .undefined
        }
        _ = JSObject.global.requestAnimationFrame!(closure)
    }

    /// Wrap a DOM mutation in a `document.startViewTransition()` call so the
    /// browser animates the before/after states using the View Transitions
    /// API. Falls back to invoking the callback immediately on browsers
    /// that lack the API. Pair with `.viewTransitionName(_:)` on
    /// individual elements to enable matched-element morphs.
    public func startViewTransition(_ callback: @escaping () -> Void) {
        let doc = JSObject.global.document.object!
        // Feature-detect: `startViewTransition` is undefined on browsers
        // that have not shipped the API yet (Safari < 18, Firefox < 130).
        guard doc.startViewTransition.function != nil else {
            callback()
            return
        }
        let closure = JSOneshotClosure { _ in
            callback()
            return .undefined
        }
        _ = doc.startViewTransition!(closure)
    }

    // MARK: - Window

    /// Get a value from `window` by key.
    public func windowProperty(_ key: String) -> JSValue {
        JSObject.global[key]
    }

    /// Call `window.setTimeout`.
    public func setTimeout(_ callback: @escaping () -> Void, milliseconds: Int) {
        let closure = JSOneshotClosure { _ in
            callback()
            return .undefined
        }
        _ = JSObject.global.setTimeout!(closure, milliseconds)
    }

    // MARK: - Style Sheet Management

    /// Get or create a `<style>` element with the given ID in `<head>`.
    public func getOrCreateStyleElement(id: String) -> JSObject {
        if let existing = document.getElementById!(id).object {
            return existing
        }
        let style = document.createElement!("style").object!
        _ = style.setAttribute!("id", id)
        let head = document.head.object ?? document.getElementsByTagName!("head").object![0].object!
        _ = head.appendChild!(style)
        return style
    }

    /// Append a CSS rule text to a `<style>` element.
    public func appendCSSRule(_ styleElement: JSObject, rule: String) {
        let current = styleElement.textContent.string ?? ""
        styleElement.textContent = .string(current + "\n" + rule)
    }

    #else
    // Non-WASM stub for compilation on macOS (testing)
    public init() {}
    #endif
}
