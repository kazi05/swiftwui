/// Chapter 18 — Data and dependencies. Pinned to Samples/Tour.
public enum Ch18 {
    static let samplePath = "Sites/Tutorial/Samples/Tour/Sources/Data.swift"

    static let keyCode = #"""
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
"""#
    static let modelCode = #"""
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
"""#
    static let dashboardCode = #"""
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
"""#
    static let fetchCode = #"""
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
"""#

    public static let chapter = Chapter(
        slug: "data-and-dependencies", track: .data, kicker: "CHAPTER · DATA",
        title: "Data and dependencies",
        tagline: "Fetch, persist, observe the browser — and swap any of it out in a test.",
        minutes: 25, kind: .chapter,
        sections: [
            Section(anchor: "data-fetch", kicker: "01 · FETCH",
                    title: "Load JSON with the session",
                    intro: "@Environment(\\.webSession) hands you the runtime's own WebSession — shaped like URLSession, with a Codable shortcut on top.",
                    steps: [
                        Step("Read the session in body, then call it from .task.",
                             detail: "This is the runtime's session. WebSession.shared is a separate process-wide default for code the render tree never reaches; configuring one tells you nothing about the other."),
                        Step("json(from:) is GET plus decode in one call.",
                             detail: "It throws .httpStatus on any non-2xx. data(from:) hands back the body and the status without throwing, the way URLSession does — the status is yours to inspect."),
                        Step("Catch WebFetchError and say something specific.",
                             detail: "Eight cases: badURL, invalidHeader, network, cancelled, timeout, decoding, httpStatus, unsupported."),
                        Step("badURL and invalidHeader are thrown before anything leaves the page.",
                             detail: "Only http, https and origin-relative URLs pass. A tab, newline or backslash inside the string is rejected rather than normalised, protocol-relative //host counts as cross-origin, and a header carrying CR, LF or NUL throws invalidHeader."),
                        Step("send(_:_:json:) is the same sugar for POST, PUT and PATCH — it encodes the body, sets the content type, and decodes the reply."),
                    ],
                    panel: .code(CodePanel(file: "Data.swift", code: fetchCode,
                                           origin: .sample(path: samplePath,
                                                           marker: "tour-data-fetch")))),
            Section(anchor: "data-persist", kicker: "02 · STORAGE",
                    title: "Remember a preference",
                    intro: "@AppStorage writes through to localStorage and @SceneStorage to sessionStorage. Both read and write like @State.",
                    steps: [
                        Step("@AppStorage survives a reload; @SceneStorage lives and dies with the tab.",
                             detail: "The demo persists the unit toggle across reloads and keeps the selected station per tab."),
                        Step("Any StorageConvertible value works.",
                             detail: "String, Bool, Int, Double, URL, Data and their optionals conform already; a String- or Int-backed enum opts in with an empty extension. Writing an optional back to nil removes the key rather than storing a sentinel."),
                        Step("Every wrapper for one key shares a single observable box.",
                             detail: "A write anywhere re-renders every reader of that key, in any component — including the imperative \\.webStorage dependency, which writes into the same boxes."),
                        Step("Web storage is plaintext and readable by any script on the origin. Never put a token, a password or personal data in it.",
                             detail: "The __swiftwui. key prefix is reserved for the framework; taking it warns once instead of failing."),
                        Step("Storage needs a live runtime.",
                             detail: "Construct the struct without mounting it and reads return the declared default while writes are dropped. A stored value that fails to decode also falls back to the default, with one warning, instead of crashing."),
                    ],
                    panel: .code(CodePanel(file: "Data.swift", code: dashboardCode,
                                           origin: .sample(path: samplePath,
                                                           marker: "tour-data-dashboard")))),
            Section(anchor: "data-signals", kicker: "03 · SIGNALS",
                    title: "What the browser tells you",
                    intro: "Five environment keys track browser state and re-render the components that read them. Where you read them decides whether that happens at all.",
                    steps: [
                        Step("\\.colorScheme reports prefers-color-scheme; \\.isOnline mirrors navigator.onLine."),
                        Step("\\.accessibilityReduceMotion, \\.appUpdateAvailable and \\.dragSession complete the set.",
                             detail: "reduceMotion already gates the animation engine, appUpdateAvailable pairs with \\.reloadToUpdate, and dragSession reports window-level drags including files entering the page."),
                        Step("A signal is tracked only when a component's body reads it.",
                             detail: "The same read inside a .task closure or an event handler returns the current value and registers nothing, so a later flip re-renders no one. Read it in body and pass it down."),
                        Step("Only the component that read a flipped signal re-renders — a sibling that ignores it is left alone."),
                        Step("Outside a live runtime every signal returns its default: .light and online.",
                             detail: "That is what a prerendered page serialises, so treat the first paint as the one that has not met the browser yet."),
                    ],
                    panel: .code(CodePanel(file: "Data.swift", code: dashboardCode,
                                           origin: .sample(path: samplePath,
                                                           marker: "tour-data-dashboard")))),
            Section(anchor: "data-inject", kicker: "04 · INJECTION",
                    title: "A dependency key end to end",
                    intro: "@Environment reaches Tags. A DependencyKey reaches everything else, and gives each value two versions: one for production, one for tests.",
                    steps: [
                        Step("Declare the seam as a value type, not a protocol.",
                             detail: "One struct with a different value per environment beats one protocol with two conformances to maintain."),
                        Step("A DependencyKey supplies liveValue and, optionally, testValue.",
                             detail: "testValue defaults to liveValue. Declare it and swift test picks it up on its own — the store probes once at startup for the testing runtime."),
                        Step("Extend DependencyValues with a computed property so the key gets a key path."),
                        Step("@Dependency resolves anywhere — a plain class, a free function, a service with no Tag in sight.",
                             detail: "AlertModel is not in the render tree, so @Environment has nothing to attach to."),
                        Step("Defaults are cached per key for the process lifetime.",
                             detail: "Two models built independently share one liveValue instance, so a reference-type dependency behaves as a singleton."),
                    ],
                    panel: .code(CodePanel(file: "Data.swift", code: keyCode,
                                           origin: .sample(path: samplePath,
                                                           marker: "tour-data-key")))),
            Section(anchor: "data-override", kicker: "05 · OVERRIDES",
                    title: "Swap it out in a test",
                    intro: "Overrides come from two functions and resolve in a fixed order. Knowing the order is the difference between a stub that applies and one that quietly does not.",
                    steps: [
                        Step("Resolution runs three tiers in order: the overrides captured when the wrapper was initialised, then the current global overrides, then the cached default."),
                        Step("withDependencies runs an operation under scoped overrides and restores the previous values on exit.",
                             detail: "A model built inside the block keeps them afterwards, including in escaping and async work — AlertModel.strict is built that way on purpose."),
                        Step("prepareDependencies changes the global overrides for good.",
                             detail: "Call it at startup. Called inside an active withDependencies scope it is undone when that scope exits."),
                        Step("Four built-ins ship with the framework: \\.webSession, \\.navigate, \\.webStorage and \\.logger.",
                             detail: "The DOM entry point rebinds navigate, webStorage and webSession to the live runtime after boot — never from inside mount(), so native tests cannot pollute each other's store."),
                        Step("@Dependency is not reactive: changing a dependency re-renders nothing.",
                             detail: "Inside a body prefer @Environment, which is wired into the render graph. Reach for @Dependency where the render tree does not go.",
                             panel: .terminal(title: "swift test", lines: [
                                TermLine(.command, "swift test --filter AlertModel"),
                                TermLine(.output, "✔ Test breachingUsesTheTestPolicy() passed after 0.002 seconds."),
                                TermLine(.output, "✔ Test suite AlertModelTests passed after 0.004 seconds."),
                                TermLine(.note, "No mock framework and no protocol: testValue substitutes the 0 °C limit for the 30 °C field limit on its own."),
                             ])),
                    ],
                    panel: .code(CodePanel(file: "Data.swift", code: modelCode,
                                           origin: .sample(path: samplePath,
                                                           marker: "tour-data-model")))),
        ],
        quiz: Quiz(questions: [
            Question(prompt: "A request to /api/readings.json comes back 404. Which call throws WebFetchError.httpStatus?",
                     options: [
                        "Both json(from:) and data(from:) — a 404 is a failure either way",
                        "Only json(from:) — data(from:) returns the body and the 404 status without throwing",
                        "Only data(from:) — the Codable sugar reports a decoding failure instead",
                        "Neither — httpStatus is reserved for 5xx responses",
                     ],
                     correctIndex: 1,
                     explanation: "Only the Codable sugar — json(from:) and send(_:_:json:) — turns a non-2xx status into .httpStatus. data(for:) and data(from:) keep URLSession's parity: the status arrives on the WebResponse as data you inspect, not as an error."),
            Question(prompt: "A component reads @Environment(\\.isOnline) inside its .task closure and nowhere else. The browser goes offline. What happens?",
                     options: [
                        "The component re-renders and the task runs again with the new value",
                        "The component re-renders, but the task keeps the value it captured",
                        "Nothing re-renders — the signal is tracked only when body reads it",
                        "The runtime asserts, because a signal read outside body is an error",
                     ],
                     correctIndex: 2,
                     explanation: "Environment signals are Observation-tracked during body evaluation. A read inside .task or an event handler returns the current value and registers no dependency, so the later flip invalidates nothing. Read the signal in body and hand it to the closure."),
            Question(prompt: "let model = withDependencies { $0.alertPolicy = strict } operation: { AlertModel() }. Later, well outside that block, model.policy is read. Which policy comes back?",
                     options: [
                        "The strict one — @Dependency snapshots the active overrides when the wrapper is initialised",
                        "The live one — the scope restored the previous values when it exited",
                        "The test one, because an expired override falls back to testValue",
                        "Whichever policy prepareDependencies installed most recently",
                     ],
                     correctIndex: 0,
                     explanation: "The first tier of resolution is the DependencyValues snapshot taken at @Dependency init. A model built inside the scope carries those values for its whole life — which is the reason to build it there rather than call into it from inside the block."),
        ]))
}
