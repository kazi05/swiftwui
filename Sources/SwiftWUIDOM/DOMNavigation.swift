#if arch(wasm32)
import JavaScriptKit
import SwiftWUI

/// Configure before mounting. A nil focus selector preserves application focus.
@MainActor public struct DOMNavigationOptions {
    public var focusSelector: String? = "[data-swui-route-focus], main, h1"
    public var announce = true
    public var restoreScroll = true
    public init() { }
    public static var disabled: Self {
        var value = Self(); value.focusSelector = nil; value.announce = false; value.restoreScroll = false
        return value
    }
}

@MainActor final class DOMNavigationController {
    private var positions: [Int: (Double, Double)] = [:]
    private var nextID = 0
    private var currentID = 0
    private var isHistory = false
    private var epoch = 0
    private var announcer: JSObject?
    private let options: DOMNavigationOptions
    init(options: DOMNavigationOptions) {
        self.options = options
        if options.restoreScroll { JSObject.global.history.scrollRestoration = .string("manual") }
        stampCurrentEntry()
    }
    private func stampCurrentEntry() {
        let history = JSObject.global.history.object!
        let state = JSObject.global.Object.object!.assign!(JSObject.global.Object.function!.new(), history.state).object!
        state["__swiftwuiEntry"] = .number(Double(currentID))
        _ = history.replaceState?(state, "")
    }
    func begin(isHistory: Bool) {
        positions[currentID] = (JSObject.global.scrollX.number ?? 0, JSObject.global.scrollY.number ?? 0)
        self.isHistory = isHistory
        epoch += 1
        if isHistory {
            if let id = JSObject.global.history.state.object?["__swiftwuiEntry"].number {
                currentID = Int(id)
            } else { nextID += 1; currentID = nextID; stampCurrentEntry() }
        }
    }
    func moved(replace: Bool) {
        if !replace { nextID += 1; currentID = nextID }
        stampCurrentEntry()
    }
    func commit() {
        let document = JSObject.global.document.object!
        if options.announce {
            if announcer == nil {
                let node = document.createElement!("div").object!
                _ = node.setAttribute?("aria-live", "polite")
                _ = node.setAttribute?("aria-atomic", "true")
                _ = node.setAttribute?("data-swui-route-announcer", "")
                _ = node.setAttribute?("style", "position:absolute;width:1px;height:1px;padding:0;overflow:hidden;clip-path:inset(50%);white-space:nowrap")
                _ = document.body.object?.appendChild?(node)
                announcer = node
            }
            announcer?.textContent = .string(document.title.string ?? "")
        }
        if let selector = options.focusSelector,
           let target = document.querySelector?(selector).object {
            let hadTabIndex = target.hasAttribute?("tabindex").boolean ?? false
            if !hadTabIndex { _ = target.setAttribute?("tabindex", "-1") }
            let settings = JSObject.global.Object.function!.new()
            settings.preventScroll = .boolean(true)
            _ = target.focus?(settings)
            // Keep the programmatic focus target focusable. Removing tabindex
            // immediately can drop activeElement back to body in browsers.
        }
        guard options.restoreScroll else { return }
        let position = isHistory ? positions[currentID] ?? (0, 0) : (0, 0)
        let version = epoch
        _ = JSObject.global.requestAnimationFrame?(JSOneshotClosure { [weak self] _ in
            guard let self, self.epoch == version else { return .undefined }
            let hash = JSObject.global.location.hash.string ?? ""
            let fragment = String(hash.dropFirst())
            let decoded = (try? JSObject.global.decodeURIComponent.function?.throws.callAsFunction(fragment).string) ?? fragment
            if !self.isHistory, hash.count > 1,
               let target = document.getElementById?(decoded).object {
                _ = target.scrollIntoView?()
            } else { _ = JSObject.global.scrollTo?(position.0, position.1) }
            return .undefined
        })
    }
}
#endif
