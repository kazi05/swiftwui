import Foundation

public enum DevInjection {
    /// The flag script MUST run before the app module loads — injection right
    /// after <head> guarantees it (module scripts are deferred by spec).
    static let snippet =
        #"<script>window.__swiftwui_dev = true;</script><script src="/__swiftwui/dev-client.js"></script>"#

    public static func inject(into html: String) -> String {
        if let range = html.range(of: "<head>", options: .caseInsensitive) {
            var out = html
            out.insert(contentsOf: snippet, at: range.upperBound)
            return out
        }
        return snippet + html   // headless documents: prepend (spec §6)
    }

    /// Single-line JSON string literal for SSE data frames.
    public static func jsonStringLiteral(_ s: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [s])
        guard let data, var text = String(data: data, encoding: .utf8) else { return "\"\"" }
        text.removeFirst()   // strip the array brackets: ["..."] → "..."
        text.removeLast()
        return text
    }
}
