/// Declared UI for the window between first paint and a live wasm runtime.
///
/// The content is rendered ONCE per document, natively, at build time — see
/// `Runtime._renderBootShell`. It therefore has no `@State`, no event handlers
/// and no `.task`; it does have the document's locale, so `L10n` works.
public struct BootUI {
    enum Kind {
        case none
        case inherit
        case overlay(AnyTag, Int)     // content, delay in whole milliseconds
    }
    let kind: Kind
    private init(_ kind: Kind) { self.kind = kind }

    /// No boot UI at this level. On a `Page`, also suppresses the app's.
    public static var none: BootUI { .init(.none) }

    /// Take the app's declaration. The default for every `Page`; on `App`
    /// itself it is read as `.none`.
    public static var inherit: BootUI { .init(.inherit) }

    /// Content shown once `after` has elapsed and boot is still running.
    /// The delay exists so a cached wasm — which instantiates in tens of
    /// milliseconds — never flashes a loader.
    public static func overlay(after: CSSDuration = .ms(300),
                               @TagBuilder content: () -> some Tag) -> BootUI {
        .init(.overlay(AnyTag(content()), Int(after.milliseconds.rounded())))
    }

    // MARK: SPI — read by SwiftWUIStatic (to render) and the CLI (to stamp).
    public var _content: AnyTag? {
        if case .overlay(let tag, _) = kind { return tag }
        return nil
    }
    public var _delayMS: Int {
        if case .overlay(_, let ms) = kind { return ms }
        return 300
    }
    public var _isInherit: Bool { if case .inherit = kind { return true }; return false }
    public var _isNone: Bool { if case .none = kind { return true }; return false }
}
