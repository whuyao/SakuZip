import Foundation

public enum FileSizeResolver {
    public static func logicalSize(for url: URL) -> Int64 {
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
