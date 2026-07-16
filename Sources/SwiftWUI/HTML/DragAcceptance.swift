/// Matching between a zone's `data-swui-drop-accepts` attribute and a live
/// drag's `dataTransfer` contents. Pure string logic so it is testable
/// natively; DOMBackend calls it at dragenter/dragover fire time.
///
/// Token grammar (space-separated):
///   "Files"                          — any OS-file drag
///   "Files:image/*,application/pdf"  — file drag whose items match a pattern
///   "<content-type>"                 — custom payload type (exact match)
enum _DragAcceptance {
    /// - fileMimes: `dataTransfer.items[].type` for kind=="file" entries.
    ///   Empty while unavailable (some browsers hide items mid-drag) →
    ///   optimistic accept; the drop-side filter is authoritative.
    static func matches(accepts: String, types: [String], fileMimes: [String]) -> Bool {
        for token in accepts.split(separator: " ") {
            if token == "Files" {
                if types.contains("Files") { return true }
            } else if token.hasPrefix("Files:") {
                guard types.contains("Files") else { continue }
                if fileMimes.isEmpty { return true }          // optimistic
                let patterns = token.dropFirst("Files:".count).split(separator: ",")
                if fileMimes.contains(where: { mime in
                    patterns.contains { mimeMatches(pattern: String($0), mime: mime) }
                }) { return true }
            } else if types.contains(String(token)) {
                return true
            }
        }
        return false
    }

    /// "*/*" matches anything; "image/*" is a prefix family; else exact,
    /// case-insensitive. UX filtering only — never a security decision.
    static func mimeMatches(pattern: String, mime: String) -> Bool {
        if pattern == "*/*" || pattern == "*" { return true }
        let p = pattern.lowercased(), m = mime.lowercased()
        if p.hasSuffix("/*") { return m.hasPrefix(p.dropLast()) }   // keeps the "/"
        return p == m
    }
}
