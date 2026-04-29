import Foundation

class ProductionBuilder {
    let options: BuildOptions
    let builder: WASMBuilder

    init(options: BuildOptions) {
        let sdk = options.sdk ?? WASMBuilder.detectSDK() ?? "swift-6.2.3-RELEASE_wasm"
        self.options = options
        self.builder = WASMBuilder(target: options.target, sdk: sdk, configuration: "release")
    }

    func build() {
        let start = Date()
        print("[SwiftWUI] Building \(options.target) for production...")

        let result = builder.build()
        guard result.success else {
            print("[SwiftWUI] Build failed:\n\(result.output)")
            exit(1)
        }
        print("[SwiftWUI] Release build completed in \(String(format: "%.1f", result.duration))s")

        let fm = FileManager.default
        let outputDir = options.output

        // Clean and create output directory
        if fm.fileExists(atPath: outputDir) {
            try? fm.removeItem(atPath: outputDir)
        }
        try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        // Copy PackageToJS output
        let srcDir = builder.outputDirectory
        if let files = try? fm.contentsOfDirectory(atPath: srcDir) {
            for file in files {
                try? fm.copyItem(
                    atPath: srcDir + "/" + file,
                    toPath: outputDir + "/" + file
                )
            }
        }

        // Generate production HTML
        let html = HTMLTemplate(target: options.target).productionHTML()
        try? html.write(toFile: outputDir + "/index.html", atomically: true, encoding: .utf8)

        // Optimize WASM. The size pass is the bulk of the win — `-Oz` plus
        // strip-debug/strip-producers/converge typically takes a 60+MB debug
        // artefact down to ~1MB. The aggressive variant also pre-compresses
        // and emits SRI hashes so production servers can ship the static
        // bytes with `Cache-Control: immutable` and a CSP-safe `integrity=`
        // attribute on the bootstrap script tag.
        switch options.optimize {
        case .size:
            optimizeWASM(flags: ["-Oz", "--strip-debug", "--strip-producers", "--converge"])
            compressFiles()
            emitSRI()
        case .aggressive:
            optimizeWASM(flags: ["-O3", "--strip-debug", "--strip-producers", "--converge"])
            compressFiles()
            emitSRI()
        case .default:
            break
        }

        let totalDuration = Date().timeIntervalSince(start)
        printSummary(duration: totalDuration)
    }

    private func optimizeWASM(flags: [String]) {
        let wasmPath = options.output + "/\(options.target).wasm"
        guard FileManager.default.fileExists(atPath: wasmPath) else {
            print("[SwiftWUI] Warning: WASM file not found at \(wasmPath)")
            return
        }

        print("[SwiftWUI] Running wasm-opt \(flags.joined(separator: " "))...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["wasm-opt"] + flags + [wasmPath, "-o", wasmPath]

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("[SwiftWUI] wasm-opt completed")
            } else {
                print("[SwiftWUI] Warning: wasm-opt failed (install with: brew install binaryen)")
            }
        } catch {
            print("[SwiftWUI] Warning: wasm-opt not found, skipping optimization")
        }
    }

    /// Emit gzip and brotli pre-compressed copies of every `.wasm` / `.js`
    /// asset. Cloudflare/Netlify/Nginx all pick the matching `.br` or `.gz`
    /// when the client advertises support — no per-request CPU spent.
    private func compressFiles() {
        let fm = FileManager.default
        let outputDir = options.output
        guard let files = try? fm.contentsOfDirectory(atPath: outputDir) else { return }

        for file in files where file.hasSuffix(".wasm") || file.hasSuffix(".js") {
            let path = outputDir + "/" + file
            // gzip -9 -k path  → path.gz
            runOptional(executable: "gzip", arguments: ["-k", "-9", path])
            // brotli -q 11 -k path  → path.br
            runOptional(executable: "brotli", arguments: ["-q", "11", "-k", path])
        }
        print("[SwiftWUI] Pre-compressed .gz and .br files created")
    }

    /// Compute SHA-384 hashes for every `.wasm` / `.js` asset, encode in
    /// base64, and write a sidecar `<file>.sri` that the deployment step can
    /// inline into the production HTML's `integrity="sha384-…"` attributes.
    /// SHA-384 is the SRI default; SHA-256 also acceptable but 384 is what
    /// the W3C recommendation suggests for new code.
    private func emitSRI() {
        let fm = FileManager.default
        let outputDir = options.output
        guard let files = try? fm.contentsOfDirectory(atPath: outputDir) else { return }

        for file in files where file.hasSuffix(".wasm") || file.hasSuffix(".js") {
            let path = outputDir + "/" + file
            // openssl dgst -sha384 -binary path | openssl base64 -A
            let hash = Process()
            hash.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            hash.arguments = ["sh", "-c",
                "openssl dgst -sha384 -binary '\(path)' | openssl base64 -A"]
            let pipe = Pipe()
            hash.standardOutput = pipe
            do {
                try hash.run()
                hash.waitUntilExit()
                guard hash.terminationStatus == 0 else { continue }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let b64 = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !b64.isEmpty else { continue }
                let line = "sha384-\(b64)\n"
                try line.write(toFile: path + ".sri", atomically: true, encoding: .utf8)
            } catch {
                continue
            }
        }
        print("[SwiftWUI] SHA-384 SRI files emitted")
    }

    /// Run a process if it is on PATH, swallow failures otherwise. Used for
    /// optional release-time tools (`gzip`, `brotli`, `openssl`) that may be
    /// absent on bare CI runners.
    private func runOptional(executable: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // optional tool, skip silently
        }
    }

    private func printSummary(duration: TimeInterval) {
        let fm = FileManager.default
        let outputDir = options.output

        print("\n--- Production Build Summary ---")
        print("Output: \(outputDir)/")
        print("Duration: \(String(format: "%.1f", duration))s")

        if let files = try? fm.contentsOfDirectory(atPath: outputDir) {
            for file in files.sorted() {
                let path = outputDir + "/" + file
                if let attrs = try? fm.attributesOfItem(atPath: path),
                   let size = attrs[.size] as? Int {
                    let sizeStr = size > 1024 * 1024
                        ? String(format: "%.1f MB", Double(size) / 1024 / 1024)
                        : String(format: "%.1f KB", Double(size) / 1024)
                    print("  \(file): \(sizeStr)")
                }
            }
        }
        print("--- Build complete ---\n")
    }
}
