import Foundation

public enum ToolchainResources {
    public static var root: URL {
        guard let url = Bundle.module.url(forResource: "Resources", withExtension: nil) else {
            fatalError("SwiftWUIToolchain resources missing from bundle")
        }
        return url
    }
    public static func url(_ rel: String) -> URL {
        root.appendingPathComponent(rel)
    }
}
