// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OpenRockyPython",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "OpenRockyPython",
            targets: ["OpenRockyPython"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "Python",
            path: "Python.xcframework"
        ),
        .target(
            name: "OpenRockyPython",
            dependencies: ["Python"],
            path: "Sources/OpenRockyPython"
        ),
    ]
)
