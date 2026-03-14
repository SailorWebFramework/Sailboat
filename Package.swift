// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Sailboat",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Sailboat",
            targets: ["Sailboat"])
    ],
    dependencies: [ ],
    targets: [
        .target(
            name: "Sailboat",
            dependencies: [],
            path: "Sources"
        )
    ]
)
