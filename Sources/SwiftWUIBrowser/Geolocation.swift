// Geolocation.swift - Browser Geolocation API wrapper

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

import Observation

/// Represents geographic coordinates returned by the Geolocation API.
public struct Coordinate: Sendable {
    /// The latitude in decimal degrees.
    public let latitude: Double
    /// The longitude in decimal degrees.
    public let longitude: Double
    /// The accuracy of the position in metres, if available.
    public let accuracy: Double?

    public init(latitude: Double, longitude: Double, accuracy: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
    }
}

/// Manages browser geolocation access.
///
/// Create an instance, call ``requestLocation()``, and observe
/// ``lastLocation`` for results.
///
/// ```swift
/// struct LocationView: Tag {
///     @State var geo = GeolocationManager()
///
///     var body: some Tag {
///         if let loc = geo.lastLocation {
///             Text("Lat: \(loc.latitude), Lon: \(loc.longitude)")
///         }
///         Button(onclick: { geo.requestLocation() }) { Text("Get Location") }
///     }
/// }
/// ```
@Observable
public final class GeolocationManager: @unchecked Sendable {
    /// The most recently obtained location, or `nil` if none.
    public var lastLocation: Coordinate?
    /// A human-readable error message, or `nil` if no error occurred.
    public var error: String?
    /// Whether a location request is currently in progress.
    public var isLoading = false

    public init() {}

    /// Request the user's current location.
    ///
    /// On WASM, results are delivered asynchronously through ``lastLocation``
    /// and ``error``. The ``isLoading`` flag is set while the request is active.
    /// On non-WASM platforms, this immediately sets ``error``.
    public func requestLocation() {
        #if arch(wasm32)
        let nav = JSObject.global.navigator.object!
        guard nav.geolocation.isUndefined == false else {
            error = "Geolocation is not supported by this browser"
            return
        }

        isLoading = true
        error = nil

        let geo = nav.geolocation.object!

        let successClosure = JSOneshotClosure { [weak self] args in
            let position = args[0].object!
            let coords = position.coords.object!
            self?.lastLocation = Coordinate(
                latitude: coords.latitude.number!,
                longitude: coords.longitude.number!,
                accuracy: coords.accuracy.number
            )
            self?.isLoading = false
            return .undefined
        }

        let errorClosure = JSOneshotClosure { [weak self] args in
            let err = args[0].object!
            self?.error = err.message.string ?? "Unknown geolocation error"
            self?.isLoading = false
            return .undefined
        }

        _ = geo.getCurrentPosition!(successClosure, errorClosure)
        #else
        error = "Geolocation is only available in WASM environment"
        #endif
    }
}
