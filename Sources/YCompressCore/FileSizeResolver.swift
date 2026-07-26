import Foundation

public enum FileSizeResolver {
    public static func logicalSize(for url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            let keys: Set<URLResourceKey> = [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .totalFileAllocatedSizeKey
            ]
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [],
                errorHandler: { _, _ in true }
            ) else {
                return 0
            }
            var total: Int64 = 0
            for case let itemURL as URL in enumerator {
                guard let values = try? itemURL.resourceValues(forKeys: keys),
                      values.isRegularFile == true,
                      values.isSymbolicLink != true else {
                    continue
                }
                total += Int64(values.fileSize ?? values.totalFileAllocatedSize ?? 0)
            }
            return total
        }

        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = (attributes[.size] as? NSNumber)?.int64Value,
           size > 0 {
            return size
        }

        let values = try? url.resourceValues(
            forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey]
        )
        return Int64(values?.fileSize ?? values?.totalFileAllocatedSize ?? 0)
    }
}
