import SwiftWUI

/// Chapter: "Data and dependencies". A dashboard that loads over the network,
/// remembers one preference across reloads and one per tab, reacts to two
/// browser signals, and resolves a rule that tests replace without a mock
/// framework.

struct Reading: Decodable, Hashable {
    let station: String
    let celsius: Double
}

private struct ReadingsPayload: Decodable { let readings: [Reading] }

// tutorial:begin tour-data-key
/// The seam is a value, not a protocol — one implementation per environment.
struct AlertPolicy {
    var limitCelsius: Double
    var name: String
}

enum AlertPolicyKey: DependencyKey {
    static var liveValue: AlertPolicy { AlertPolicy(limitCelsius: 30, name: "field") }
    /// Substituted automatically under `swift test`, so a test never reads the
    /// production number by accident.
    static var testValue: AlertPolicy { AlertPolicy(limitCelsius: 0, name: "test") }
}

extension DependencyValues {
    var alertPolicy: AlertPolicy {
        get { self[AlertPolicyKey.self] }
        set { self[AlertPolicyKey.self] = newValue }
    }
}
// tutorial:end tour-data-key

// tutorial:begin tour-data-model
/// A plain class has no place in the render tree, so `@Environment` has
/// nothing to attach to. `@Dependency` resolves anywhere.
final class AlertModel {
    @Dependency(\.alertPolicy) var policy
    @Dependency(\.logger) var logger

    func breaching(_ readings: [Reading]) -> [String] {
        let over = readings.filter { $0.celsius > policy.limitCelsius }.map(\.station)
        if !over.isEmpty {
            logger.warning("\(policy.name): \(over.count) station(s) over \(policy.limitCelsius)")
        }
        return over
    }

    /// Built inside the scope, so it keeps the override after the scope exits:
    /// `@Dependency` snapshots the overrides at init, not at each read.
    static let strict = withDependencies {
        $0.alertPolicy = AlertPolicy(limitCelsius: 18, name: "strict")
    } operation: {
        AlertModel()
    }
}
// tutorial:end tour-data-model

// tutorial:begin tour-data-dashboard
struct DataDemo: Tag {
    @Environment(\.webSession) var session
    @Environment(\.colorScheme) var scheme   // both signals stay reactive only
    @Environment(\.isOnline) var isOnline    // because they are read in `body`
    @AppStorage("tour.fahrenheit") private var fahrenheit = false   // survives reload
    @SceneStorage("tour.focused") private var focused = ""          // this tab only
    @State private var readings: [Reading] = []
    @State private var hot: [String] = []
    @State private var strictCount = 0
    @State private var failure: String?

    private let alerts = AlertModel()

    var body: some Tag {
        Main(class: "tour") {
            H1("Station readings")
            P { Text(isOnline ? "Live." : "Offline — this is the last load.") }
                .opacity(isOnline ? 1 : 0.6)
            P { Text("System theme: \(scheme == .dark ? "dark" : "light").") }

            Button(fahrenheit ? "Show °C" : "Show °F") { fahrenheit.toggle() }

            if let failure {
                P { Text(failure) }
                    .color(.hex("#b3261e"))
            }
            Ul {
                ForEach(readings, id: \.station) { reading in
                    Li {
                        Button(reading.station) { focused = reading.station }
                        Text(" \(temperature(reading))")
                        if focused == reading.station { Text(" ← focused") }
                    }
                }
            }
            P { Text("Over the field limit: \(hot.joined(separator: ", "))") }
            P { Text("Over the strict limit: \(strictCount)") }
            Link("/") { Span { "Back to the tour" } }
        }
        .task { await reload() }
    }
// tutorial:end tour-data-dashboard

    private func temperature(_ reading: Reading) -> String {
        fahrenheit ? "\(reading.celsius * 9 / 5 + 32) °F" : "\(reading.celsius) °C"
    }

// tutorial:begin tour-data-fetch
    /// `json(from:)` is the Codable sugar: unlike `data(from:)` it turns a
    /// non-2xx status into `.httpStatus` instead of handing back the body.
    private func reload() async {
        do {
            let payload: ReadingsPayload = try await session.json(from: "/api/readings.json")
            readings = payload.readings
            hot = alerts.breaching(payload.readings)
            strictCount = AlertModel.strict.breaching(payload.readings).count
            failure = nil
        } catch let error as WebFetchError {
            failure = Self.explain(error)
        } catch {
            failure = "Unexpected failure: \(error)"
        }
    }

    static func explain(_ error: WebFetchError) -> String {
        switch error {
        case .httpStatus(let code, _): "The server answered \(code)."
        case .decoding(let why): "The payload did not match Reading: \(why)"
        case .network(let why): "The request never completed: \(why)"
        case .timeout: "The request ran out of time."
        case .cancelled: "The request was cancelled."
        case .badURL(let url): "Rejected before sending: \(url) is not a usable URL."
        case .invalidHeader(let name): "Rejected before sending: bad header \(name)."
        case .unsupported: "This build has no fetch transport."
        }
    }
// tutorial:end tour-data-fetch
}
