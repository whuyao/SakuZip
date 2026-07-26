import CSakuZipArchive
import Foundation
import SakuZipCore

private let password = Array("correct horse battery staple".utf8)

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
}

private func makeFixture() throws -> (
    root: URL,
    source: URL,
    archive: URL,
    output: URL,
    contents: String
) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("SakuZipChecks-\(UUID().uuidString)")
    let source = root.appendingPathComponent("测试资料", isDirectory: true)
    let archive = root.appendingPathComponent("encrypted.zip")
    let output = root.appendingPathComponent("output", isDirectory: true)
    let contents = "SakuZip encrypted ZIP round trip ✅"
    try FileManager.default.createDirectory(
        at: source,
        withIntermediateDirectories: true
    )
    try contents.write(
        to: source.appendingPathComponent("你好-日本語.txt"),
        atomically: true,
        encoding: .utf8
    )
    return (root, source, archive, output, contents)
}

private func withControl<Result>(
    _ body: (OpaquePointer) throws -> Result
) throws -> Result {
    guard let control = yc_archive_control_create() else {
        throw CocoaError(.fileWriteOutOfSpace)
    }
    defer {
        var value: OpaquePointer? = control
        yc_archive_control_delete(&value)
    }
    return try body(control)
}

private func createArchive(
    source: URL,
    archive: URL,
    encryption: Int32
) throws -> Int32 {
    try withControl { control in
        password.withUnsafeBufferPointer { bytes in
            source.path.withCString { sourcePath in
                archive.path.withCString { archivePath in
                    yc_archive_create(
                        sourcePath,
                        archivePath,
                        bytes.baseAddress,
                        bytes.count,
                        encryption,
                        1,
                        6,
                        UInt64(FileSizeResolver.logicalSize(for: source)),
                        control,
                        nil,
                        nil
                    )
                }
            }
        }
    }
}

private func checkRoundTrip(encryption: Int32) throws {
    let fixture = try makeFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let creationResult = try createArchive(
        source: fixture.source,
        archive: fixture.archive,
        encryption: encryption
    )
    require(
        creationResult == Int32(YC_ARCHIVE_OK),
        "encrypted archive creation"
    )
    try FileManager.default.createDirectory(
        at: fixture.output,
        withIntermediateDirectories: true
    )
    let result = try withControl { control in
        password.withUnsafeBufferPointer { bytes in
            fixture.archive.path.withCString { archivePath in
                fixture.output.path.withCString { outputPath in
                    yc_archive_extract(
                        archivePath,
                        outputPath,
                        bytes.baseAddress,
                        bytes.count,
                        control,
                        nil,
                        nil
                    )
                }
            }
        }
    }
    require(result == Int32(YC_ARCHIVE_OK), "encrypted archive extraction")
    let extracted = fixture.output
        .appendingPathComponent(fixture.source.lastPathComponent)
        .appendingPathComponent("你好-日本語.txt")
    let extractedContents = try String(contentsOf: extracted, encoding: .utf8)
    require(
        extractedContents == fixture.contents,
        "round-trip content and Unicode path"
    )
}

try checkRoundTrip(encryption: Int32(YC_ARCHIVE_ENCRYPTION_AES256))
try checkRoundTrip(encryption: Int32(YC_ARCHIVE_ENCRYPTION_TRADITIONAL))

do {
    let fixture = try makeFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let fixtureCreationResult = try createArchive(
        source: fixture.source,
        archive: fixture.archive,
        encryption: Int32(YC_ARCHIVE_ENCRYPTION_AES256)
    )
    require(
        fixtureCreationResult == Int32(YC_ARCHIVE_OK),
        "AES fixture creation"
    )

    var info = yc_archive_info()
    var unsafeEntry = [CChar](repeating: 0, count: 1024)
    let inspectionResult = fixture.archive.path.withCString {
        yc_archive_inspect($0, &info, &unsafeEntry, unsafeEntry.count)
    }
    require(inspectionResult == Int32(YC_ARCHIVE_OK), "archive inspection")
    require(info.is_encrypted == 1, "encrypted flag")
    require(info.uses_aes == 1, "AES flag")
    require(info.entry_count > 0, "entry count")
    require(info.total_uncompressed_size > 0, "uncompressed size")

    try FileManager.default.createDirectory(
        at: fixture.output,
        withIntermediateDirectories: true
    )
    let wrongPassword = Array("not-the-password".utf8)
    let wrongPasswordResult = try withControl { control in
        wrongPassword.withUnsafeBufferPointer { bytes in
            fixture.archive.path.withCString { archivePath in
                fixture.output.path.withCString { outputPath in
                    yc_archive_extract(
                        archivePath,
                        outputPath,
                        bytes.baseAddress,
                        bytes.count,
                        control,
                        nil,
                        nil
                    )
                }
            }
        }
    }
    require(wrongPasswordResult == -108, "wrong password rejection")
}

do {
    let fixture = try makeFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let cancelledResult = try withControl { control in
        yc_archive_control_cancel(control)
        return password.withUnsafeBufferPointer { bytes in
            fixture.source.path.withCString { sourcePath in
                fixture.archive.path.withCString { archivePath in
                    yc_archive_create(
                        sourcePath,
                        archivePath,
                        bytes.baseAddress,
                        bytes.count,
                        Int32(YC_ARCHIVE_ENCRYPTION_AES256),
                        1,
                        6,
                        UInt64(FileSizeResolver.logicalSize(for: fixture.source)),
                        control,
                        nil,
                        nil
                    )
                }
            }
        }
    }
    require(
        cancelledResult == Int32(YC_ARCHIVE_CANCELLED),
        "cancelled creation"
    )
}

let legacyJSON = """
{
  "outputSuffix": "",
  "revealWhenFinished": false,
  "continueOnError": true,
  "imageFormat": "automatic",
  "videoResolution": "hd",
  "videoOptimizeForNetwork": true,
  "archiveKeepParentFolder": true,
  "archivePreserveMacMetadata": true,
  "extractCreateSubfolder": true
}
""".data(using: .utf8)!
let legacyOptions = try JSONDecoder().decode(
    WorkflowAdvancedOptions.self,
    from: legacyJSON
)
require(
    legacyOptions.archiveEncryption == .none,
    "legacy workflow migration"
)

print("SakuZip encrypted archive checks passed")
