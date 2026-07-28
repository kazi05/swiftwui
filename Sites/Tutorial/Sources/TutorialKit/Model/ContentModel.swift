/// Content model for the tutorial site (spec §5). Pure data — no Tag imports.

/// Curriculum tracks, in reading order — `allCases` drives the overview's
/// grouping, so the declaration order IS the site's order.
public enum Track: String, CaseIterable, Sendable {
    case welcome = "Welcome"
    case explore = "Explore SwiftWUI"
    case styles = "Styles"
    case interact = "Interact"
    case routing = "Routing"
    case motion = "Motion"
    case data = "Data"
    case ship = "Ship"
}

public enum PageKind: Equatable, Sendable {
    case overview, chapter, wrapUp
}

public struct TermLine: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case command, output, note }
    public let kind: Kind
    public let text: String
    public init(_ kind: Kind, _ text: String) { self.kind = kind; self.text = text }
}

/// Where a code panel's text comes from — the TEXT is embedded (wasm has no
/// filesystem); the origin pins it to a compiled file via native test (spec §7/§9.2).
public enum CodeOrigin: Equatable, Sendable {
    /// `code` must equal the region between `// tutorial:begin <marker>` and
    /// `// tutorial:end <marker>` in the file at repo-relative `path`.
    case sample(path: String, marker: String)
    /// `code` must be a verbatim substring of the file at repo-relative `path`.
    case fragment(path: String)
}

public struct CodePanel: Equatable, Sendable {
    public let file: String        // chrome title, e.g. "Counter.swift"
    public let code: String        // embedded verbatim source text
    public let origin: CodeOrigin
    public init(file: String, code: String, origin: CodeOrigin) {
        self.file = file; self.code = code; self.origin = origin
    }
}

public enum Panel: Equatable, Sendable {
    case code(CodePanel)
    case terminal(title: String, lines: [TermLine])
    /// `screenshot` is a path under public/assets/, e.g. "screens/counter-3.png";
    /// rendered as <img src="/assets/screens/counter-3.png">.
    case browser(url: String, screenshot: String)
}

public struct Step: Equatable, Sendable {
    public let title: String
    public let detail: String?
    /// Override: when this step is active, the sticky panel shows this instead
    /// of the section panel (spec D2).
    public let panel: Panel?
    public init(_ title: String, detail: String? = nil, panel: Panel? = nil) {
        self.title = title; self.detail = detail; self.panel = panel
    }
}

public struct Section: Equatable, Sendable {
    public let anchor: String      // stable DOM id prefix + #anchor target, kebab-case
    public let kicker: String      // "01 · TOOLCHAIN"
    public let title: String
    public let intro: String?
    public let steps: [Step]
    public let panel: Panel
    public init(anchor: String, kicker: String, title: String, intro: String? = nil,
                steps: [Step], panel: Panel) {
        self.anchor = anchor; self.kicker = kicker; self.title = title
        self.intro = intro; self.steps = steps; self.panel = panel
    }
}

public struct Question: Equatable, Sendable {
    public let prompt: String
    public let options: [String]
    public let correctIndex: Int
    public let explanation: String
    public init(prompt: String, options: [String], correctIndex: Int, explanation: String) {
        self.prompt = prompt; self.options = options
        self.correctIndex = correctIndex; self.explanation = explanation
    }
}

public struct Quiz: Equatable, Sendable {
    public let questions: [Question]   // invariant: exactly 3 (spec §3)
    public init(questions: [Question]) { self.questions = questions }
}

public struct Chapter: Sendable {
    public let slug: String
    public let track: Track
    public let kicker: String      // "GETTING STARTED", "CHAPTER · STYLES", "WRAP-UP · SHIP"
    public let title: String
    public let tagline: String
    public let body: String?       // hero paragraph (big hero only)
    public let minutes: Int
    public let kind: PageKind
    public let heroPanel: Panel?   // ch4 code card in the hero (Figma 1:2); nil = simple hero
    public let sections: [Section]
    public let recap: [String]?    // wrap-up bullets (spec §5)
    public let quiz: Quiz?
    public init(slug: String, track: Track, kicker: String, title: String,
                tagline: String, body: String? = nil, minutes: Int, kind: PageKind,
                heroPanel: Panel? = nil, sections: [Section] = [],
                recap: [String]? = nil, quiz: Quiz? = nil) {
        self.slug = slug; self.track = track; self.kicker = kicker; self.title = title
        self.tagline = tagline; self.body = body; self.minutes = minutes; self.kind = kind
        self.heroPanel = heroPanel; self.sections = sections
        self.recap = recap; self.quiz = quiz
    }

    /// Route path: overview is "/", everything else "/tutorials/<slug>".
    public var path: String { kind == .overview ? "/" : "/tutorials/\(slug)" }
}

public extension Section {
    /// Panel to show when `step` is active: the step's override or the
    /// section default. Out-of-range (pre-mount) falls back to the default.
    func activePanel(step: Int) -> Panel {
        guard steps.indices.contains(step) else { return panel }
        return steps[step].panel ?? panel
    }
}
