// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "snaptex",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "snaptex", targets: ["SnapTexApp"]),
        .library(name: "SnapTexCore", targets: ["SnapTexCore"])
    ],
    targets: [
        .target(name: "SnapTexCore"),
        .executableTarget(
            name: "SnapTexApp",
            dependencies: ["SnapTexCore"],
            resources: [
                .copy("Resources/logo.png"),
                .copy("Resources/MathJax.js")
            ]
        ),
        .testTarget(
            name: "SnapTexCoreTests",
            dependencies: ["SnapTexCore"]
        ),
        .testTarget(
            name: "SnapTexAppTests",
            dependencies: ["SnapTexApp"]
        )
    ]
)
