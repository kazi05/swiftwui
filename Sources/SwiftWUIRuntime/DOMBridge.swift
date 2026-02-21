// DOMBridge.swift - Bridge between Swift and browser DOM via JavaScriptKit

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

import Foundation
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

    /// Remove a child from a parent element.
    public func removeChild(_ parent: JSObject, child: JSObject) {
        _ = parent.removeChild!(child)
    }

    /// Replace a child element.
    public func replaceChild(_ parent: JSObject, newChild: JSObject, oldChild: JSObject) {
        _ = parent.replaceChild!(newChild, oldChild)
    }

    /// Remove all children from an element.
    public func removeAllChildren(_ element: JSObject) {
        element.innerHTML = .string("")
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

    /// Add an event listener to a DOM element.
    /// Returns an ID that can be used to remove the listener.
    public func addEventListener(
        _ element: JSObject,
        event: String,
        handler: @escaping () -> Void
    ) -> String {
        let id = "\(event)-\(UUID().uuidString)"
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

    #else
    // Non-WASM stub for compilation on macOS (testing)
    public init() {}
    #endif
}
