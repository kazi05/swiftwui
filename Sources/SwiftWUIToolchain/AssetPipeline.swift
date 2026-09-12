import Foundation

/// Prepares responsive variants using host tools and publishes their dimensions.
/// Codec dependencies remain outside the browser runtime.
public enum AssetPipeline {
    public struct Configuration: Codable, Equatable {
        public var images: [Image] = []
        public var fonts: [Font] = []
        public init(images: [Image] = [], fonts: [Font] = []) { self.images = images; self.fonts = fonts }
        private enum CodingKeys: String, CodingKey { case images, fonts }
        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            images = try values.decodeIfPresent([Image].self, forKey: .images) ?? []
            fonts = try values.decodeIfPresent([Font].self, forKey: .fonts) ?? []
        }
    }
    public struct Image: Codable, Equatable {
        /// Stable logical name used by application code.
        public var id: String
        /// Paths are relative to public/ and become root-relative URLs.
        public var variants: [String]
        public var sizes: String?
        /// Optional source plus widths turn this manifest into a generator. The
        /// command receives `{input}`, `{output}`, and `{width}` substitutions.
        public var source: String?
        public var widths: [Int]?
        public var command: [String]?
        public init(id: String, variants: [String] = [], sizes: String? = nil, source: String? = nil, widths: [Int]? = nil, command: [String]? = nil) {
            self.id = id; self.variants = variants; self.sizes = sizes; self.source = source; self.widths = widths; self.command = command
        }
        private enum CodingKeys: String, CodingKey { case id, variants, sizes, source, widths, command }
        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(String.self, forKey: .id)
            variants = try values.decodeIfPresent([String].self, forKey: .variants) ?? []
            sizes = try values.decodeIfPresent(String.self, forKey: .sizes)
            source = try values.decodeIfPresent(String.self, forKey: .source)
            widths = try values.decodeIfPresent([Int].self, forKey: .widths)
            command = try values.decodeIfPresent([String].self, forKey: .command)
        }
    }
    public struct Font: Codable, Equatable {
        public var command: [String]
        public var output: String?
        public init(command: [String], output: String? = nil) { self.command = command; self.output = output }
    }
    public struct Manifest: Codable, Equatable {
        public var schemaVersion = 1
        public var images: [Entry]
        public var fonts: [FontEntry]
    }
    public struct Entry: Codable, Equatable {
        public var id: String
        public var width: Int
        public var height: Int
        public var src: String
        public var srcset: String
        public var sizes: String?
    }
    public struct FontEntry: Codable, Equatable { public var href: String }

    public static let configurationName = "swiftwui-assets.json"
    public static let manifestName = "swiftwui-assets-manifest.json"

    /// Generates configured image variants, runs font preparation commands, then writes the
    /// manifest. Commands are arrays (never shell text), so project configuration
    /// cannot accidentally acquire shell interpolation semantics.
    @discardableResult
    public static func generate(projectDir: String, outDir: String, runner: ProcessRunner) throws -> Manifest? {
        let configPath = projectDir + "/" + configurationName
        guard FileManager.default.fileExists(atPath: configPath) else { return nil }
        let config = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: URL(fileURLWithPath: configPath)))
        try prepare(config: config, projectDir: projectDir, runner: runner)
        return try writeManifest(config: config, projectDir: projectDir, outDir: outDir)
    }

    /// Call before `DistLayout.assemble`: generated variants are project public
    /// assets and must be present before that directory is copied to dist.
    public static func prepare(projectDir: String, runner: ProcessRunner) throws -> Bool {
        let configPath = projectDir + "/" + configurationName
        guard FileManager.default.fileExists(atPath: configPath) else { return false }
        let config = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: URL(fileURLWithPath: configPath)))
        try prepare(config: config, projectDir: projectDir, runner: runner)
        return true
    }

    /// Publishes metadata after already-prepared assets were copied to dist.
    public static func writePreparedManifest(projectDir: String, outDir: String) throws -> Manifest? {
        let path = projectDir + "/" + configurationName
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let config = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        return try writeManifest(config: config, projectDir: projectDir, outDir: outDir)
    }

    private static func prepare(config: Configuration, projectDir: String, runner: ProcessRunner) throws {
        for image in config.images where image.source != nil || image.widths != nil {
            guard let rawSource = image.source, let widths = image.widths, !widths.isEmpty else { throw ToolchainError.io("asset image '\(image.id)' must specify both source and non-empty widths") }
            guard widths.allSatisfy({ $0 > 0 }), Set(widths).count == widths.count else { throw ToolchainError.io("asset image '\(image.id)' widths must be positive and unique") }
            let source = try safeRelativePath(rawSource)
            let sourcePath = try containedPath(source, projectDir: projectDir)
            guard let original = dimensions(of: sourcePath) else { throw ToolchainError.io("cannot read source dimensions for public/\(source)") }
            let ns = source as NSString; let stem = ns.deletingPathExtension, ext = ns.pathExtension
            guard !ext.isEmpty else { throw ToolchainError.io("asset image '\(image.id)' source needs a file extension") }
            for width in widths.sorted() {
                guard width <= original.width else { throw ToolchainError.io("asset image '\(image.id)' width \(width) exceeds source width \(original.width)") }
                let output = stem + "-\(width)w." + ext
                let outputPath = try containedPath(output, projectDir: projectDir)
                // Rebuild generated outputs when inputs change. Merely finding
                // an old file is not a content cache and can ship stale imagery.
                do {
                    let argv = image.command ?? ["sips", "--resampleWidth", "{width}", "{input}", "--out", "{output}"]
                    guard let executable = argv.first else { throw ToolchainError.io("asset image '\(image.id)' command cannot be empty") }
                    let arguments = argv.dropFirst().map { $0.replacingOccurrences(of: "{input}", with: sourcePath).replacingOccurrences(of: "{output}", with: outputPath).replacingOccurrences(of: "{width}", with: String(width)) }
                    let result = try runner.run(executable, arguments, cwd: projectDir, streamOutput: true)
                    guard result.exitCode == 0 else { throw ToolchainError.buildFailed(output: result.stdout + result.stderr) }
                }
                guard let actual = dimensions(of: outputPath), actual.width == width,
                      abs(Double(actual.height) / Double(actual.width) - Double(original.height) / Double(original.width)) < 0.02 else { throw ToolchainError.io("generated variant public/\(output) has unexpected dimensions") }
            }
        }
        for font in config.fonts {
            guard let executable = font.command.first else { throw ToolchainError.io("asset font command cannot be empty") }
            let result = try runner.run(executable, Array(font.command.dropFirst()), cwd: projectDir, streamOutput: true)
            guard result.exitCode == 0 else { throw ToolchainError.buildFailed(output: result.stdout + result.stderr) }
            if let output = font.output {
                let path = try containedPath(output, projectDir: projectDir)
                if !FileManager.default.fileExists(atPath: path) { throw ToolchainError.io("font command did not create public/\(output)") }
            }
        }
    }

    private static func writeManifest(config: Configuration, projectDir: String, outDir: String) throws -> Manifest {
        var entries: [Entry] = []
        guard Set(config.images.map(\.id)).count == config.images.count else {
            throw ToolchainError.io("asset image IDs must be unique")
        }
        for image in config.images.sorted(by: { $0.id < $1.id }) {
            var variants: [(url: String, width: Int, height: Int)] = []
            let declared = image.variants.isEmpty ? generatedVariants(for: image) : image.variants
            guard Set(declared).count == declared.count else { throw ToolchainError.io("asset image '\(image.id)' has duplicate variants") }
            for rel in declared {
                let normalized = try safeRelativePath(rel)
                let source = try containedPath(normalized, projectDir: projectDir)
                guard let size = dimensions(of: source) else { throw ToolchainError.io("cannot read image dimensions for public/\(normalized); supported formats are PNG, JPEG, WebP, and SVG") }
                guard size.width > 0, size.height > 0 else { throw ToolchainError.io("image dimensions must be positive: \(normalized)") }
                variants.append((encodedURL(normalized), size.width, size.height))
            }
            guard let fallback = variants.sorted(by: { $0.width < $1.width }).last else { throw ToolchainError.io("asset image '\(image.id)' has no variants") }
            guard Set(variants.map(\.width)).count == variants.count else { throw ToolchainError.io("asset image '\(image.id)' has duplicate width descriptors") }
            guard variants.allSatisfy({ abs(Double($0.height) / Double($0.width) - Double(fallback.height) / Double(fallback.width)) < 0.02 }) else { throw ToolchainError.io("asset image '\(image.id)' variants have different aspect ratios; use Picture sources for art direction") }
            let srcset = variants.sorted(by: { $0.width < $1.width }).map { "\($0.url) \($0.width)w" }.joined(separator: ", ")
            entries.append(Entry(id: image.id, width: fallback.width, height: fallback.height, src: fallback.url, srcset: srcset, sizes: image.sizes))
        }
        let fonts = try config.fonts.compactMap { font -> FontEntry? in guard let output = font.output else { return nil }; return FontEntry(href: encodedURL(try safeRelativePath(output))) }
        let manifest = Manifest(images: entries, fonts: fonts)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(manifest).write(to: URL(fileURLWithPath: outDir + "/" + manifestName), options: .atomic)
        return manifest
    }

    private static func generatedVariants(for image: Image) -> [String] {
        guard let source = image.source, let widths = image.widths else { return [] }
        let ns = source as NSString; return widths.sorted().map { ns.deletingPathExtension + "-\($0)w." + ns.pathExtension }
    }

    private static func safeRelativePath(_ path: String) throws -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard !path.hasPrefix("/"), !parts.contains(".."), !parts.isEmpty else { throw ToolchainError.io("asset path '\(path)' must be a relative path under public/") }
        return parts.joined(separator: "/")
    }
    private static func containedPath(_ path: String, projectDir: String) throws -> String {
        let relative = try safeRelativePath(path)
        let root = URL(fileURLWithPath: projectDir + "/public", isDirectory: true).resolvingSymlinksInPath().standardizedFileURL
        let candidate = root.appendingPathComponent(relative).resolvingSymlinksInPath().standardizedFileURL
        guard candidate.path.hasPrefix(root.path + "/") else {
            throw ToolchainError.io("asset path '\(path)' escapes public/ through a symbolic link")
        }
        return candidate.path
    }
    private static func encodedURL(_ relative: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: " ,")
        return "/" + (relative.addingPercentEncoding(withAllowedCharacters: allowed) ?? relative)
    }
    private static func dimensions(of path: String) -> (width: Int, height: Int)? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }; let b = [UInt8](data)
        if b.count >= 24, Array(b[0..<8]) == [137,80,78,71,13,10,26,10] { return (be32(b, 16), be32(b, 20)) }
        if b.count >= 10, b[0] == 0xFF, b[1] == 0xD8 { return jpegSize(b) }
        if b.count >= 30, Array(b[0..<4]) == [82,73,70,70], Array(b[8..<12]) == [87,69,66,80] { return webpSize(b) }
        if let text = String(data: data.prefix(32_768), encoding: .utf8), text.contains("<svg") { return svgSize(text) }
        return nil
    }
    private static func be32(_ b: [UInt8], _ p: Int) -> Int { Int(b[p]) << 24 | Int(b[p+1]) << 16 | Int(b[p+2]) << 8 | Int(b[p+3]) }
    private static func le24(_ b: [UInt8], _ p: Int) -> Int { Int(b[p]) | Int(b[p+1]) << 8 | Int(b[p+2]) << 16 }
    private static func jpegSize(_ b: [UInt8]) -> (Int, Int)? { var p = 2; while p + 3 < b.count { guard b[p] == 0xFF else { p += 1; continue }; let marker = b[p+1]; p += 2; if marker == 0xD8 || marker == 0xD9 { continue }; guard p + 1 < b.count else { return nil }; let n = Int(b[p]) << 8 | Int(b[p+1]); guard n >= 2, p + n <= b.count else { return nil }; if (0xC0...0xC3).contains(marker) || (0xC5...0xC7).contains(marker) || (0xC9...0xCB).contains(marker) || (0xCD...0xCF).contains(marker) { guard n >= 8 else { return nil }; return (Int(b[p+5]) << 8 | Int(b[p+6]), Int(b[p+3]) << 8 | Int(b[p+4])) }; p += n }; return nil }
    private static func webpSize(_ b: [UInt8]) -> (Int, Int)? { let type = String(decoding: b[12..<16], as: UTF8.self); if type == "VP8X", b.count >= 30 { return (le24(b, 24) + 1, le24(b, 27) + 1) }; if type == "VP8 ", b.count >= 30, b[23] == 0x9D, b[24] == 0x01, b[25] == 0x2A { return ((Int(b[26]) | Int(b[27]) << 8) & 0x3FFF, (Int(b[28]) | Int(b[29]) << 8) & 0x3FFF) }; if type == "VP8L", b.count >= 25 { let bits = Int(b[21]) | Int(b[22]) << 8 | Int(b[23]) << 16 | Int(b[24]) << 24; return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1) }; return nil }
    private static func svgSize(_ text: String) -> (Int, Int)? {
        let pattern = "viewBox\\s*=\\s*[\\\"']\\s*[-.0-9]+\\s+[-.0-9]+\\s+([0-9.]+)\\s+([0-9.]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let a = Range(match.range(at: 1), in: text), let c = Range(match.range(at: 2), in: text),
              let w = Double(text[a]), let h = Double(text[c]),
              w.isFinite, h.isFinite, w > 0, h > 0,
              w < Double(Int.max), h < Double(Int.max) else { return nil }
        return (Int(w.rounded()), Int(h.rounded()))
    }
}
