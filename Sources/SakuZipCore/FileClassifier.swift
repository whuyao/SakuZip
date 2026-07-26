import Foundation

public enum FileClassifier {
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "bmp", "gif", "webp"
    ]
    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "webm", "mpeg", "mpg"
    ]
    private static let archiveExtensions: Set<String> = [
        "zip", "tar", "tgz", "gz"
    ]

    public static func kind(for url: URL) -> MediaKind {
        let ext = url.pathExtension.lowercased()
        if imageExtensions.contains(ext) { return .image }
        if videoExtensions.contains(ext) { return .video }
        if archiveExtensions.contains(ext) || url.lastPathComponent.lowercased().hasSuffix(".tar.gz") {
            return .archive
        }
        return .file
    }

    public static func resolvedAction(for url: URL, requested: JobAction) -> JobAction {
        guard requested == .smart else { return requested }
        switch kind(for: url) {
        case .image: return .compressImage
        case .video: return .compressVideo
        case .archive, .file: return .createArchive
        }
    }
}
