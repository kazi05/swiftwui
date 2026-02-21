import SwiftWUI

struct CounterApp: Tag {
    @State var count = 0

    var body: some Tag {
        Div {
            H1 { "SwiftWUI Counter" }
            P {
                Text("Count: \(count)")
            }
            .fontSize(.px(24))
            Div {
                Button(onclick: { count -= 1 }) {
                    Text("-")
                }
                .padding(.px(8), .px(16))
                .fontSize(.px(20))
                .cursor(.pointer)

                Button(onclick: { count += 1 }) {
                    Text("+")
                }
                .padding(.px(8), .px(16))
                .fontSize(.px(20))
                .cursor(.pointer)
            }
            .display(.flex)
            .style("gap", "12px")
            .style("align-items", "center")
        }
        .padding(.px(32))
        .style("font-family", "system-ui, sans-serif")
    }
}

let app = Application {
    Route("/") { CounterApp() }
}
app.mount()
