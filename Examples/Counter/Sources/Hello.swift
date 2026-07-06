import SwiftWUI

// tutorial:begin hello
struct Hello: Tag {
    var body: some Tag {
        Div(class: "card") {
            H1("Hello, SwiftWUI")
            P { "Swift on the web —" }
            P { "no JavaScript required." }
            A(href: "/docs") { "Read the docs" }
        }
    }
}
// tutorial:end hello
