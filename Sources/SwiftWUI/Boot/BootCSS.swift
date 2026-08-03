/// The framework's two boot rules, as a literal.
///
/// NOT registered through the app's rule registry, and the element that carries
/// them must NOT be marked `data-swiftwui`: `DOMBackend.setStylesheet` adopts
/// `style[data-swiftwui]` as the managed stylesheet and replaces its whole
/// `textContent` on the first render pass, which would delete these rules.
///
/// `!important` is mandatory. Every typed style modifier emits an
/// element-attached declaration (`HTMLRenderer` writes `el.style.cssText`), and
/// those outrank any selector-matched rule — an overlay authored as
/// `.position(.fixed).display(.flex)` would otherwise never hide.
public enum BootCSS {
    public static let text = """
    html:not([data-swui-boot]) [data-swui-boot-ui]{display:none!important}
    html[data-swui-boot] [data-swui-boot-veil]{display:none!important}
    """
}
