// SSR.swift - Server-side rendering helpers.
//
// SwiftWUI's SSR pipeline emits a complete HTML document for a given
// route, ready for a Vapor / Hummingbird / WAI handler to ship to the
// browser. Hydration on the client (re-binding listeners over the
// pre-rendered DOM rather than re-creating it) is a Phase 4 work
// item — for now the SSR'd page bootstraps the WASM client which
// performs a full render that overwrites the server output. Apps see
// faster first paint (server HTML reaches the user immediately) at
// the cost of a brief flash when the client takes over.
//
// Use:
// ```swift
// let html = app.renderHTMLDocument(
//     title: "My Page",
//     wasmJSURL: "/Counter.js"
// )
// ```

import SwiftWUICore

/// Configuration for the HTML document emitted by `renderHTMLDocument`.
public struct SSRDocumentOptions: Sendable {
    /// `<title>` value.
    public var title: String
    /// Optional `<meta name="description" content="…">`.
    public var description: String?
    /// Stylesheet URLs / inline CSS to include in `<head>`. Inline CSS
    /// is wrapped in a `<style>` element; URLs in `<link>` tags.
    public var stylesheets: [SSRStylesheet]
    /// URL of the bootstrap JS module that loads the SwiftWUI WASM
    /// runtime. Typically `/Counter.js` or whatever PackageToJS emits.
    /// Pass `nil` for fully-static pages with no client behaviour.
    public var wasmJSURL: String?
    /// Pre-rendered initial state to embed as JSON. The client reads
    /// this from `window.__swiftwui_state` during hydration. Future
    /// phases will populate it automatically; today apps that need it
    /// must encode their own.
    public var initialState: String?
    /// Theme CSS to inline into `<head>` (typically the output of
    /// `ThemeCSS.definitions(light:dark:)`).
    public var themeCSS: String?

    public init(
        title: String,
        description: String? = nil,
        stylesheets: [SSRStylesheet] = [],
        wasmJSURL: String? = nil,
        initialState: String? = nil,
        themeCSS: String? = nil
    ) {
        self.title = title
        self.description = description
        self.stylesheets = stylesheets
        self.wasmJSURL = wasmJSURL
        self.initialState = initialState
        self.themeCSS = themeCSS
    }
}

public enum SSRStylesheet: Sendable {
    case url(String)
    case inline(String)
}

extension Application {
    /// Render the application's currently-matched route as a complete
    /// HTML document string. The document includes:
    ///   * a `<title>` and optional `<meta description>`
    ///   * any supplied `<link rel=stylesheet>` / inline CSS
    ///   * inline theme CSS from `ThemeCSS.definitions(...)` if provided
    ///   * a `<div id="app">` containing the SSR'd Tag tree
    ///   * an optional `<script type="module" src="…">` that loads the
    ///     WASM bootstrap so the client can take over after first paint
    ///   * an optional `<script id="__swiftwui_state">` JSON blob for
    ///     future hydration to read
    ///
    /// Hydration is not implemented yet — the SSR document is fully
    /// re-rendered when the WASM client mounts. Apps using this for
    /// FCP improvements should be aware that interactivity is still
    /// gated on the WASM bundle finishing its `instantiateStreaming`
    /// pass.
    public func renderHTMLDocument(_ options: SSRDocumentOptions) -> String {
        let renderer = StaticRenderer()
        let bodyHTML = renderToString(in: renderer)
        return Self.assembleDocument(bodyHTML: bodyHTML, options: options)
    }

    static func assembleDocument(bodyHTML: String, options: SSRDocumentOptions) -> String {
        var html = "<!DOCTYPE html>\n<html>\n<head>\n"
        html += "  <meta charset=\"utf-8\">\n"
        html += "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"

        if let desc = options.description {
            html += "  <meta name=\"description\" content=\"\(HTMLEscaping.text(desc))\">\n"
        }
        html += "  <title>\(HTMLEscaping.text(options.title))</title>\n"

        if let theme = options.themeCSS {
            html += "  <style>\(HTMLEscaping.rawTextElement(theme))</style>\n"
        }
        for sheet in options.stylesheets {
            switch sheet {
            case .url(let u):
                html += "  <link rel=\"stylesheet\" href=\"\(HTMLEscaping.text(u))\">\n"
            case .inline(let css):
                html += "  <style>\(HTMLEscaping.rawTextElement(css))</style>\n"
            }
        }

        html += "</head>\n<body>\n"
        html += "  <div id=\"app\">\n\(bodyHTML)\n  </div>\n"

        if let state = options.initialState {
            html += "  <script id=\"__swiftwui_state\" type=\"application/json\">\(HTMLEscaping.scriptJSON(state))</script>\n"
        }
        if let jsURL = options.wasmJSURL {
            html += "  <script type=\"module\">\n"
            html += "    import { init } from \"\(HTMLEscaping.text(jsURL))\";\n"
            html += "    init();\n"
            html += "  </script>\n"
        }

        html += "</body>\n</html>\n"
        return html
    }
}
