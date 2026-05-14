// PreviewKind.swift — how a ScrollyTeller step's preview pane is filled.

import SwiftWUI

public enum PreviewKind {
    case live(AnyTag)
    case screenshot(String)    // path relative to /snapshots/
}
