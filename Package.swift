// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CleanLock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CleanLock", targets: ["CleanLock"]),
        .executable(name: "CleanLockMenuBarAgent", targets: ["CleanLockMenuBarAgent"]),
        .executable(name: "CleanLockLoginHelper", targets: ["CleanLockLoginHelper"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.2")
    ],
    targets: [
        .target(
            name: "CleanLockShared",
            path: "Sources/CleanLockShared"
        ),
        .executableTarget(
            name: "CleanLock",
            dependencies: [
                "CleanLockShared",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/CleanLock"
        ),
        .executableTarget(
            name: "CleanLockMenuBarAgent",
            dependencies: [
                "CleanLockShared"
            ],
            path: "Sources/CleanLockMenuBarAgent"
        ),
        .executableTarget(
            name: "CleanLockLoginHelper",
            dependencies: [
                "CleanLockShared"
            ],
            path: "Sources/CleanLockLoginHelper"
        )
    ]
)
