// Page.swift - Protocol for full HTML pages

import SwiftWUICore

/// Represents a complete HTML page with head configuration and body content.
/// Analogous to UIViewController in UIKit — manages a full page with metadata.
///
/// ```swift
/// struct HomePage: Page {
///     var title: String { "My App" }
///     var styleSheets: [StyleSheetRef] { [.file("styles.css")] }
///
///     var body: some Tag {
///         Div(class: "container") {
///             H1 { "Welcome" }
///         }
///     }
/// }
/// ```
public protocol Page {
    associatedtype Body: Tag

    /// The page title (shown in browser tab).
    var title: String { get }

    /// Meta tags for the page head.
    var meta: [MetaTag] { get }

    /// CSS stylesheets to include in the page.
    var styleSheets: [StyleSheetRef] { get }

    /// JavaScript files to include in the page.
    var scripts: [ScriptRef] { get }

    /// The page body content.
    @TagBuilder var body: Body { get }
}

// MARK: - Default Implementations

extension Page {
    public var title: String { "SwiftWUI App" }

    public var meta: [MetaTag] {
        [
            .charset("utf-8"),
            .viewport("width=device-width, initial-scale=1.0"),
        ]
    }

    public var styleSheets: [StyleSheetRef] { [] }
    public var scripts: [ScriptRef] { [] }
}
