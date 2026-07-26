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

print("YCompressCoreChecks: all checks passed")
