// FormState.swift - Schema-driven, observable form controller.
//
// SwiftWUI form pattern: an `@Observable` `FormState<Schema>` owns the
// values, errors, and submission state for a form. Inputs bind to
// individual fields via `state.bind(\.field)`, and the submit handler
// flips `isSubmitting` while it awaits the network call. Mirrors
// React-Hook-Form / Tanstack Form ergonomics in Swift.

import Observation
import SwiftWUICore

/// Observable controller for a single form. `Schema` is whatever
/// struct the app uses to model the form's values — typically a
/// `Codable` struct that mirrors the API request body.
///
/// ```swift
/// struct SignupForm { var email = ""; var password = "" }
///
/// @State var form = FormState(values: SignupForm())
///
/// TextField("Email", text: form.bind(\.email))
///     .formError(form.error(for: \.email))
/// Button("Sign up") {
///     Task { await form.submit { try await api.signUp(form.values) } }
/// }
/// .disabled(form.isSubmitting)
/// ```
@Observable
public final class FormState<Schema>: @unchecked Sendable {
    /// The current form values. Inputs read and write through here via
    /// `bind(_:)`.
    public var values: Schema

    /// Field-level validation errors keyed by an opaque field name.
    /// `bind(_:)` produces names from the keyPath; consumers can also
    /// write arbitrary keys for cross-field errors ("server" / "form").
    public var errors: [String: String] = [:]

    /// Submission flag. `true` while `submit(_:)` is awaiting; flips
    /// back to `false` when the operation completes (success or error).
    public var isSubmitting: Bool = false

    /// Top-level error captured by `submit(_:)` when its operation
    /// throws something other than per-field validation. Surface in UI
    /// via a banner above the form.
    public var submitError: (any Error)?

    public init(values: Schema) {
        self.values = values
    }

    /// Produce a two-way binding to a stored field. The keyPath does
    /// double duty as the binding source AND as the error map key, so
    /// `formError(for:)` can show validation errors next to the input.
    public func bind<V>(_ keyPath: WritableKeyPath<Schema, V>) -> Binding<V> {
        Binding(
            get: { self.values[keyPath: keyPath] },
            set: { self.values[keyPath: keyPath] = $0 }
        )
    }

    /// Read a per-field error.
    public func error<V>(for keyPath: KeyPath<Schema, V>) -> String? {
        errors[keyName(keyPath)]
    }

    /// Set a per-field error. Pass `nil` to clear.
    public func setError<V>(_ message: String?, for keyPath: KeyPath<Schema, V>) {
        let key = keyName(keyPath)
        if let message {
            errors[key] = message
        } else {
            errors.removeValue(forKey: key)
        }
    }

    /// Clear all field-level errors plus any captured submit error.
    public func clearErrors() {
        errors.removeAll()
        submitError = nil
    }

    /// Run an async submission operation while toggling `isSubmitting`.
    /// Captures thrown errors into `submitError` rather than re-throwing,
    /// so call sites can stay declarative — the failure path lights up
    /// through the observable state.
    public func submit(
        _ operation: @escaping () async throws -> Void
    ) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        submitError = nil
        do {
            try await operation()
        } catch {
            submitError = error
        }
        isSubmitting = false
    }

    /// Generate a stable name for a keyPath. AnyKeyPath has a usable
    /// `String(describing:)` form like `\Schema.email`; trim the prefix
    /// so the error map key is just `email`.
    private func keyName<V>(_ keyPath: KeyPath<Schema, V>) -> String {
        let s = String(describing: keyPath)
        if let dot = s.firstIndex(of: ".") {
            return String(s[s.index(after: dot)...])
        }
        return s
    }
}
