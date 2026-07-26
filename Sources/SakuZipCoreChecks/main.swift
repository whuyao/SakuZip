import Foundation
import SakuZipCore

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
}

check(
    FileClassifier.kind(for: URL(fileURLWithPath: "/tmp/photo.HEIC")) == .image,
    "HEIC should be classified as image"
)
check(
    FileClassifier.kind(for: URL(fileURLWithPath: "/tmp/movie.mov")) == .video,
    "MOV should be classified as video"
)
check(
    FileClassifier.kind(for: URL(fileURLWithPath: "/tmp/files.tar.gz")) == .archive,
    "tar.gz should be classified as archive"
)
check(!PathSafety.isSafeArchiveEntry("../escape.txt"), "parent traversal must be rejected")
check(!PathSafety.isSafeArchiveEntry("/etc/passwd"), "absolute path must be rejected")
check(PathSafety.isSafeArchiveEntry("folder/file.txt"), "normal relative path must pass")

let directory = URL(fileURLWithPath: "/tmp/output")
let used = Set(["/tmp/output/photo.jpg", "/tmp/output/photo 2.jpg"])
let unique = PathSafety.uniqueURL(
    directory: directory,
    baseName: "photo",
    pathExtension: "jpg",
    fileExists: { used.contains($0) }
)
check(unique.path == "/tmp/output/photo 3.jpg", "unique naming should increment suffix")

let builtInIDs = Set(WorkflowPreset.builtIns.map(\.id))
check(
    builtInIDs.count == WorkflowPreset.builtIns.count,
    "built-in workflow IDs must be stable and unique"
)
check(
    WorkflowPreset.builtIns[1].advanced.imageFormat == .jpeg,
    "web image workflow should default to JPEG"
)
check(
    WorkflowPreset.builtIns[2].advanced.videoResolution == .compact,
    "sharing video workflow should default to compact resolution"
)
check(
    CompressionQuality.high.videoTargetSizeRatio
        > CompressionQuality.balanced.videoTargetSizeRatio,
    "high video quality should allow a larger output than balanced"
)
check(
    CompressionQuality.balanced.videoTargetSizeRatio
        > CompressionQuality.compact.videoTargetSizeRatio,
    "compact video quality should target the smallest output"
)
check(
    CompressionQuality.high.videoTargetSizeRatio < 1,
    "every video quality must target an output smaller than the source"
)
check(
    AppLanguage.allCases.map(\.rawValue) == ["system", "zh-Hans", "en", "ja"],
    "language choices should remain stable for persisted settings"
)
check(
    AppLanguage(rawValue: "system") == .system,
    "the default persisted language should resolve to system"
)

let legacyDefaultsDomain =
    "net.urbancomp.SakuZipCoreChecks.legacy.\(UUID().uuidString)"
let currentDefaultsDomain =
    "net.urbancomp.SakuZipCoreChecks.current.\(UUID().uuidString)"
let legacyDefaults = UserDefaults(suiteName: legacyDefaultsDomain)!
let currentDefaults = UserDefaults(suiteName: currentDefaultsDomain)!
defer {
    UserDefaults.standard.removePersistentDomain(forName: legacyDefaultsDomain)
    UserDefaults.standard.removePersistentDomain(forName: currentDefaultsDomain)
}
legacyDefaults.set(AppLanguage.japanese.rawValue, forKey: L10n.languageStorageKey)
legacyDefaults.set(Data([0x53, 0x5A]), forKey: "workflowPresetsV2")
LegacySettingsMigrator.migrateIfNeeded(
    from: legacyDefaultsDomain,
    to: currentDefaults
)
check(
    currentDefaults.string(forKey: L10n.languageStorageKey)
        == AppLanguage.japanese.rawValue,
    "the renamed app should migrate the saved language"
)
check(
    currentDefaults.data(forKey: "workflowPresetsV2") == Data([0x53, 0x5A]),
    "the renamed app should migrate saved workflows"
)
legacyDefaults.set(AppLanguage.english.rawValue, forKey: L10n.languageStorageKey)
LegacySettingsMigrator.migrateIfNeeded(
    from: legacyDefaultsDomain,
    to: currentDefaults
)
check(
    currentDefaults.string(forKey: L10n.languageStorageKey)
        == AppLanguage.japanese.rawValue,
    "legacy settings migration should run only once"
)

let legacyPresetJSON = """
{
  "id": "89E269D7-0C6F-491A-A1E6-870CFF4A5D35",
  "name": "Legacy",
  "detail": "Legacy workflow",
  "symbol": "gear",
  "action": "compressImage",
  "quality": "balanced",
  "maxImageDimension": 2048,
  "isBuiltIn": false
}
"""
let migratedPreset = try JSONDecoder().decode(
    WorkflowPreset.self,
    from: Data(legacyPresetJSON.utf8)
)
check(
    migratedPreset.advanced.imageMaxDimension == 2048,
    "legacy workflows should migrate their image dimension"
)

let sourceFile = URL(fileURLWithPath: "/tmp/SakuZip Input/photo.jpg")
let sourceFolder = URL(
    fileURLWithPath: "/tmp/SakuZip Input/Folder",
    isDirectory: true
)
check(
    OutputDirectoryResolver.defaultDirectory(for: [sourceFile])?.path
        == "/tmp/SakuZip Input",
    "file output should default to its source directory"
)
check(
    OutputDirectoryResolver.defaultDirectory(for: [sourceFolder])?.path
        == "/tmp/SakuZip Input",
    "folder output should default to its parent directory"
)
check(
    OutputDirectoryResolver.defaultDirectory(for: []) == nil,
    "empty input should not change the output directory"
)

let sizeCheckDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("SakuZipCoreChecks-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(
    at: sizeCheckDirectory,
    withIntermediateDirectories: true
)
defer {
    try? FileManager.default.removeItem(at: sizeCheckDirectory)
}
let knownSizeFile = sizeCheckDirectory.appendingPathComponent("known-size.bin")
let knownSizeData = Data(repeating: 0x59, count: 4_321)
try knownSizeData.write(to: knownSizeFile)
check(
    FileSizeResolver.logicalSize(for: knownSizeFile) == Int64(knownSizeData.count),
    "logical source size should be read from the current file state"
)
let emptyFile = sizeCheckDirectory.appendingPathComponent("empty.bin")
FileManager.default.createFile(atPath: emptyFile.path, contents: Data())
check(
    FileSizeResolver.logicalSize(for: emptyFile) == 0,
    "empty files should retain a zero logical size"
)
let hydratedData = Data(repeating: 0x43, count: 8_765)
try hydratedData.write(to: emptyFile)
check(
    FileSizeResolver.logicalSize(for: emptyFile) == Int64(hydratedData.count),
    "source size should refresh after a placeholder file is hydrated"
)

print("SakuZipCoreChecks: all checks passed")
