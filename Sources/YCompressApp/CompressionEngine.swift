import AVFoundation
import CoreGraphics
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers
import YCompressCore

enum CompressionError: LocalizedError {
    case unsupported(String)
    case invalidImage
    case cannotCreateOutput
    case toolFailed(String)
    case unsafeArchiveEntry(String)
    case exportFailed(String)
    case videoAlreadyEfficient
    case outputNotSmaller

    var errorDescription: String? {
        switch self {
        case .unsupported(let value): L10n.format("暂不支持：%@", value)
        case .invalidImage: L10n.string("无法读取图片")
        case .cannotCreateOutput: L10n.string("无法创建输出文件")
        case .toolFailed(let message): message
        case .unsafeArchiveEntry(let entry):
            L10n.format("压缩包包含不安全路径：%@", entry)
        case .exportFailed(let message):
            L10n.format("视频导出失败：%@", message)
        case .videoAlreadyEfficient:
            L10n.string(
                "源视频已高度压缩，所选设置预计无法继续减小；请尝试“更小体积”或更低分辨率"
            )
        case .outputNotSmaller:
            L10n.string("输出文件没有小于源视频，已自动删除无效结果")
        }
    }
}

typealias CompressionProgressHandler = @MainActor @Sendable (Double, String) -> Void

private struct VideoPresetEstimate {
    let preset: String
    let bytes: Int64
}

actor CompressionEngine {
    private var activeExportSession: AVAssetExportSession?
    private var activeProcess: Process?
    private var activeArchiveControl: OpaquePointer?

    func cancelCurrent() {
        activeExportSession?.cancelExport()
        if activeProcess?.isRunning == true {
            activeProcess?.terminate()
        }
        EncryptedArchiveBridge.cancel(control: activeArchiveControl)
    }

    func setPaused(_ paused: Bool) {
        EncryptedArchiveBridge.setPaused(paused, control: activeArchiveControl)
    }

    func inspectArchive(_ url: URL) throws -> ArchiveInspection {
        guard url.lastPathComponent.lowercased().hasSuffix(".zip") else {
            return ArchiveInspection(
                totalUncompressedBytes: 0,
                entryCount: 0,
                isEncrypted: false,
                usesAES: false,
                usesTraditionalEncryption: false
            )
        }
        return try EncryptedArchiveBridge.inspect(url)
    }

    func process(
        url: URL,
        options: CompressionOptions,
        archivePassword: ArchivePassword? = nil,
        progress: @escaping CompressionProgressHandler
    ) async throws -> URL {
        await progress(0.02, L10n.string("正在准备"))
        try FileManager.default.createDirectory(
            at: options.outputDirectory,
            withIntermediateDirectories: true
        )
        let action = FileClassifier.resolvedAction(for: url, requested: options.action)
        switch action {
        case .compressImage:
            return try await compressImage(url, options: options, progress: progress)
        case .compressVideo:
            return try await compressVideo(url, options: options, progress: progress)
        case .createArchive:
            return try await createArchive(
                url,
                options: options,
                archivePassword: archivePassword,
                progress: progress
            )
        case .extractArchive:
            return try await extractArchive(
                url,
                options: options,
                archivePassword: archivePassword,
                progress: progress
            )
        case .smart:
            throw CompressionError.unsupported(L10n.string("无法解析智能工作流"))
        }
    }

    private func compressImage(
        _ sourceURL: URL,
        options: CompressionOptions,
        progress: @escaping CompressionProgressHandler
    ) async throws -> URL {
        await progress(0.08, L10n.string("正在读取图片"))
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw CompressionError.invalidImage
        }

        await progress(0.30, L10n.string("正在缩放图片"))
        try Task.checkCancellation()
        let image: CGImage?
        if let maxDimension = options.advanced.imageMaxDimension ?? options.maxImageDimension {
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
            ]
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
        } else {
            image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        guard let image else { throw CompressionError.invalidImage }

        await progress(0.58, L10n.string("正在准备输出"))
        try Task.checkCancellation()
        let preservesAlpha = image.alphaInfo == .premultipliedFirst
            || image.alphaInfo == .premultipliedLast
            || image.alphaInfo == .first
            || image.alphaInfo == .last
        let fileExtension: String
        let destinationType: String
        switch options.advanced.imageFormat {
        case .automatic:
            fileExtension = preservesAlpha ? "png" : "jpg"
            destinationType = preservesAlpha ? UTType.png.identifier : UTType.jpeg.identifier
        case .jpeg:
            fileExtension = "jpg"
            destinationType = UTType.jpeg.identifier
        case .png:
            fileExtension = "png"
            destinationType = UTType.png.identifier
        case .heic:
            fileExtension = "heic"
            destinationType = UTType.heic.identifier
        }
        let destinationURL = PathSafety.uniqueURL(
            directory: options.outputDirectory,
            baseName: outputBaseName(
                for: sourceURL,
                requestedSuffix: options.advanced.outputSuffix,
                defaultSuffix: "-compressed"
            ),
            pathExtension: fileExtension
        )
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            destinationType as CFString,
            1,
            nil
        ) else {
            throw CompressionError.cannotCreateOutput
        }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: options.quality.imageQuality,
            kCGImagePropertyOrientation: 1
        ]
        await progress(0.78, L10n.string("正在写入图片"))
        try Task.checkCancellation()
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.cannotCreateOutput
        }
        await progress(0.98, L10n.string("正在完成"))
        return destinationURL
    }

    private func compressVideo(
        _ sourceURL: URL,
        options: CompressionOptions,
        progress: @escaping CompressionProgressHandler
    ) async throws -> URL {
        await progress(0.06, L10n.string("正在读取视频"))
        let asset = AVURLAsset(url: sourceURL)
        let destinationURL = PathSafety.uniqueURL(
            directory: options.outputDirectory,
            baseName: outputBaseName(
                for: sourceURL,
                requestedSuffix: options.advanced.outputSuffix,
                defaultSuffix: "-compressed"
            ),
            pathExtension: "mp4"
        )
        let sourceBytes = try fileSize(of: sourceURL)
        guard sourceBytes > 0 else {
            throw CompressionError.unsupported(L10n.string("无法读取源视频大小"))
        }

        await progress(0.08, L10n.string("正在分析源视频码率"))
        let targetBytes = Int64(
            Double(sourceBytes) * options.quality.videoTargetSizeRatio
        )
        let selection = try await selectVideoPreset(
            asset: asset,
            destinationURL: destinationURL,
            resolution: options.advanced.videoResolution,
            sourceBytes: sourceBytes,
            targetBytes: targetBytes
        )
        try Task.checkCancellation()

        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: selection.preset
        ) else {
            throw CompressionError.unsupported(
                L10n.string("此视频编码无法使用所选预设")
            )
        }
        session.outputURL = destinationURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = options.advanced.videoOptimizeForNetwork
        activeExportSession = session
        defer {
            if activeExportSession === session {
                activeExportSession = nil
            }
            if session.status != .completed {
                try? FileManager.default.removeItem(at: destinationURL)
            }
        }
        let expectedSaving = max(
            0,
            Int((1 - Double(selection.bytes) / Double(sourceBytes)) * 100)
        )
        await progress(0.10, L10n.format("预计节省约 %d%%", expectedSaving))
        session.exportAsynchronously(completionHandler: {})
        exportLoop: while true {
            if Task.isCancelled {
                session.cancelExport()
                throw CancellationError()
            }
            let value = 0.10 + Double(session.progress) * 0.88
            await progress(min(value, 0.98), L10n.string("正在压缩视频"))
            switch session.status {
            case .unknown, .waiting, .exporting:
                try await Task.sleep(nanoseconds: 150_000_000)
            default:
                break exportLoop
            }
        }
        switch session.status {
        case .completed:
            let outputBytes = try fileSize(of: destinationURL)
            guard outputBytes < sourceBytes else {
                try? FileManager.default.removeItem(at: destinationURL)
                throw CompressionError.outputNotSmaller
            }
            await progress(0.98, L10n.string("正在完成"))
            return destinationURL
        case .cancelled:
            throw CancellationError()
        default:
            throw CompressionError.exportFailed(
                session.error?.localizedDescription ?? L10n.string("未知错误")
            )
        }
    }

    private func selectVideoPreset(
        asset: AVAsset,
        destinationURL: URL,
        resolution: VideoResolution,
        sourceBytes: Int64,
        targetBytes: Int64
    ) async throws -> VideoPresetEstimate {
        var estimates: [VideoPresetEstimate] = []
        for preset in videoPresetCandidates(for: resolution) {
            try Task.checkCancellation()
            guard let session = AVAssetExportSession(asset: asset, presetName: preset),
                  session.supportedFileTypes.contains(.mp4) else {
                continue
            }
            session.outputURL = destinationURL
            session.outputFileType = .mp4
            let bytes: Int64
            do {
                bytes = try await estimatedOutputLength(for: session)
            } catch {
                continue
            }
            if bytes > 0 {
                estimates.append(.init(preset: preset, bytes: bytes))
            }
        }

        if let bestWithinTarget = estimates
            .filter({ $0.bytes <= targetBytes })
            .max(by: { $0.bytes < $1.bytes }) {
            return bestWithinTarget
        }
        if let bestReduction = estimates
            .filter({ $0.bytes < sourceBytes })
            .max(by: { $0.bytes < $1.bytes }) {
            return bestReduction
        }
        throw CompressionError.videoAlreadyEfficient
    }

    private func videoPresetCandidates(for resolution: VideoResolution) -> [String] {
        let presets: [String]
        switch resolution {
        case .source:
            presets = [
                AVAssetExportPresetHEVCHighestQuality,
                AVAssetExportPresetHighestQuality
            ]
        case .fullHD:
            presets = [
                AVAssetExportPresetHEVC1920x1080,
                AVAssetExportPreset1920x1080,
                AVAssetExportPreset1280x720,
                AVAssetExportPreset960x540,
                AVAssetExportPresetMediumQuality,
                AVAssetExportPresetLowQuality
            ]
        case .hd:
            presets = [
                AVAssetExportPreset1280x720,
                AVAssetExportPreset960x540,
                AVAssetExportPresetMediumQuality,
                AVAssetExportPresetLowQuality
            ]
        case .compact:
            presets = [
                AVAssetExportPreset960x540,
                AVAssetExportPreset640x480,
                AVAssetExportPresetMediumQuality,
                AVAssetExportPresetLowQuality
            ]
        }
        var seen = Set<String>()
        return presets.filter { seen.insert($0).inserted }
    }

    private func estimatedOutputLength(
        for session: AVAssetExportSession
    ) async throws -> Int64 {
        try await withCheckedThrowingContinuation { continuation in
            session.estimateOutputFileLength { length, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: length)
                }
            }
        }
    }

    private func fileSize(of url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func createArchive(
        _ sourceURL: URL,
        options: CompressionOptions,
        archivePassword: ArchivePassword?,
        progress: @escaping CompressionProgressHandler
    ) async throws -> URL {
        await progress(0.08, L10n.string("正在准备 ZIP"))
        let destinationURL = PathSafety.uniqueURL(
            directory: options.outputDirectory,
            baseName: outputBaseName(
                for: sourceURL,
                requestedSuffix: options.advanced.outputSuffix,
                defaultSuffix: ""
            ),
            pathExtension: "zip"
        )
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)
        if options.advanced.archiveEncryption.requiresPassword {
            guard let archivePassword, !archivePassword.isEmpty else {
                throw EncryptedArchiveError.passwordRequired
            }
            let partialURL = options.outputDirectory.appendingPathComponent(
                ".ycompress-\(UUID().uuidString).partial"
            )
            let totalBytes = UInt64(max(FileSizeResolver.logicalSize(for: sourceURL), 1))
            await progress(
                0.12,
                options.advanced.archiveEncryption == .aes256
                    ? L10n.string("正在创建 AES-256 加密 ZIP")
                    : L10n.string("正在创建兼容加密 ZIP")
            )
            var control: OpaquePointer?
            do {
                control = try EncryptedArchiveBridge.makeControl()
                activeArchiveControl = control
                try await EncryptedArchiveBridge.create(
                    sourceURL: sourceURL,
                    destinationURL: partialURL,
                    password: archivePassword,
                    encryption: options.advanced.archiveEncryption,
                    keepParentFolder: isDirectory.boolValue
                        && options.advanced.archiveKeepParentFolder,
                    compressionLevel: archiveCompressionLevel(for: options.quality),
                    totalUncompressedBytes: totalBytes,
                    control: control!,
                    progress: { value, entry in
                        Task { @MainActor in
                            let detail = entry.isEmpty
                                ? L10n.string("正在创建加密 ZIP")
                                : L10n.format("正在加密：%@", entry)
                            progress(0.12 + value * 0.84, detail)
                        }
                    }
                )
                try Task.checkCancellation()
                try FileManager.default.moveItem(at: partialURL, to: destinationURL)
                activeArchiveControl = nil
                EncryptedArchiveBridge.deleteControl(&control)
                await progress(0.98, L10n.string("正在完成"))
                return destinationURL
            } catch {
                activeArchiveControl = nil
                EncryptedArchiveBridge.deleteControl(&control)
                try? FileManager.default.removeItem(at: partialURL)
                try? FileManager.default.removeItem(at: destinationURL)
                throw error
            }
        }
        var arguments = ["-c", "-k"]
        if options.advanced.archivePreserveMacMetadata {
            arguments.append("--sequesterRsrc")
        }
        if isDirectory.boolValue && options.advanced.archiveKeepParentFolder {
            arguments.append("--keepParent")
        }
        arguments.append(contentsOf: [sourceURL.path, destinationURL.path])
        await progress(0.25, L10n.string("正在创建 ZIP"))
        try Task.checkCancellation()
        do {
            _ = try await runTool(
                "/usr/bin/ditto",
                arguments: arguments
            )
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
        await progress(0.98, L10n.string("正在完成"))
        return destinationURL
    }

    private func extractArchive(
        _ sourceURL: URL,
        options: CompressionOptions,
        archivePassword: ArchivePassword?,
        progress: @escaping CompressionProgressHandler
    ) async throws -> URL {
        await progress(0.06, L10n.string("正在读取压缩包"))
        guard FileClassifier.kind(for: sourceURL) == .archive else {
            throw CompressionError.unsupported(sourceURL.pathExtension)
        }
        let destinationURL: URL
        if options.advanced.extractCreateSubfolder {
            destinationURL = uniqueDirectory(
                parent: options.outputDirectory,
                name: outputBaseName(
                    for: sourceURL,
                    requestedSuffix: options.advanced.outputSuffix,
                    defaultSuffix: ""
                )
            )
        } else {
            destinationURL = options.outputDirectory
        }
        let lowerName = sourceURL.lastPathComponent.lowercased()
        if lowerName.hasSuffix(".zip") {
            let inspection = try EncryptedArchiveBridge.inspect(sourceURL)
            if inspection.isEncrypted {
                guard let archivePassword, !archivePassword.isEmpty else {
                    throw EncryptedArchiveError.passwordRequired
                }
                return try await extractEncryptedZIP(
                    sourceURL,
                    destinationURL: destinationURL,
                    outputDirectory: options.outputDirectory,
                    createSubfolder: options.advanced.extractCreateSubfolder,
                    password: archivePassword,
                    progress: progress
                )
            }
        }
        let entries: String
        await progress(0.18, L10n.string("正在检查文件列表"))
        try Task.checkCancellation()
        if lowerName.hasSuffix(".zip") {
            entries = try await runTool("/usr/bin/unzip", arguments: ["-Z1", sourceURL.path])
        } else if lowerName.hasSuffix(".tar") || lowerName.hasSuffix(".tgz") || lowerName.hasSuffix(".tar.gz") {
            entries = try await runTool("/usr/bin/tar", arguments: ["-tf", sourceURL.path])
        } else {
            throw CompressionError.unsupported(sourceURL.pathExtension)
        }

        for entry in entries.split(whereSeparator: \.isNewline).map(String.init) {
            guard PathSafety.isSafeArchiveEntry(entry) else {
                throw CompressionError.unsafeArchiveEntry(entry)
            }
        }
        await progress(0.42, L10n.string("安全检查通过"))
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true
        )
        await progress(0.58, L10n.string("正在解压"))
        try Task.checkCancellation()
        do {
            if lowerName.hasSuffix(".zip") {
                _ = try await runTool(
                    "/usr/bin/ditto",
                    arguments: ["-x", "-k", sourceURL.path, destinationURL.path]
                )
            } else {
                _ = try await runTool(
                    "/usr/bin/tar",
                    arguments: ["-xf", sourceURL.path, "-C", destinationURL.path]
                )
            }
        } catch {
            if options.advanced.extractCreateSubfolder {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            throw error
        }
        await progress(0.98, L10n.string("正在完成"))
        return destinationURL
    }

    private func extractEncryptedZIP(
        _ sourceURL: URL,
        destinationURL: URL,
        outputDirectory: URL,
        createSubfolder: Bool,
        password: ArchivePassword,
        progress: @escaping CompressionProgressHandler
    ) async throws -> URL {
        let stagingURL = outputDirectory.appendingPathComponent(
            ".ycompress-extract-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: stagingURL,
            withIntermediateDirectories: true
        )
        await progress(0.18, L10n.string("加密 ZIP 安全检查通过"))
        var control: OpaquePointer?
        do {
            control = try EncryptedArchiveBridge.makeControl()
            activeArchiveControl = control
            try await EncryptedArchiveBridge.extract(
                archiveURL: sourceURL,
                destinationURL: stagingURL,
                password: password,
                control: control!,
                progress: { value, entry in
                    Task { @MainActor in
                        let detail = entry.isEmpty
                            ? L10n.string("正在解密 ZIP")
                            : L10n.format("正在解密：%@", entry)
                        progress(0.20 + value * 0.76, detail)
                    }
                }
            )
            try Task.checkCancellation()
            let committedURL: URL
            if createSubfolder {
                try FileManager.default.moveItem(at: stagingURL, to: destinationURL)
                committedURL = destinationURL
            } else {
                try commitStagingContents(
                    from: stagingURL,
                    to: outputDirectory
                )
                try FileManager.default.removeItem(at: stagingURL)
                committedURL = outputDirectory
            }
            activeArchiveControl = nil
            EncryptedArchiveBridge.deleteControl(&control)
            await progress(0.98, L10n.string("正在完成"))
            return committedURL
        } catch {
            activeArchiveControl = nil
            EncryptedArchiveBridge.deleteControl(&control)
            try? FileManager.default.removeItem(at: stagingURL)
            if createSubfolder {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            throw error
        }
    }

    private func commitStagingContents(from stagingURL: URL, to destinationURL: URL) throws {
        let items = try FileManager.default.contentsOfDirectory(
            at: stagingURL,
            includingPropertiesForKeys: nil
        )
        for item in items {
            let destination = destinationURL.appendingPathComponent(
                item.lastPathComponent,
                isDirectory: item.hasDirectoryPath
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: item, to: destination)
        }
    }

    private func archiveCompressionLevel(for quality: CompressionQuality) -> Int32 {
        switch quality {
        case .high, .balanced: 6
        case .compact: 9
        }
    }

    private func outputBaseName(
        for sourceURL: URL,
        requestedSuffix: String,
        defaultSuffix: String
    ) -> String {
        let suffix = requestedSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        return sourceURL.deletingPathExtension().lastPathComponent
            + (suffix.isEmpty ? defaultSuffix : suffix)
    }

    private func uniqueDirectory(parent: URL, name: String) -> URL {
        var candidate = parent.appendingPathComponent(name, isDirectory: true)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(name) \(index)", isDirectory: true)
            index += 1
        }
        return candidate
    }

    private func runTool(_ executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        activeProcess = process
        defer {
            if activeProcess === process {
                activeProcess = nil
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
                let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0 {
                    continuation.resume(returning: String(decoding: outputData, as: UTF8.self))
                } else if process.terminationReason == .uncaughtSignal,
                          process.terminationStatus == SIGTERM {
                    continuation.resume(throwing: CancellationError())
                } else {
                    let message = String(decoding: errorData, as: UTF8.self)
                    continuation.resume(
                        throwing: CompressionError.toolFailed(
                            message.isEmpty
                                ? L10n.string("系统工具执行失败")
                                : message
                        )
                    )
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
