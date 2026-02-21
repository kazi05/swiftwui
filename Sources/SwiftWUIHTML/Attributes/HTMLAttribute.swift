// HTMLAttribute.swift - Common HTML attribute types

import SwiftWUICore

/// Button type attribute values.
public enum ButtonType: String, Sendable {
    case button
    case submit
    case reset
}

/// Input type attribute values.
public enum InputType: String, Sendable {
    case text
    case password
    case email
    case number
    case checkbox
    case radio
    case date
    case time
    case file
    case hidden
    case range
    case color
    case search
    case tel
    case url
}

/// Form method attribute values.
public enum FormMethod: String, Sendable {
    case get
    case post
}

/// Anchor/form target attribute values.
public enum Target: String, Sendable {
    case _self
    case _blank
    case _parent
    case _top

    /// The raw HTML attribute value.
    public var htmlValue: String {
        switch self {
        case ._self: return "_self"
        case ._blank: return "_blank"
        case ._parent: return "_parent"
        case ._top: return "_top"
        }
    }
}

/// Autocomplete attribute values.
public enum AutocompleteType: String, Sendable {
    case on
    case off
    case name
    case email
    case username
    case newPassword = "new-password"
    case currentPassword = "current-password"
    case organizationTitle = "organization-title"
    case organization
    case streetAddress = "street-address"
    case country
    case countryName = "country-name"
    case postalCode = "postal-code"
    case language
    case tel
    case url
}
