/// A rendered boot shell. Codable because the CLI receives it as one JSON line
/// from `swift run <App> boot-shell` (boot spec §9.2).
///
/// `nonisolated` for that same reason: the CLI target is not MainActor-isolated
/// and could otherwise neither build nor read one (cf. `SHA256`).
public nonisolated struct BootShell: Codable, Equatable {
    public var html: String
    public var css: String
    public var delayMS: Int
    public init(html: String, css: String, delayMS: Int) {
        self.html = html; self.css = css; self.delayMS = delayMS
    }
}

/// Everything the shim needs, stamped at build time.
/// `sizeBytes == nil` means "unknown" — the shim then reports indeterminate
/// progress rather than dividing by a wrong number.
public struct BootConfig: Codable, Equatable {
    public var wasmURL: String
    public var entryURL: String
    /// Where `swiftwui-boot.js` is served from. Carried rather than hardcoded in
    /// the serializer: a project whose entry is not under `/app/` would 404 the
    /// shim and never boot, with the veil still up — and the dev server, which
    /// serves the shim at a fixed path of its own, could not say so.
    /// No default, so every construction site has to name the truth it knows.
    public var shimURL: String
    public var sizeBytes: Int?
    public var delayMS: Int
    public init(wasmURL: String, entryURL: String, shimURL: String,
                sizeBytes: Int?, delayMS: Int) {
        self.wasmURL = wasmURL; self.entryURL = entryURL; self.shimURL = shimURL
        self.sizeBytes = sizeBytes; self.delayMS = delayMS
    }
}
