// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YCompress",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "YCompress", targets: ["YCompressApp"]),
        .library(name: "YCompressCore", targets: ["YCompressCore"])
    ],
    targets: [
        .target(name: "YCompressCore"),
        .executableTarget(
            name: "YCompressApp",
            dependencies: ["YCompressCore"],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .executableTarget(
            name: "YCompressCoreChecks",
            dependencies: ["YCompressCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
