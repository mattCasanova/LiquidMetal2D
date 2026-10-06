// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "MotionatorKit",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "MotionatorKit", targets: ["MotionatorKit"]),
        .executable(name: "motionator", targets: ["motionator"]),
    ],
    dependencies: [
        .package(name: "LiquidMetal2D", path: "../../.."),
    ],
    targets: [
        .target(
            name: "MotionatorKit",
            dependencies: [.product(name: "LiquidMetal2D", package: "LiquidMetal2D")]),
        .executableTarget(
            name: "motionator",
            dependencies: ["MotionatorKit"]),
        .testTarget(
            name: "MotionatorKitTests",
            dependencies: ["MotionatorKit"]),
    ]
)
