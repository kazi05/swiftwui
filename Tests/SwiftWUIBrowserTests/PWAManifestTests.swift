import Testing
@testable import SwiftWUIBrowser

@Suite("WebAppManifest")
struct PWAManifestTests {
    @Test("Minimal manifest carries name, start_url, display")
    func minimal() {
        let m = WebAppManifest(name: "Test")
        let json = m.json()
        #expect(json.contains("\"name\": \"Test\""))
        #expect(json.contains("\"start_url\": \"/\""))
        #expect(json.contains("\"display\": \"standalone\""))
    }

    @Test("Optional fields are omitted when nil")
    func nilFieldsOmitted() {
        let m = WebAppManifest(name: "X")
        let json = m.json()
        #expect(!json.contains("short_name"))
        #expect(!json.contains("description"))
        #expect(!json.contains("theme_color"))
        #expect(!json.contains("orientation"))
    }

    @Test("All fields populate when supplied")
    func allFields() {
        let m = WebAppManifest(
            name: "Counter",
            shortName: "Cnt",
            description: "Count things",
            startURL: "/app",
            scope: "/app/",
            display: .fullscreen,
            orientation: .portrait,
            themeColor: "#0a84ff",
            backgroundColor: "#ffffff",
            icons: [
                .init(src: "/icon.png", sizes: "192x192", type: "image/png", purpose: .maskable)
            ],
            lang: "en-US",
            dir: .ltr,
            categories: ["productivity", "utilities"]
        )
        let json = m.json()
        #expect(json.contains("\"short_name\": \"Cnt\""))
        #expect(json.contains("\"description\": \"Count things\""))
        #expect(json.contains("\"scope\": \"/app/\""))
        #expect(json.contains("\"display\": \"fullscreen\""))
        #expect(json.contains("\"orientation\": \"portrait\""))
        #expect(json.contains("\"theme_color\": \"#0a84ff\""))
        #expect(json.contains("\"background_color\": \"#ffffff\""))
        #expect(json.contains("\"lang\": \"en-US\""))
        #expect(json.contains("\"dir\": \"ltr\""))
        #expect(json.contains("\"categories\": [\"productivity\", \"utilities\"]"))
    }

    @Test("Icons serialize with sizes, type, and purpose")
    func iconShape() {
        let m = WebAppManifest(name: "X", icons: [
            .init(src: "/a.png", sizes: "192x192", type: "image/png", purpose: .maskable),
            .init(src: "/b.png", sizes: "512x512"),
        ])
        let json = m.json()
        #expect(json.contains("\"src\": \"/a.png\""))
        #expect(json.contains("\"sizes\": \"192x192\""))
        #expect(json.contains("\"type\": \"image/png\""))
        #expect(json.contains("\"purpose\": \"maskable\""))
        #expect(json.contains("\"src\": \"/b.png\""))
        #expect(json.contains("\"sizes\": \"512x512\""))
    }

    @Test("Special characters in name are JSON-escaped")
    func nameEscaping() {
        let m = WebAppManifest(name: "He said \"hi\"\nLine 2")
        let json = m.json()
        #expect(json.contains("\\\"hi\\\""))
        #expect(json.contains("\\n"))
    }

    @Test("Display modes serialize correctly including hyphenated cases")
    func displayModes() {
        let modes: [(WebAppManifest.DisplayMode, String)] = [
            (.browser, "browser"),
            (.minimalUI, "minimal-ui"),
            (.standalone, "standalone"),
            (.fullscreen, "fullscreen"),
        ]
        for (mode, expected) in modes {
            let m = WebAppManifest(name: "X", display: mode)
            #expect(m.json().contains("\"display\": \"\(expected)\""))
        }
    }
}
