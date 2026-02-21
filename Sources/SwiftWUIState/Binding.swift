// Binding.swift - Two-way data binding

/// A two-way binding to a mutable value.
///
/// Use `Binding` to create a connection between a stored value and a tag that
/// displays and mutates that value. For example, you can create a binding
/// between a `@State` property and a form input tag.
///
/// You typically obtain a binding from a `@State` property's projected value (`$`):
/// ```swift
/// @State var name = ""
/// // $name is a Binding<String>
/// ```
@propertyWrapper
public struct Binding<Value> {
    private let getter: () -> Value
    private let setter: (Value) -> Void

    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getter = get
        self.setter = set
    }

    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }

    public var projectedValue: Binding<Value> { self }

    /// Creates a new binding by transforming the value with the given closures.
    public func map<T>(get: @escaping (Value) -> T, set: @escaping (T) -> Value) -> Binding<T> {
        Binding<T>(
            get: { get(self.getter()) },
            set: { self.setter(set($0)) }
        )
    }
}

// MARK: - Constant Binding

extension Binding {
    /// Creates a binding with an immutable value.
    ///
    /// Useful for previews and testing where you don't need actual mutation.
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }
}
