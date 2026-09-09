public enum VisibilityRoot: Hashable, Sendable {
    case viewport
    case ancestor(id: String)
}

public struct VisibilityMargin: Hashable, Sendable {
    public enum Value: Hashable, Sendable {
        case px(Double)
        case percent(Double)

        fileprivate var number: Double {
            switch self {
            case .px(let number), .percent(let number): return number
            }
        }

        fileprivate var css: String {
            switch self {
            case .px(let number): return cssNumber(number) + "px"
            case .percent(let number): return cssNumber(number) + "%"
            }
        }
    }

    public let top: Value
    public let right: Value
    public let bottom: Value
    public let left: Value

    public static let zero = Self()

    public init(top: Value = .px(0), right: Value = .px(0),
                bottom: Value = .px(0), left: Value = .px(0)) {
        precondition([top, right, bottom, left].allSatisfy { $0.number.isFinite },
                     "Visibility margins must be finite")
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    package var css: String {
        [top, right, bottom, left].map(\.css).joined(separator: " ")
    }
}

struct _VisibilityRequest {
    let root: VisibilityRoot
    let threshold: Double
    let margin: VisibilityMargin
    let action: (Bool) -> Void
}

enum _ResolvedVisibilityRoot: Equatable {
    case viewport
    case ancestor(NodeIdentity)
    case unavailable
}

struct _ResolvedVisibilityObservation: Equatable {
    let id: ListenerID
    let root: _ResolvedVisibilityRoot
    let threshold: Double
    let margin: VisibilityMargin
}

extension HTMLTag {
    public func visibilityRoot(id: String) -> Self {
        precondition(!id.isEmpty, "Visibility root name must not be empty")
        var copy = self
        copy._attributes.setVisibilityRoot(id)
        return copy
    }

    public func onVisibilityChange(threshold: Double = 0,
                                   root: VisibilityRoot,
                                   rootMargin: VisibilityMargin = .zero,
                                   _ action: @escaping (Bool) -> Void) -> Self {
        precondition(threshold.isFinite && (0...1).contains(threshold),
                     "Visibility threshold must be finite and in 0...1")
        if case .ancestor(let name) = root {
            precondition(!name.isEmpty, "Visibility root name must not be empty")
        }
        var copy = self
        copy._attributes.addVisibility(.init(root: root, threshold: threshold,
                                             margin: rootMargin, action: action))
        return copy
    }
}
