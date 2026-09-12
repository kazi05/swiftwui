// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "EmbeddedCounter",
    targets: [
        // build.sh adds Embedded only for the Embedded measurement. Keeping the
        // manifest neutral makes the regular and Embedded artifacts use the
        // exact same Swift source and product graph.
        .executableTarget(name: "EmbeddedCounter"),
    ]
)
