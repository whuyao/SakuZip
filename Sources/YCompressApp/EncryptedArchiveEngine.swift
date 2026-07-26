import CYCompressArchive
import Foundation
import YCompressCore

private let ycArchiveOK = Int32(YC_ARCHIVE_OK)
private let ycArchiveCancelled = Int32(YC_ARCHIVE_CANCELLED)
private let ycArchiveUnsafeEntry = Int32(YC_ARCHIVE_UNSAFE_ENTRY)
private let ycArchivePasswordRequired = Int32(YC_ARCHIVE_PASSWORD_REQUIRED)

struct ArchiveInspection: Sendable {
    let totalUncompressedBytes: UInt64
    let entryCount: UInt32
    let isEncrypted: Bool
    let usesAES: Bool
    let usesTraditionalEncryption: Bool
}

enum EncryptedArchiveError: LocalizedError {
    case passwordRequired
    case incorrectPassword
    case unsafeEntry(String)
    case unsupportedEncryption
    case damagedArchive
    case cannotRead
    case cannotWrite
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .passwordRequired:
            L10n.string("此 ZIP 已加密，需要输入密码")
        case .incorrectPassword:
            L10n.string("密码不正确，请重试")
        case .unsafeEntry(let entry):
            L10n.format("压缩包包含不安全路径：%@", entry)
        case .unsupportedEncryption:
            L10n.string("此 ZIP 使用了当前不支持的加密方式")
        case .damagedArchive:
            L10n.string("ZIP 已损坏或完整性校验失败")
        case .cannotRead:
            L10n.string("无法读取 ZIP 文件")
        case .cannotWrite:
            L10n.string("无法写入 ZIP 输出")
        case .operationFailed(let name):
            L10n.format("ZIP 处理失败：%@", name)
        }
    }
}

final class ArchivePassword: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UInt8]

    init(_ value: String) {
        storage = Array(value.utf8)
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.isEmpty
    }

    func withUnsafeBytes<Result>(
        _ body: (UnsafePointer<UInt8>?, Int) throws -> Result
    ) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try storage.withUnsafeBufferPointer { buffer in
            try body(buffer.baseAddress, buffer.count)
        }
    }

    func clear() {
        lock.lock()
        storage.withUnsafeMutableBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                yc_archive_secure_zero(baseAddress, rawBuffer.count)
            }
        }
        storage.removeAll(keepingCapacity: false)
        lock.unlock()
    }

    deinit {
        clear()
    }
}

private final class ArchiveProgressBox: @unchecked Sendable {
    let handler: @Sendable (Double, String) -> Void

    init(handler: @escaping @Sendable (Double, String) -> Void) {
        self.handler = handler
    }
}

private func archiveProgressCallback(
    _ progress: Double,
    _ entryName: UnsafePointer<CChar>?,
    _ userdata: UnsafeMutableRawPointer?
) {
    guard let userdata else { return }
    let box = Unmanaged<ArchiveProgressBox>.fromOpaque(userdata).takeUnretainedValue()
    let entry = entryName.map { String(cString: $0) } ?? ""
    box.handler(progress, entry)
}

enum EncryptedArchiveBridge {
    static func makeControl() throws -> OpaquePointer {
        guard let control = yc_archive_control_create() else {
            throw EncryptedArchiveError.operationFailed("out-of-memory")
        }
        return control
    }

    static func deleteControl(_ control: inout OpaquePointer?) {
        guard control != nil else { return }
        var value = control
        yc_archive_control_delete(&value)
        control = nil
    }

    static func setPaused(_ paused: Bool, control: OpaquePointer?) {
        guard let control else { return }
        yc_archive_control_set_paused(control, paused ? 1 : 0)
    }

    static func cancel(control: OpaquePointer?) {
        guard let control else { return }
        yc_archive_control_cancel(control)
    }

    static func inspect(_ archiveURL: URL) throws -> ArchiveInspection {
        var info = yc_archive_info()
        var unsafeEntry = [CChar](repeating: 0, count: 4096)
        let result = archiveURL.path.withCString { path in
            yc_archive_inspect(
                path,
                &info,
                &unsafeEntry,
                unsafeEntry.count
            )
        }
        if result != ycArchiveOK {
            let entry = unsafeEntry.first == 0 ? "" : String(cString: unsafeEntry)
            throw error(for: result, unsafeEntry: entry)
        }
        return ArchiveInspection(
            totalUncompressedBytes: info.total_uncompressed_size,
            entryCount: info.entry_count,
            isEncrypted: info.is_encrypted != 0,
            usesAES: info.uses_aes != 0,
            usesTraditionalEncryption: info.uses_traditional_encryption != 0
        )
    }

    static func create(
        sourceURL: URL,
        destinationURL: URL,
        password: ArchivePassword,
        encryption: ArchiveEncryptionMode,
        keepParentFolder: Bool,
        compressionLevel: Int32,
        totalUncompressedBytes: UInt64,
        control: OpaquePointer,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        let box = ArchiveProgressBox(handler: progress)
        let retainedBox = Unmanaged.passRetained(box)
        let userdata = retainedBox.toOpaque()
        defer { retainedBox.release() }

        let result = await Task.detached(priority: .userInitiated) {
            password.withUnsafeBytes { passwordBytes, passwordLength in
                sourceURL.path.withCString { sourcePath in
                    destinationURL.path.withCString { destinationPath in
                        yc_archive_create(
                            sourcePath,
                            destinationPath,
                            passwordBytes,
                            passwordLength,
                            encryption == .aes256
                                ? Int32(YC_ARCHIVE_ENCRYPTION_AES256)
                                : Int32(YC_ARCHIVE_ENCRYPTION_TRADITIONAL),
                            keepParentFolder ? 1 : 0,
                            compressionLevel,
                            totalUncompressedBytes,
                            control,
                            archiveProgressCallback,
                            userdata
                        )
                    }
                }
            }
        }.value
        if result != ycArchiveOK {
            throw error(for: result)
        }
    }

    static func extract(
        archiveURL: URL,
        destinationURL: URL,
        password: ArchivePassword?,
        control: OpaquePointer,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        let box = ArchiveProgressBox(handler: progress)
        let retainedBox = Unmanaged.passRetained(box)
        let userdata = retainedBox.toOpaque()
        defer { retainedBox.release() }

        let result = await Task.detached(priority: .userInitiated) {
            func run(
                passwordBytes: UnsafePointer<UInt8>?,
                passwordLength: Int
            ) -> Int32 {
                archiveURL.path.withCString { archivePath in
                    destinationURL.path.withCString { destinationPath in
                        yc_archive_extract(
                            archivePath,
                            destinationPath,
                            passwordBytes,
                            passwordLength,
                            control,
                            archiveProgressCallback,
                            userdata
                        )
                    }
                }
            }
            if let password {
                return password.withUnsafeBytes(run)
            }
            return run(passwordBytes: nil, passwordLength: 0)
        }.value
        if result != ycArchiveOK {
            throw error(for: result)
        }
    }

    private static func error(
        for code: Int32,
        unsafeEntry: String = ""
    ) -> Error {
        switch code {
        case ycArchiveCancelled:
            return CancellationError()
        case ycArchivePasswordRequired:
            return EncryptedArchiveError.passwordRequired
        case ycArchiveUnsafeEntry:
            return EncryptedArchiveError.unsafeEntry(unsafeEntry)
        case -108:
            return EncryptedArchiveError.incorrectPassword
        case -109:
            return EncryptedArchiveError.unsupportedEncryption
        case -103, -105, -106:
            return EncryptedArchiveError.damagedArchive
        case -111, -115:
            return EncryptedArchiveError.cannotRead
        case -116:
            return EncryptedArchiveError.cannotWrite
        case -107:
            return EncryptedArchiveError.unsafeEntry(unsafeEntry)
        default:
            let name = yc_archive_error_name(code).map(String.init(cString:))
                ?? "error-\(code)"
            return EncryptedArchiveError.operationFailed(name)
        }
    }
}
