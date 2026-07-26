import Foundation
import YCompressCore

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

let sourceFile = URL(fileURLWithPath: "/tmp/YCompress Input/photo.jpg")
let sourceFolder = URL(
    fileURLWithPath: "/tmp/YCompress Input/Folder",
    isDirectory: true
)
check(
    OutputDirectoryResolver.defaultDirectory(for: [sourceFile])?.path
        == "/tmp/YCompress Input",
    "file output should default to its source directory"
)
check(
    OutputDirectoryResolver.defaultDirectory(for: [sourceFolder])?.path
        == "/tmp/YCompress Input",
    "folder output should default to its parent directory"
)
check(
    OutputDirectoryResolver.defaultDirectory(for: []) == nil,
    "empty input should not change the output directory"
)

print("YCompressCoreChecks: all checks passed")
