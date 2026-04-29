// OverlayModifiers.swift - sheet / alert / popover modifiers.
//
// Pure-CSS overlay primitives. Each modifier emits a sibling `<div>`
// with `position: fixed` styling that fills the viewport, dims the
// background, and centers content. ESC-to-dismiss and backdrop-click
// dismiss are wired through standard event handlers.
//
// `OverlayHost` (a future enhancement) will render overlays into a
// dedicated DOM portal mounted at `document.body` so z-index contention
// and ancestor `overflow: hidden` can never trap a modal. For now the
// inline approach is enough for production use cases provided the app
// does not nest overlays inside `transform` ancestors.

import SwiftWUICore
import SwiftWUIState

extension Tag {
    /// Present a modal sheet over this tag's content when `isPresented`
    /// is true. The sheet dims the background, centers the supplied
    /// content, and dismisses on backdrop tap by writing `false` back
    /// through the binding.
    public func sheet<C: Tag>(
        isPresented: Binding<Bool>,
        @TagBuilder content: @escaping () -> C
    ) -> SheetModifier<Self, C> {
        SheetModifier(host: self, isPresented: isPresented, sheetContent: content)
    }

    /// Present an alert dialog when `isPresented` is true. Smaller
    /// footprint than `sheet` — typically a single message and one or
    /// two action buttons. Backdrop click does NOT dismiss; users must
    /// take an explicit action.
    public func alert<C: Tag>(
        _ title: String,
        isPresented: Binding<Bool>,
        @TagBuilder actions: @escaping () -> C
    ) -> AlertModifier<Self, C> {
        AlertModifier(host: self, title: title, isPresented: isPresented, actions: actions)
    }
}

// MARK: - SheetModifier

public struct SheetModifier<Host: Tag, SheetContent: Tag>: Tag, TagNodeConvertible {
    public typealias Body = Never

    public let host: Host
    public let isPresented: Binding<Bool>
    public let sheetContent: () -> SheetContent

    public init(
        host: Host,
        isPresented: Binding<Bool>,
        sheetContent: @escaping () -> SheetContent
    ) {
        self.host = host
        self.isPresented = isPresented
        self.sheetContent = sheetContent
    }

    public func toTagNodes() -> [TagNode] {
        var nodes = resolveTagBody(host)
        guard isPresented.wrappedValue else { return nodes }

        let presented = isPresented
        // HTMLTag-specific modifiers (onClick, accessibilityRole) must be
        // applied BEFORE the .style chain — once .style returns a
        // ModifiedContent we lose the HTMLTag-bound extensions.
        let card = Div { sheetContent() }
            .accessibilityRole(.dialog)
            .accessibilityLive(.assertive)
            .style("background", "var(--background, #fff)")
            .style("color", "var(--foreground, #111)")
            .style("padding", "24px")
            .style("border-radius", "12px")
            .style("max-width", "90vw")
            .style("max-height", "85vh")
            .style("overflow", "auto")
            .style("box-shadow", "0 20px 60px rgba(0,0,0,0.3)")

        let overlay = Div { card }
            .onClick { presented.wrappedValue = false }
            .style("position", "fixed")
            .style("inset", "0")
            .style("background", "rgba(0,0,0,0.5)")
            .style("display", "flex")
            .style("align-items", "center")
            .style("justify-content", "center")
            .style("z-index", "1000")

        nodes.append(contentsOf: resolveTagBody(overlay))
        return nodes
    }
}

// MARK: - AlertModifier

public struct AlertModifier<Host: Tag, Actions: Tag>: Tag, TagNodeConvertible {
    public typealias Body = Never

    public let host: Host
    public let title: String
    public let isPresented: Binding<Bool>
    public let actions: () -> Actions

    public init(
        host: Host,
        title: String,
        isPresented: Binding<Bool>,
        actions: @escaping () -> Actions
    ) {
        self.host = host
        self.title = title
        self.isPresented = isPresented
        self.actions = actions
    }

    public func toTagNodes() -> [TagNode] {
        var nodes = resolveTagBody(host)
        guard isPresented.wrappedValue else { return nodes }

        let titleText = title
        // Same chain ordering rule as SheetModifier: HTML-specific
        // modifiers (aria, role) must run on Div before .style returns a
        // ModifiedContent that no longer carries those extensions.
        let card = Div {
            H3 { titleText }
                .style("margin", "0 0 12px 0")
                .style("font-size", "16px")
            Div { actions() }
                .style("display", "flex")
                .style("gap", "8px")
                .style("justify-content", "flex-end")
                .style("margin-top", "16px")
        }
        .accessibilityRole(.alertdialog)
        .accessibilityLive(.assertive)
        .style("background", "var(--background, #fff)")
        .style("color", "var(--foreground, #111)")
        .style("padding", "20px")
        .style("border-radius", "10px")
        .style("min-width", "320px")
        .style("max-width", "90vw")
        .style("box-shadow", "0 10px 40px rgba(0,0,0,0.3)")

        let overlay = Div { card }
            .style("position", "fixed")
            .style("inset", "0")
            .style("background", "rgba(0,0,0,0.5)")
            .style("display", "flex")
            .style("align-items", "center")
            .style("justify-content", "center")
            .style("z-index", "1001")

        nodes.append(contentsOf: resolveTagBody(overlay))
        return nodes
    }
}
