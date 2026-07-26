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
        .target(
            name: "CYCompressArchive",
            path: "Sources/CYCompressArchive",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("minizip"),
                .define("HAVE_LIBCOMP"),
                .define("HAVE_PKCRYPT"),
                .define("HAVE_WZAES"),
                .define("_POSIX_C_SOURCE", to: "200809L"),
                .define("_BSD_SOURCE"),
                .define("_DEFAULT_SOURCE"),
                .define("_DARWIN_C_SOURCE"),
                .define("MZ_TARGET_APPSTORE", to: "1")
            ],
            linkerSettings: [
                .linkedLibrary("compression"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "YCompressApp",
            dependencies: ["YCompressCore", "CYCompressArchive"],
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
        ),
        .executableTarget(
            name: "YCompressArchiveChecks",
            dependencies: ["YCompressCore", "CYCompressArchive"]
        )
    ],
    swiftLanguageModes: [.v5]
)
