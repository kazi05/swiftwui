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

        // Optimize WASM
        switch options.optimize {
        case .size:
            optimizeWASM(flags: ["-Oz", "--strip-debug"])
        case .aggressive:
            optimizeWASM(flags: ["-O3", "--strip-debug"])
            compressFiles()
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

    private func compressFiles() {
        let fm = FileManager.default
        let outputDir = options.output
        guard let files = try? fm.contentsOfDirectory(atPath: outputDir) else { return }

        for file in files where file.hasSuffix(".wasm") || file.hasSuffix(".js") {
            let path = outputDir + "/" + file
            let gzipProcess = Process()
            gzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
            gzipProcess.arguments = ["-k", "-9", path]
            try? gzipProcess.run()
            gzipProcess.waitUntilExit()
        }
        print("[SwiftWUI] Pre-compressed .gz files created")
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
