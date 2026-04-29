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
