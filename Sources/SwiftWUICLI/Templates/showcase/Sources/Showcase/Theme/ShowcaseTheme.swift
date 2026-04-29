// {{PROJECT_NAME}}Theme.swift — light/dark token sets for the SwiftWUI {{project_name}}.

import SwiftWUIStyles

public struct {{PROJECT_NAME}}Theme: Theme {
    public let tokens: [String: String]

    private init(tokens: [String: String]) { self.tokens = tokens }

    public static let requiredTokens: [String] = [
        "swui-bg", "swui-surface", "swui-surface-2",
        "swui-fg", "swui-fg-2", "swui-fg-3",
        "swui-border", "swui-border-strong",
        "swui-accent", "swui-accent-bg",
        "swui-code-bg", "swui-code-fg",
        "space-1", "space-2", "space-3", "space-4",
        "space-5", "space-6", "space-7", "space-8",
        "radius-sm", "radius-md", "radius-lg",
        "font-display", "font-text", "font-mono",
    ]

    public static let light = {{PROJECT_NAME}}Theme(tokens: [
        "swui-bg":             "#fbfbfd",
        "swui-surface":        "#ffffff",
        "swui-surface-2":      "#f5f5f7",
        "swui-fg":             "#1d1d1f",
        "swui-fg-2":           "#424245",
        "swui-fg-3":           "#6e6e73",
        "swui-border":         "#e8e8ed",
        "swui-border-strong":  "#d2d2d7",
        "swui-accent":         "#ff9500",
        "swui-accent-bg":      "#fff5e8",
        "swui-code-bg":        "#1d1d1f",
        "swui-code-fg":        "#f5f5f7",
        "space-1": "4px",  "space-2": "8px",  "space-3": "12px", "space-4": "16px",
        "space-5": "24px", "space-6": "32px", "space-7": "48px", "space-8": "64px",
        "radius-sm": "8px", "radius-md": "12px", "radius-lg": "18px",
        "font-display": "-apple-system, \"SF Pro Display\", system-ui, \"Segoe UI\", Roboto, sans-serif",
        "font-text":    "-apple-system, \"SF Pro Text\", system-ui, \"Segoe UI\", Roboto, sans-serif",
        "font-mono":    "ui-monospace, \"SF Mono\", \"Cascadia Code\", Menlo, Consolas, monospace",
    ])

    public static let dark = {{PROJECT_NAME}}Theme(tokens: [
        "swui-bg":             "#000000",
        "swui-surface":        "#1d1d1f",
        "swui-surface-2":      "#2c2c2e",
        "swui-fg":             "#f5f5f7",
        "swui-fg-2":           "#a1a1a6",
        "swui-fg-3":           "#86868b",
        "swui-border":         "#3a3a3c",
        "swui-border-strong":  "#48484a",
        "swui-accent":         "#ff9f0a",
        "swui-accent-bg":      "#3a2410",
        "swui-code-bg":        "#0d0d0f",
        "swui-code-fg":        "#f5f5f7",
        "space-1": "4px",  "space-2": "8px",  "space-3": "12px", "space-4": "16px",
        "space-5": "24px", "space-6": "32px", "space-7": "48px", "space-8": "64px",
        "radius-sm": "8px", "radius-md": "12px", "radius-lg": "18px",
        "font-display": "-apple-system, \"SF Pro Display\", system-ui, \"Segoe UI\", Roboto, sans-serif",
        "font-text":    "-apple-system, \"SF Pro Text\", system-ui, \"Segoe UI\", Roboto, sans-serif",
        "font-mono":    "ui-monospace, \"SF Mono\", \"Cascadia Code\", Menlo, Consolas, monospace",
    ])
}
