// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CleanLock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CleanLock", targets: ["CleanLock"])
    ],
    targets: [
        .executableTarget(
            name: "CleanLock",
            path: "Sources/CleanLock"
        )
    ]
)
