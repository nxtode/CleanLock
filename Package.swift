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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.2")
    ],
    targets: [
        .executableTarget(
            name: "CleanLock",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/CleanLock"
        )
    ]
)
