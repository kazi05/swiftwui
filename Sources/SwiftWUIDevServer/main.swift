import Foundation

let command = parseArguments()

switch command {
case .dev(let options):
    let server = DevServer(options: options)
    Task {
        do {
            try await server.start()
        } catch {
            print("[SwiftWUI] Error: \(error)")
            exit(1)
        }
    }
    RunLoop.main.run()

case .build(let options):
    let prodBuilder = ProductionBuilder(options: options)
    prodBuilder.build()
}
