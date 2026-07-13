// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ThemeKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ThemeKit", targets: ["ThemeKit"]),
        .executable(name: "themectl", targets: ["themectl"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "ThemeKit",
            resources: [.copy("Resources/Themes")]
        ),
        .executableTarget(
            name: "themectl",
            dependencies: [
                "ThemeKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "ThemeKitTests",
            dependencies: ["ThemeKit"]
        ),
    ]
)
