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

    var errorDescription: String? {
        switch self {
        case .unsupported(let value): "暂不支持：\(value)"
        case .invalidImage: "无法读取图片"
        case .cannotCreateOutput: "无法创建输出文件"
        case .toolFailed(let message): message
        case .unsafeArchiveEntry(let entry): "压缩包包含不安全路径：\(entry)"
        case .exportFailed(let message): "视频导出失败：\(message)"
        }
    }
}

typealias CompressionProgressHandler = @MainActor @Sendable (Double, String) -> Void

actor CompressionEngine {
    private var activeExportSession: AVAssetExportSession?
    private var activeProcess: Process?

    func cancelCurrent() {
        activeExportSession?.cancelExport()
        if activeProcess?.isRunning == true {
            activeProcess?.terminate()
        }
    }

    func process(
        url: URL,
        options: CompressionOptions,
        progress: @escaping CompressionProgressHandler
    ) async throws -> URL {
        await progress(0.02, "正在准备")
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
            return try await createArchive(url, options: options, progress: progress)
        case .extractArchive:
            return try await extractArchive(url, options: options, progress: progress)
        case .smart:
            throw CompressionError.unsupported("无法解析智能工作流")
        }
    }

    private func compressImage(
        _ sourceURL: URL,
        options: CompressionOptions,
        progress: @escaping CompressionProgressHandler
    ) async throws -> URL {
        await progress(0.08, "正在读取图片")
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw CompressionError.invalidImage
        }

        await progress(0.30, "正在缩放图片")
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

        await progress(0.58, "正在准备输出")
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
        await progress(0.78, "正在写入图片")
        try Task.checkCancellation()
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.cannotCreateOutput
        }
        await progress(0.98, "正在完成")
        return destinationURL
    }

    private func compressVideo(
        _ sourceURL: URL,
        options: CompressionOptions,
        progress: @escaping CompressionProgressHandler
    ) async throws -> URL {
        await progress(0.06, "正在读取视频")
        let asset = AVURLAsset(url: sourceURL)
        let preset: String
        switch options.advanced.videoResolution {
        case .source:
            preset = AVAssetExportPresetHighestQuality
        case .fullHD:
            preset = AVAssetExportPreset1920x1080
        case .hd:
            preset = AVAssetExportPreset1280x720
        case .compact:
            preset = AVAssetExportPreset960x540
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw CompressionError.unsupported("此视频编码无法使用所选预设")
        }
        let destinationURL = PathSafety.uniqueURL(
            directory: options.outputDirectory,
            baseName: outputBaseName(
                for: sourceURL,
                requestedSuffix: options.advanced.outputSuffix,
                defaultSuffix: "-compressed"
            ),
            pathExtension: "mp4"
        )
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
        await progress(0.10, "正在启动视频压缩")
        session.exportAsynchronously(completionHandler: {})
        exportLoop: while true {
            if Task.isCancelled {
                session.cancelExport()
                throw CancellationError()
            }
            let value = 0.10 + Double(session.progress) * 0.88
            await progress(min(value, 0.98), "正在压缩视频")
            switch session.status {
            case .unknown, .waiting, .exporting:
                try await Task.sleep(nanoseconds: 150_000_000)
            default:
                break exportLoop
            }
        }
        switch session.status {
        case .completed:
            await progress(0.98, "正在完成")
            return destinationURL
        case .cancelled:
            throw CancellationError()
        default:
            throw CompressionError.exportFailed(session.error?.localizedDescription ?? "未知错误")
        }
    }

    private func createArchive(
        _ sourceURL: URL,
        options: CompressionOptions,
        progress: @escaping CompressionProgressHandler
    ) async throws -> URL {
        await progress(0.08, "正在准备 ZIP")
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
        var arguments = ["-c", "-k"]
        if options.advanced.archivePreserveMacMetadata {
            arguments.append("--sequesterRsrc")
        }
        if isDirectory.boolValue && options.advanced.archiveKeepParentFolder {
            arguments.append("--keepParent")
        }
        arguments.append(contentsOf: [sourceURL.path, destinationURL.path])
        await progress(0.25, "正在创建 ZIP")
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
        await progress(0.98, "正在完成")
        return destinationURL
    }

    private func extractArchive(
        _ sourceURL: URL,
        options: CompressionOptions,
        progress: @escaping CompressionProgressHandler
    ) async throws -> URL {
        await progress(0.06, "正在读取压缩包")
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
        let entries: String
        await progress(0.18, "正在检查文件列表")
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
        await progress(0.42, "安全检查通过")
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true
        )
        await progress(0.58, "正在解压")
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
        await progress(0.98, "正在完成")
        return destinationURL
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
                            message.isEmpty ? "系统工具执行失败" : message
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
