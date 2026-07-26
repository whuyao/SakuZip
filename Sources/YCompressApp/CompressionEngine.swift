import AVFoundation
import CoreGraphics
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

actor CompressionEngine {
    func process(url: URL, options: CompressionOptions) async throws -> URL {
        try FileManager.default.createDirectory(
            at: options.outputDirectory,
            withIntermediateDirectories: true
        )
        let action = FileClassifier.resolvedAction(for: url, requested: options.action)
        switch action {
        case .compressImage:
            return try compressImage(url, options: options)
        case .compressVideo:
            return try await compressVideo(url, options: options)
        case .createArchive:
            return try await createArchive(url, outputDirectory: options.outputDirectory)
        case .extractArchive:
            return try await extractArchive(url, outputDirectory: options.outputDirectory)
        case .smart:
            throw CompressionError.unsupported("无法解析智能工作流")
        }
    }

    private func compressImage(_ sourceURL: URL, options: CompressionOptions) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw CompressionError.invalidImage
        }

        let image: CGImage?
        if let maxDimension = options.maxImageDimension {
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

        let preservesAlpha = image.alphaInfo == .premultipliedFirst
            || image.alphaInfo == .premultipliedLast
            || image.alphaInfo == .first
            || image.alphaInfo == .last
        let fileExtension = preservesAlpha ? "png" : "jpg"
        let destinationType = preservesAlpha ? UTType.png.identifier : UTType.jpeg.identifier
        let destinationURL = PathSafety.uniqueURL(
            directory: options.outputDirectory,
            baseName: sourceURL.deletingPathExtension().lastPathComponent + "-compressed",
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
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.cannotCreateOutput
        }
        return destinationURL
    }

    private func compressVideo(_ sourceURL: URL, options: CompressionOptions) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let preset: String
        switch options.quality {
        case .high:
            preset = AVAssetExportPresetHighestQuality
        case .balanced:
            preset = AVAssetExportPreset1280x720
        case .compact:
            preset = AVAssetExportPreset960x540
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw CompressionError.unsupported("此视频编码无法使用所选预设")
        }
        let destinationURL = PathSafety.uniqueURL(
            directory: options.outputDirectory,
            baseName: sourceURL.deletingPathExtension().lastPathComponent + "-compressed",
            pathExtension: "mp4"
        )
        session.outputURL = destinationURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        await session.export()
        switch session.status {
        case .completed:
            return destinationURL
        case .cancelled:
            throw CancellationError()
        default:
            throw CompressionError.exportFailed(session.error?.localizedDescription ?? "未知错误")
        }
    }

    private func createArchive(_ sourceURL: URL, outputDirectory: URL) async throws -> URL {
        let destinationURL = PathSafety.uniqueURL(
            directory: outputDirectory,
            baseName: sourceURL.deletingPathExtension().lastPathComponent,
            pathExtension: "zip"
        )
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)
        var arguments = ["-c", "-k", "--sequesterRsrc"]
        if isDirectory.boolValue {
            arguments.append("--keepParent")
        }
        arguments.append(contentsOf: [sourceURL.path, destinationURL.path])
        _ = try await runTool(
            "/usr/bin/ditto",
            arguments: arguments
        )
        return destinationURL
    }

    private func extractArchive(_ sourceURL: URL, outputDirectory: URL) async throws -> URL {
        guard FileClassifier.kind(for: sourceURL) == .archive else {
            throw CompressionError.unsupported(sourceURL.pathExtension)
        }
        let destinationURL = uniqueDirectory(
            parent: outputDirectory,
            name: sourceURL.deletingPathExtension().lastPathComponent
        )
        let lowerName = sourceURL.lastPathComponent.lowercased()
        let entries: String
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
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true
        )
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
        return destinationURL
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
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = standardOutput
            process.standardError = standardError
            process.terminationHandler = { process in
                let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
                let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0 {
                    continuation.resume(returning: String(decoding: outputData, as: UTF8.self))
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
