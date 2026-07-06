/// Line-based Swift/terminal syntax tokenizer (spec D8). Pure function of the
/// input line — determinism is what keeps ssg output and hydrated DOM identical.
public enum SwiftHighlighter {
    public enum Kind: Equatable, Sendable {
        case plain, keyword, type, string, comment, number, wrapper
        public var cssClass: String? {
            switch self {
            case .plain: return nil
            case .keyword: return "tok-kw"
            case .type: return "tok-type"
            case .string: return "tok-str"
            case .comment: return "tok-cmt"
            case .number: return "tok-num"
            case .wrapper: return "tok-wrap"
            }
        }
    }
    public struct Token: Equatable, Sendable {
        public let text: String
        public let kind: Kind
        public init(_ text: String, _ kind: Kind) { self.text = text; self.kind = kind }
    }

    static let keywords: Set<String> = [
        "import", "struct", "class", "enum", "extension", "protocol", "func",
        "var", "let", "some", "return", "if", "else", "guard", "for", "in",
        "while", "switch", "case", "default", "static", "public", "private",
        "init", "self", "true", "false", "nil", "throws", "try", "await", "async",
    ]

    public static func tokenize(line: String) -> [Token] {
        var tokens: [Token] = []
        var plain = ""
        func flushPlain() { if !plain.isEmpty { tokens.append(Token(plain, .plain)); plain = "" } }

        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            // comment to end of line
            if c == "/", i + 1 < chars.count, chars[i + 1] == "/" {
                flushPlain()
                tokens.append(Token(String(chars[i...]), .comment))
                return tokens
            }
            // string literal (interpolation stays inside the string token — matches the design)
            if c == "\"" {
                flushPlain()
                var j = i + 1
                var s = "\""
                while j < chars.count {
                    s.append(chars[j])
                    if chars[j] == "\"" && chars[j - 1] != "\\" { break }
                    j += 1
                }
                tokens.append(Token(s, .string))
                i = j + 1
                continue
            }
            // property wrapper / attribute
            if c == "@" {
                flushPlain()
                var j = i + 1
                while j < chars.count, chars[j].isLetter || chars[j].isNumber { j += 1 }
                tokens.append(Token(String(chars[i..<j]), .wrapper))
                i = j
                continue
            }
            // identifier / keyword / TypeName
            if c.isLetter || c == "_" {
                var j = i
                while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
                let word = String(chars[i..<j])
                if keywords.contains(word) {
                    flushPlain(); tokens.append(Token(word, .keyword))
                } else if word.first!.isUppercase {
                    flushPlain(); tokens.append(Token(word, .type))
                } else {
                    plain += word
                }
                i = j
                continue
            }
            // number
            if c.isNumber {
                var j = i
                while j < chars.count, chars[j].isNumber || chars[j] == "." || chars[j] == "_" { j += 1 }
                flushPlain(); tokens.append(Token(String(chars[i..<j]), .number))
                i = j
                continue
            }
            plain.append(c)
            i += 1
        }
        flushPlain()
        return tokens
    }
}
