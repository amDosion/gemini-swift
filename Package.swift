// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "gemini-swfit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "gemini-swfit",
            type: .dynamic,
            targets: ["gemini-swfit"]),
        .executable(
            name: "GeminiTestRunner",
            targets: ["GeminiTestRunner"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", .upToNextMajor(from: "2.1.1")),
    ],
    targets: [
        .target(
            name: "gemini-swfit",
            dependencies: ["SwiftyBeaver"],
            path: "Sources/gemini-swfit"),
        .testTarget(
            name: "gemini-swfitTests",
            dependencies: ["gemini-swfit"],
            path: "Tests",
            resources: [
                .process("Resources/image.png"),
                .process("Resources/oceans.mp4"),
                .process("Resources/1753924165117.mp3")
            ]),
        .executableTarget(
            name: "GeminiTestRunner",
            dependencies: ["gemini-swfit"],
            path: "Sources/GeminiTestRunner",
            resources: [
                .process("Resources/image.png"),
                .process("Resources/oceans.mp4"),
                .process("Resources/1753924165117.mp3")
            ]),
    ],
    swiftLanguageModes: [.v6]
)
