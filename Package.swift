// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SakuZip",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SakuZip", targets: ["SakuZipApp"]),
        .library(name: "SakuZipCore", targets: ["SakuZipCore"])
    ],
    targets: [
        .target(name: "SakuZipCore"),
        .target(
            name: "CSakuZipArchive",
            path: "Sources/CSakuZipArchive",
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
            name: "SakuZipApp",
            dependencies: ["SakuZipCore", "CSakuZipArchive"],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .executableTarget(
            name: "SakuZipCoreChecks",
            dependencies: ["SakuZipCore"]
        ),
        .executableTarget(
            name: "SakuZipArchiveChecks",
            dependencies: ["SakuZipCore", "CSakuZipArchive"]
        )
    ],
    swiftLanguageModes: [.v5]
)
