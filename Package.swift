// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClaudeCodeSDK",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "ClaudeCodeSDK",
            targets: ["ClaudeCodeSDK"]
        ),
        .executable(
            name: "ClaudeCodeExample",
            targets: ["ClaudeCodeExample"]
        )
    ],
    targets: [
        .target(
            name: "ClaudeCodeSDK",
            dependencies: [],
            resources: [
                .copy("Resources/sdk-wrapper.mjs")
            ],
            swiftSettings: []
        ),
        .executableTarget(
            name: "ClaudeCodeExample",
            dependencies: ["ClaudeCodeSDK"]
        ),
        .testTarget(
            name: "ClaudeCodeSDKTests",
            dependencies: ["ClaudeCodeSDK"]
        )
    ]
)
