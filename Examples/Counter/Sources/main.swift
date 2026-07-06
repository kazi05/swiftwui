import SwiftWUI
import SwiftWUIDOM

// tutorial:begin counter
struct Counter: Tag {
    @State private var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("−") { count -= 1 }
            Button("+") { count += 1 }
            if count >= 10 { P { "Double digits." } }
        }
    }
}
// tutorial:end counter

@main
struct CounterApp: App {
    var body: some Tag { Counter() }
}
