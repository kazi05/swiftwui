// ChapterRegistry.swift — canonical chapter metadata. Used by the top-bar
// popovers and the section picker's "N of M" pagination.

import SwiftWUI

public struct ChapterInfo: Identifiable, Hashable, Sendable {
    public let id: String           // slug: "hello", "state", …
    public let number: Int          // 1...12
    public let title: String        // "Hello, SwiftWUI"
    public let path: String         // "/learn/hello"
    public let group: String        // "Essentials" | "Building UI" | "Production"

    public init(id: String, number: Int, title: String, path: String, group: String) {
        self.id = id
        self.number = number
        self.title = title
        self.path = path
        self.group = group
    }
}

public enum ChapterRegistry {
    public static let all: [ChapterInfo] = [
        .init(id: "hello",     number: 1,  title: "Hello, SwiftWUI",  path: "/learn/hello",     group: "Essentials"),
        .init(id: "state",     number: 2,  title: "State & Bindings", path: "/learn/state",     group: "Essentials"),
        .init(id: "modifiers", number: 3,  title: "Modifiers",        path: "/learn/modifiers", group: "Essentials"),

        .init(id: "lists",     number: 4,  title: "Lists & ForEach",  path: "/learn/lists",     group: "Building UI"),
        .init(id: "forms",     number: 5,  title: "Forms & Inputs",   path: "/learn/forms",     group: "Building UI"),
        .init(id: "routing",   number: 6,  title: "Routing & Guards", path: "/learn/routing",   group: "Building UI"),
        .init(id: "async",     number: 7,  title: "Async & Resources",path: "/learn/async",     group: "Building UI"),

        .init(id: "theming",   number: 8,  title: "Theming",          path: "/learn/theming",   group: "Production"),
        .init(id: "a11y",      number: 9,  title: "Accessibility",    path: "/learn/a11y",      group: "Production"),
        .init(id: "errors",    number: 10, title: "Error Handling",   path: "/learn/errors",    group: "Production"),
        .init(id: "ssr",       number: 11, title: "SSR & Hydration",  path: "/learn/ssr",       group: "Production"),
        .init(id: "pwa",       number: 12, title: "PWA",              path: "/learn/pwa",       group: "Production"),
    ]

    public static func chapter(forID id: String) -> ChapterInfo? {
        all.first { $0.id == id }
    }

    public static func chapter(forPath path: String) -> ChapterInfo? {
        all.first { $0.path == path }
    }

    public static func grouped() -> [(group: String, chapters: [ChapterInfo])] {
        let order = ["Essentials", "Building UI", "Production"]
        return order.map { g in (g, all.filter { $0.group == g }) }
    }
}
