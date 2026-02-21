import Foundation

final class FileWatcher: @unchecked Sendable {
    private var process: Process?
    private var debounceTimer: DispatchWorkItem?
    private let debounceInterval: TimeInterval
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "swiftwui.filewatcher")

    init(debounceInterval: TimeInterval = 0.3, onChange: @escaping @Sendable () -> Void) {
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    func watch(directory: String) {
        // Try fswatch first (macOS: brew install fswatch)
        if FileManager.default.fileExists(atPath: "/usr/local/bin/fswatch") ||
           FileManager.default.fileExists(atPath: "/opt/homebrew/bin/fswatch") {
            startFSWatch(directory: directory)
        } else {
            print("Note: Install fswatch for better file watching (brew install fswatch)")
            print("Falling back to polling (1s interval)")
            startPolling(directory: directory)
        }
    }

    private func startFSWatch(directory: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = [
            "fswatch", "-r",
            "--include", "\\.swift$",
            "--exclude", ".*",
            "-l", "0.3",
            directory
        ]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.debounceAndNotify()
        }

        do {
            try proc.run()
            self.process = proc
        } catch {
            print("Warning: fswatch failed, falling back to polling")
            startPolling(directory: directory)
        }
    }

    private func startPolling(directory: String) {
        nonisolated(unsafe) var lastModified: [String: Date] = [:]

        queue.async { [weak self] in
            while true {
                Thread.sleep(forTimeInterval: 1.0)
                let fm = FileManager.default
                guard let enumerator = fm.enumerator(atPath: directory) else { continue }

                var changed = false
                while let file = enumerator.nextObject() as? String {
                    guard file.hasSuffix(".swift") else { continue }
                    let path = (directory as NSString).appendingPathComponent(file)
                    guard let attrs = try? fm.attributesOfItem(atPath: path),
                          let mtime = attrs[.modificationDate] as? Date else { continue }

                    if let prev = lastModified[path], prev != mtime {
                        changed = true
                    }
                    lastModified[path] = mtime
                }

                if changed {
                    self?.debounceAndNotify()
                }
            }
        }
    }

    private func debounceAndNotify() {
        debounceTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        debounceTimer = item
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    func stop() {
        process?.terminate()
        process = nil
        debounceTimer?.cancel()
    }
}
