import Foundation

public enum PackageInfo {
    /// First executable product per `swift package describe --type json`.
    public static func executableProduct(in dir: String, runner: ProcessRunner) throws -> String {
        let r = try runner.run("swift", ["package", "describe", "--type", "json"], cwd: dir, streamOutput: false)
        guard r.exitCode == 0,
              let data = r.stdout.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ToolchainError.productNotFound(dir) }
        // products: [{"name": "...", "type": {"executable": null}}, ...]
        if let products = obj["products"] as? [[String: Any]] {
            for p in products {
                if let type = p["type"] as? [String: Any], type.keys.contains("executable"),
                   let name = p["name"] as? String { return name }
            }
        }
        // fallback: targets: [{"name": "...", "type": "executable"}, ...]
        if let targets = obj["targets"] as? [[String: Any]] {
            for t in targets where (t["type"] as? String) == "executable" {
                if let name = t["name"] as? String { return name }
            }
        }
        throw ToolchainError.productNotFound(dir)
    }
}
