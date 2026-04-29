// TypedInputs.swift - SwiftUI-style typed form inputs.
//
// Thin wrappers over the raw HTML `Input`, `Textarea`, `Select` tags
// that take a `Binding` and read/write through it on the appropriate
// DOM event. The `body: some Tag` shape makes them composable inside
// any form layout.

import SwiftWUICore
import SwiftWUIState

/// Single-line text input bound to a `Binding<String>`. Uses the
/// `oninput` DOM event so the binding updates on every keystroke.
public struct TextField: Tag {
    public let label: String
    public let text: Binding<String>
    public let placeholder: String?
    public let kind: InputType

    public init(
        _ label: String,
        text: Binding<String>,
        placeholder: String? = nil,
        kind: InputType = .text
    ) {
        self.label = label
        self.text = text
        self.placeholder = placeholder
        self.kind = kind
    }

    public var body: some Tag {
        let bound = text
        return Input(
            type: kind,
            placeholder: placeholder,
            value: bound.wrappedValue,
            oninput: {
                if let new = InputEventContext.currentValue {
                    bound.wrappedValue = new
                }
            }
        )
        .accessibilityLabel(label)
    }
}

/// Password input. Identical to `TextField` save for `type=password`.
public struct SecureField: Tag {
    public let label: String
    public let text: Binding<String>
    public let placeholder: String?

    public init(_ label: String, text: Binding<String>, placeholder: String? = nil) {
        self.label = label
        self.text = text
        self.placeholder = placeholder
    }

    public var body: some Tag {
        let bound = text
        return Input(
            type: .password,
            placeholder: placeholder,
            value: bound.wrappedValue,
            oninput: {
                if let new = InputEventContext.currentValue {
                    bound.wrappedValue = new
                }
            }
        )
        .accessibilityLabel(label)
    }
}

/// Boolean toggle, rendered as `<input type="checkbox">`. Reads the
/// checkbox's truthiness from the input event's value coercion (HTML
/// checkboxes report `"on"` when checked).
public struct Toggle: Tag {
    public let label: String
    public let isOn: Binding<Bool>

    public init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self.isOn = isOn
    }

    public var body: some Tag {
        let bound = isOn
        var input = Input(
            type: .checkbox,
            oninput: {
                bound.wrappedValue.toggle()
            }
        )
        if bound.wrappedValue {
            input.attributes["checked"] = "true"
        }
        return input.accessibilityLabel(label).accessibilityRole(.checkbox)
    }
}

/// Numeric slider bound to a `Binding<Double>`. Renders as
/// `<input type="range">`. The browser coerces the typed value through
/// `Double(_:)`; out-of-range values fall back to the previous value.
public struct Slider: Tag {
    public let label: String
    public let value: Binding<Double>
    public let range: ClosedRange<Double>
    public let step: Double?

    public init(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...1,
        step: Double? = nil
    ) {
        self.label = label
        self.value = value
        self.range = range
        self.step = step
    }

    public var body: some Tag {
        let bound = value
        var input = Input(
            type: .range,
            value: String(bound.wrappedValue),
            oninput: {
                if let s = InputEventContext.currentValue, let d = Double(s) {
                    bound.wrappedValue = d
                }
            }
        )
        input.attributes["min"] = String(range.lowerBound)
        input.attributes["max"] = String(range.upperBound)
        if let step { input.attributes["step"] = String(step) }
        return input.accessibilityLabel(label).accessibilityRole(.slider)
    }
}

/// Numeric stepper bound to a `Binding<Int>`. Renders as
/// `<input type="number">` with explicit `step` and optional bounds.
public struct Stepper: Tag {
    public let label: String
    public let value: Binding<Int>
    public let range: ClosedRange<Int>?
    public let step: Int

    public init(
        _ label: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>? = nil,
        step: Int = 1
    ) {
        self.label = label
        self.value = value
        self.range = range
        self.step = step
    }

    public var body: some Tag {
        let bound = value
        var input = Input(
            type: .number,
            value: String(bound.wrappedValue),
            oninput: {
                if let s = InputEventContext.currentValue, let i = Int(s) {
                    bound.wrappedValue = i
                }
            }
        )
        input.attributes["step"] = String(step)
        if let range {
            input.attributes["min"] = String(range.lowerBound)
            input.attributes["max"] = String(range.upperBound)
        }
        return input.accessibilityLabel(label)
    }
}

/// Decimal numeric input bound to a `Binding<Double>`. Identical in
/// shape to `Stepper` but defaults to no step constraint, so the user
/// can type arbitrary precision values.
public struct NumberField: Tag {
    public let label: String
    public let value: Binding<Double>
    public let placeholder: String?

    public init(_ label: String, value: Binding<Double>, placeholder: String? = nil) {
        self.label = label
        self.value = value
        self.placeholder = placeholder
    }

    public var body: some Tag {
        let bound = value
        return Input(
            type: .number,
            placeholder: placeholder,
            value: String(bound.wrappedValue),
            oninput: {
                if let s = InputEventContext.currentValue, let d = Double(s) {
                    bound.wrappedValue = d
                }
            }
        )
        .accessibilityLabel(label)
    }
}

/// Color picker bound to a hex string `Binding<String>`. Renders as
/// `<input type="color">`. The browser only accepts seven-character
/// `#RRGGBB` values, so app code is responsible for normalising any
/// input it stores in the binding to that format.
public struct ColorPicker: Tag {
    public let label: String
    public let hex: Binding<String>

    public init(_ label: String, hex: Binding<String>) {
        self.label = label
        self.hex = hex
    }

    public var body: some Tag {
        let bound = hex
        return Input(
            type: .color,
            value: bound.wrappedValue,
            oninput: {
                if let s = InputEventContext.currentValue {
                    bound.wrappedValue = s
                }
            }
        )
        .accessibilityLabel(label)
    }
}

/// Date picker bound to an ISO-8601 date string (`yyyy-MM-dd`). Storing
/// the value as `String` rather than `Date` avoids a Foundation
/// dependency in `SwiftWUIHTML`; apps that need Date parsing can do it
/// at the boundary.
public struct DatePicker: Tag {
    public let label: String
    public let dateString: Binding<String>

    public init(_ label: String, dateString: Binding<String>) {
        self.label = label
        self.dateString = dateString
    }

    public var body: some Tag {
        let bound = dateString
        return Input(
            type: .date,
            value: bound.wrappedValue,
            oninput: {
                if let s = InputEventContext.currentValue {
                    bound.wrappedValue = s
                }
            }
        )
        .accessibilityLabel(label)
    }
}

/// Single-select picker bound to a `Binding<Selection>`. The
/// `Selection` type must be `LosslessStringConvertible` because HTML
/// `<select>` reports its value as a string; the binding round-trips
/// through `String.init(describing:)` and `Selection.init(_:)` to
/// preserve typing.
///
/// ```swift
/// enum Country: String, LosslessStringConvertible {
///     case us, gb, jp, ru
///     var description: String { rawValue }
///     init?(_ s: String) { self.init(rawValue: s) }
/// }
///
/// @State var country: Country = .us
///
/// Picker("Country", selection: $country) {
///     for c in [Country.us, .gb, .jp, .ru] {
///         Option(value: c.rawValue) { Text(c.rawValue.uppercased()) }
///     }
/// }
/// ```
public struct Picker<Selection: LosslessStringConvertible>: Tag {
    public let label: String
    public let selection: Binding<Selection>
    public let optionsBuilder: () -> AnyTag

    public init(
        _ label: String,
        selection: Binding<Selection>,
        @TagBuilder content: @escaping () -> some Tag
    ) {
        self.label = label
        self.selection = selection
        self.optionsBuilder = { AnyTag(content()) }
    }

    public var body: some Tag {
        let bound = selection
        // Render `<select>` with `onchange` hooked into InputEventContext.
        // The DOMRenderer fires `change` events with the same value-extraction
        // path as `input`, so we reuse `currentValue`.
        let optsClosure = optionsBuilder
        return Select(onchange: {
            guard let raw = InputEventContext.currentValue,
                  let parsed = Selection(raw) else { return }
            bound.wrappedValue = parsed
        }) {
            optsClosure()
        }
        .accessibilityLabel(label)
    }
}

extension Picker {
    public init(
        _ label: String,
        selection: Binding<Selection>,
        content: AnyTag
    ) {
        self.label = label
        self.selection = selection
        self.optionsBuilder = { content }
    }
}
