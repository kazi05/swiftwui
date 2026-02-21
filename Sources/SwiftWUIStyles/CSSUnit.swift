// CSSUnit.swift - CSS measurement units

import SwiftWUICore

/// Type-safe CSS measurement units.
public enum CSSUnit: Sendable, Hashable, Equatable {
    case px(Double)
    case em(Double)
    case rem(Double)
    case percent(Double)
    case vw(Double)
    case vh(Double)
    case vmin(Double)
    case vmax(Double)
    case fr(Double)
    case auto
    case zero
    case inherit
    case initial
    case unset
    case maxContent
    case minContent
    case fitContent

    public var cssValue: String {
        switch self {
        case .px(let v): return "\(formatNumber(v))px"
        case .em(let v): return "\(formatNumber(v))em"
        case .rem(let v): return "\(formatNumber(v))rem"
        case .percent(let v): return "\(formatNumber(v))%"
        case .vw(let v): return "\(formatNumber(v))vw"
        case .vh(let v): return "\(formatNumber(v))vh"
        case .vmin(let v): return "\(formatNumber(v))vmin"
        case .vmax(let v): return "\(formatNumber(v))vmax"
        case .fr(let v): return "\(formatNumber(v))fr"
        case .auto: return "auto"
        case .zero: return "0"
        case .inherit: return "inherit"
        case .initial: return "initial"
        case .unset: return "unset"
        case .maxContent: return "max-content"
        case .minContent: return "min-content"
        case .fitContent: return "fit-content"
        }
    }

    private func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(value)
    }
}
