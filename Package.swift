// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "LiquidMetal2D",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "LiquidMetal2D",
            targets: ["LiquidMetal2D"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mattCasanova/MetalMath.git", from: "0.2.0"),
        .package(url: "https://github.com/realm/SwiftLint", from: "0.63.2"),
    ],
    targets: [
        .target(
            name: "LiquidMetal2D",
            dependencies: ["MetalMath"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint"),
            ]),
        .testTarget(
            name: "LiquidMetal2DTests",
            dependencies: ["LiquidMetal2D"]),
    ]
)
