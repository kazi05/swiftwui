import Foundation
import SwiftWUI

/// `dist/swiftwui-site.json` — how the toolchain (which does not depend on
/// SwiftWUI and cannot read Swift statics) learns the locale strategy.
/// Reserved filename: excluded from PWA precache like `nginx.conf`.
public enum SiteDescriptor {
    public static let fileName = "swiftwui-site.json"

    public static func json(localization: Localization?) -> String? {
        guard let localization else { return nil }
        let strategy: String
        switch localization.strategy {
        case .pathPrefix: strategy = "pathPrefix"
        case .negotiated: strategy = "negotiated"
        case .client:     strategy = "client"
        }
        let locales = localization.supported.map { "\"\($0.identifier)\"" }.joined(separator: ",")
        return """
        {"localization":{"strategy":"\(strategy)","locales":[\(locales)],"default":"\(localization.default.identifier)"}}
        """
    }

    public static func write(localization: Localization?, outDir: String) throws {
        guard let text = json(localization: localization) else { return }
        let path = outDir + "/" + fileName
        do {
            try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
            try text.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            throw StaticSiteError.io(path: path, underlying: "\(error)")
        }
    }
}
