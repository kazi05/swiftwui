// ShowcaseTheme.swift — Apple Tutorials–fidelity token set.
// Dark-default (matches cited reference). Light variant designed to feel
// like Apple's lighter docs sections. Manual override via
// <html data-theme="light|dark"> beats the @media default.

import SwiftWUI

public enum ShowcaseTheme {
    public static let css: String = """
    :root {
      --swui-bg: #000000;
      --swui-surface: #1c1c1e;
      --swui-surface-2: #2c2c2e;
      --swui-fg: #f5f5f7;
      --swui-fg-2: #98989d;
      --swui-fg-3: #6e6e73;
      --swui-border: rgba(255, 255, 255, 0.10);
      --swui-border-strong: rgba(255, 255, 255, 0.22);
      --swui-accent: #5ac8b0;
      --swui-accent-strong: #66e1c1;
      --swui-code-bg: #1d1d1f;
      --swui-code-line-hl: rgba(255, 255, 255, 0.06);
      --syntax-keyword: #fc5fa3;
      --syntax-type: #5dd8ff;
      --syntax-string: #fc6a5d;
      --syntax-number: #d0bf69;
      --syntax-comment: #7f8c98;
      --font-display: -apple-system, "SF Pro Display", "Segoe UI", sans-serif;
      --font-text: -apple-system, "SF Pro Text", "Segoe UI", sans-serif;
      --font-mono: "SF Mono", "Menlo", "Cascadia Code", monospace;
      --radius-sm: 6px;
      --radius-md: 10px;
      --radius-lg: 16px;
      --radius-pill: 999px;
    }

    @media (prefers-color-scheme: light) {
      :root:not([data-theme="dark"]) {
        --swui-bg: #ffffff;
        --swui-surface: #f5f5f7;
        --swui-surface-2: #ebebf0;
        --swui-fg: #1d1d1f;
        --swui-fg-2: #6e6e73;
        --swui-fg-3: #aeaeb2;
        --swui-border: rgba(0, 0, 0, 0.10);
        --swui-border-strong: rgba(0, 0, 0, 0.18);
        --swui-accent: #0a84ff;
        --swui-accent-strong: #007aff;
        --swui-code-bg: #f5f5f7;
        --swui-code-line-hl: rgba(0, 0, 0, 0.04);
        --syntax-keyword: #ad3da4;
        --syntax-type: #0f68a2;
        --syntax-string: #c41a16;
        --syntax-number: #272ad8;
        --syntax-comment: #5d6c79;
      }
    }

    :root[data-theme="light"] {
      --swui-bg: #ffffff;
      --swui-surface: #f5f5f7;
      --swui-surface-2: #ebebf0;
      --swui-fg: #1d1d1f;
      --swui-fg-2: #6e6e73;
      --swui-fg-3: #aeaeb2;
      --swui-border: rgba(0, 0, 0, 0.10);
      --swui-border-strong: rgba(0, 0, 0, 0.18);
      --swui-accent: #0a84ff;
      --swui-accent-strong: #007aff;
      --swui-code-bg: #f5f5f7;
      --swui-code-line-hl: rgba(0, 0, 0, 0.04);
      --syntax-keyword: #ad3da4;
      --syntax-type: #0f68a2;
      --syntax-string: #c41a16;
      --syntax-number: #272ad8;
      --syntax-comment: #5d6c79;
    }

    :root[data-theme="dark"] {
      --swui-bg: #000000;
      --swui-surface: #1c1c1e;
      --swui-surface-2: #2c2c2e;
      --swui-fg: #f5f5f7;
      --swui-fg-2: #98989d;
      --swui-fg-3: #6e6e73;
      --swui-border: rgba(255, 255, 255, 0.10);
      --swui-border-strong: rgba(255, 255, 255, 0.22);
      --swui-accent: #5ac8b0;
      --swui-accent-strong: #66e1c1;
      --swui-code-bg: #1d1d1f;
      --swui-code-line-hl: rgba(255, 255, 255, 0.06);
      --syntax-keyword: #fc5fa3;
      --syntax-type: #5dd8ff;
      --syntax-string: #fc6a5d;
      --syntax-number: #d0bf69;
      --syntax-comment: #7f8c98;
    }

    html, body {
      background: var(--swui-bg);
      color: var(--swui-fg);
      font-family: var(--font-text);
      -webkit-font-smoothing: antialiased;
      margin: 0;
      padding: 0;
    }

    /* Keyboard focus — WCAG 2.4.7. Override the default platform outline so
       the accent stays visible against any surface (the framework never sets
       its own focus-visible rule). */
    a:focus-visible, button:focus-visible, summary:focus-visible,
    input:focus-visible, select:focus-visible, textarea:focus-visible,
    [tabindex]:focus-visible {
      outline: 2px solid var(--swui-accent);
      outline-offset: 2px;
      border-radius: inherit;
    }

    /* Active-step accent + preview crossfade */
    .swui-step-card {
      border-left: 3px solid transparent;
      padding-left: 12px;
      transition: border-left-color .2s ease, opacity .2s ease;
      opacity: 0.5;
    }
    .swui-step-card[data-active="true"] {
      border-left-color: var(--swui-accent);
      opacity: 1;
    }

    .swui-preview-pane {
      transition: opacity .2s ease;
    }
    .swui-preview-pane[data-preview-fading="true"] {
      opacity: 0;
    }

    /* Highlighted code line (paired with LineNumberedCode's data-line-hl) */
    .swui-code-line-hl {
      background: var(--swui-code-line-hl);
    }
    """
}
