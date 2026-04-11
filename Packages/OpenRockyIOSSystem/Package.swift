// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OpenRockyIOSSystem",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "OpenRockyIOSSystem",
            targets: ["ios_system", "files", "shell", "network_ios"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "ios_system",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.4/ios_system.xcframework.zip",
            checksum: "6973c1c14a66cdc110a5be7d62991af4546124bd0d9773b5391694b3a93a5be0"
        ),
        .binaryTarget(
            name: "files",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.4/files.xcframework.zip",
            checksum: "02d6522f5e1adc3b472f7aaa53910f049e6c5829e07c7e3005cf2a0d5f9f423a"
        ),
        .binaryTarget(
            name: "shell",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.4/shell.xcframework.zip",
            checksum: "78d71828b89c83741a8f7e857f0d065da72952558fd7deb806f5748c3801fd95"
        ),
        .binaryTarget(
            name: "network_ios",
            url: "https://github.com/holzschu/network_ios/releases/download/v0.3/network_ios.xcframework.zip",
            checksum: "9fe5f119b2d5568d2255e2540f36e76525bfbeaeda58f32f02592ca8d74f4178"
        ),
    ]
)
