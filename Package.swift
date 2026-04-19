// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "LiquidMetal2D",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "LiquidMetal2D",
            targets: ["LiquidMetal2D"]),
    ],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint", from: "0.63.2"),
    ],
    targets: [
        .target(
            name: "LiquidMetal2D",
            resources: [
                .copy("Resources/AlphaBlendShader.metalSource"),
                .copy("Resources/WireframeShader.metalSource"),
                .copy("Resources/RippleShader.metalSource"),
                .copy("Resources/ParticleShader.metalSource"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint"),
            ]),
        .testTarget(
            name: "LiquidMetal2DTests",
            dependencies: ["LiquidMetal2D"]),
    ]
)
