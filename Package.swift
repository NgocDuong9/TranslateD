// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TranslateD",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TranslateD", targets: ["TranslateD"])
    ],
    targets: [
        .executableTarget(
            name: "TranslateD",
            path: "Sources/TranslateD",
            resources: [
                .copy("image.png"),
                .copy("iconApp.png"),
                .copy("icon.svg")
            ]
        )
    ]
)
