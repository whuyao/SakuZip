import Foundation

public enum OutputDirectoryResolver {
    public static func defaultDirectory(for urls: [URL]) -> URL? {
        guard let firstURL = urls.first else { return nil }
        return firstURL.standardizedFileURL.deletingLastPathComponent()
    }
}
