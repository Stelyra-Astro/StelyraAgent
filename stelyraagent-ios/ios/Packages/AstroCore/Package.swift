// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AstroCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AstroCore", targets: ["AstroCore"]),
    ],
    targets: [
        .target(
            name: "CSwissEphemeris",
            path: "Sources/CSwissEphemeris",
            exclude: [
                "LICENSE",
                "LICENSE.TXT",
                "agpl-3.0.txt",
                "readme.md",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("NDEBUG", .when(configuration: .release)),
                .unsafeFlags(["-Wno-shorten-64-to-32"]),
            ]
        ),
        .target(
            name: "AstroCore",
            dependencies: ["CSwissEphemeris"]
        ),
        .testTarget(
            name: "AstroCoreTests",
            dependencies: ["AstroCore"],
            exclude: ["Fixtures"]
        ),
    ]
)
