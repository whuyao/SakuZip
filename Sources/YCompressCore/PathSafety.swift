import Foundation

public enum PathSafety {
    public static func isSafeArchiveEntry(_ entry: String) -> Bool {
        let normalized = entry.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.hasPrefix("/") else { return false }
        guard !normalized.hasPrefix("~") else { return false }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        return !components.contains("..")
    }

    public static func uniqueURL(
        directory: URL,
        baseName: String,
        pathExtension: String,
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> URL {
        let cleanBase = baseName.isEmpty ? "YCompress" : baseName
        var candidate = directory
            .appendingPathComponent(cleanBase)
            .appendingPathExtension(pathExtension)
        var index = 2
        while fileExists(candidate.path) {
            candidate = directory
                .appendingPathComponent("\(cleanBase) \(index)")
                .appendingPathExtension(pathExtension)
            index += 1
        }
        return candidate
    }
}
