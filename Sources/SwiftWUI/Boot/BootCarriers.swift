/// A rendered boot shell. Codable because the CLI receives it as one JSON line
/// from `swift run <App> boot-shell` (boot spec §9.2).
public struct BootShell: Codable, Equatable {
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
    public var sizeBytes: Int?
    public var delayMS: Int
    public init(wasmURL: String, entryURL: String, sizeBytes: Int?, delayMS: Int) {
        self.wasmURL = wasmURL; self.entryURL = entryURL
        self.sizeBytes = sizeBytes; self.delayMS = delayMS
    }
}
