/// A rule captured on an element before the registry is reachable; resolved
/// to a swui-<hash> class in resolveElement.
public struct PendingStyleRule {
    let pseudo: String?
    let media: String?
    let declarations: [StyleDeclaration]
}

public struct _AttributeBag {
    private(set) var pairs: [(name: String, value: String)] = []
    private(set) var properties: [(name: String, value: PropertyValue)] = []
    private(set) var handlers: [(event: EventName, action: (Any?) -> Void)] = []
    private(set) var observers: [(kind: ObserverKind, action: (Any?) -> Void)] = []
    private(set) var styles: [StyleDeclaration] = []
    private(set) var pendingRules: [PendingStyleRule] = []
    mutating func addPendingRule(_ r: PendingStyleRule) { pendingRules.append(r) }

    init(id: String? = nil, class classes: String? = nil) {
        if let id { set("id", id) }
        if let classes { set("class", classes) }
    }

    mutating func set(_ name: String, _ value: String?) {
        guard let value else { return }
        guard Self.isValidName(name) else {
            assertionFailure("invalid attribute name: \(name)")   // debug trap, drop in release
            return
        }
        pairs.append((name, value))
    }

    mutating func setProperty(_ name: String, _ value: PropertyValue) { properties.append((name, value)) }
    func flattenedProperties() -> [String: PropertyValue] {
        var out: [String: PropertyValue] = [:]
        for (name, value) in properties { out[name] = value }     // last-wins
        return out
    }

    mutating func appendClasses(_ names: [String]) {
        for n in names { pairs.append(("class", n)) }
    }

    mutating func addHandler(_ event: EventName, _ action: @escaping () -> Void) {
        handlers.append((event, { _ in action() }))
    }
    mutating func addHandler<P>(_ event: EventName, payload: P.Type, _ action: @escaping (P) -> Void) {
        handlers.append((event, { any in
            guard let p = any as? P else {
                assertionFailure("payload type mismatch for \(event.rawValue): expected \(P.self), got \(String(describing: any))")
                return                                            // release: drop (spec §11)
            }
            action(p)
        }))
    }
    mutating func addRawHandler(_ event: EventName, _ action: @escaping (Any?) -> Void) {
        handlers.append((event, action))
    }

    mutating func addObserver(_ kind: ObserverKind, _ action: @escaping (Any?) -> Void) {
        observers.append((kind, action))
    }

    mutating func addStyle(_ d: StyleDeclaration) { styles.append(d) }

    /// Last-wins per name, except `class` accumulates space-joined (spec decision 5).
    func flattened() -> [String: String] {
        var out: [String: String] = [:]
        for (name, value) in pairs {
            if name == "class", let existing = out["class"], !existing.isEmpty {
                out["class"] = existing + " " + value
            } else {
                out[name] = value
            }
        }
        if !styles.isEmpty {
            out["style"] = Self.mergeStyleText(base: out["style"], styles)
        }
        return out
    }

    /// "prop: value; …" — call order, last-wins per property, base text first.
    static func mergeStyleText(base: String?, _ styles: [StyleDeclaration]) -> String {
        var order: [String] = []
        var valueFor: [String: String] = [:]
        for d in styles {
            if valueFor[d.property] == nil { order.append(d.property) }
            valueFor[d.property] = d.value
        }
        let text = order.map { "\($0): \(valueFor[$0]!)" }.joined(separator: "; ")
        if let base, !base.isEmpty { return base + "; " + text }
        return text
    }

    /// [a-zA-Z_:][a-zA-Z0-9_.:-]* — spec §11 point 3. Foundation-free.
    static func isValidName(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first else { return false }
        func isAlpha(_ c: Unicode.Scalar) -> Bool {
            ("a"..."z").contains(c) || ("A"..."Z").contains(c)
        }
        guard isAlpha(first) || first == "_" || first == ":" else { return false }
        for c in name.unicodeScalars.dropFirst() {
            guard isAlpha(c) || ("0"..."9").contains(c)
                || c == "_" || c == "." || c == ":" || c == "-" else { return false }
        }
        return true
    }
}
