import Foundation

enum Command {
    case dev(DevOptions)
    case build(BuildOptions)
}

struct DevOptions {
    var target: String
    var port: Int = 8080
    var sdk: String?
    var watchPath: String = "Sources"
    var openBrowser: Bool = false
}

struct BuildOptions {
    var target: String
    var output: String = "dist"
    var sdk: String?
    var optimize: OptimizeLevel = .default
}

enum OptimizeLevel: String {
    case `default`
    case size
    case aggressive
}

func parseArguments() -> Command {
    let args = Array(CommandLine.arguments.dropFirst())

    var command = "dev"
    var target: String?
    var port = 8080
    var sdk: String?
    var watchPath = "Sources"
    var output = "dist"
    var optimize = OptimizeLevel.default
    var openBrowser = false

    var i = 0
    if let first = args.first, !first.starts(with: "-") {
        command = first
        i = 1
    }

    while i < args.count {
        switch args[i] {
        case "--target":
            i += 1; if i < args.count { target = args[i] }
        case "--port":
            i += 1; if i < args.count { port = Int(args[i]) ?? 8080 }
        case "--sdk":
            i += 1; if i < args.count { sdk = args[i] }
        case "--watch":
            i += 1; if i < args.count { watchPath = args[i] }
        case "--output":
            i += 1; if i < args.count { output = args[i] }
        case "--optimize":
            i += 1; if i < args.count { optimize = OptimizeLevel(rawValue: args[i]) ?? .default }
        case "--open":
            openBrowser = true
        default:
            break
        }
        i += 1
    }

    guard let target else {
        print("Error: --target is required")
        print("Usage: swift run swiftwui-dev [dev|build] --target <name> [--port <port>] [--sdk <sdk-id>]")
        exit(1)
    }

    switch command {
    case "build":
        return .build(BuildOptions(target: target, output: output, sdk: sdk, optimize: optimize))
    default:
        return .dev(DevOptions(target: target, port: port, sdk: sdk, watchPath: watchPath, openBrowser: openBrowser))
    }
}
