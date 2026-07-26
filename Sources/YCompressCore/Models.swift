import Foundation

public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case image
    case video
    case archive
    case file

    public var title: String {
        switch self {
        case .image: "图片"
        case .video: "视频"
        case .archive: "压缩包"
        case .file: "文件"
        }
    }
}

public enum JobAction: String, Codable, CaseIterable, Sendable {
    case smart
    case compressImage
    case compressVideo
    case createArchive
    case extractArchive

    public var title: String {
        switch self {
        case .smart: "智能处理"
        case .compressImage: "压缩图片"
        case .compressVideo: "压缩视频"
        case .createArchive: "创建 ZIP"
        case .extractArchive: "解压文件"
        }
    }
}

public enum CompressionQuality: String, Codable, CaseIterable, Sendable {
    case high
    case balanced
    case compact

    public var title: String {
        switch self {
        case .high: "高质量"
        case .balanced: "均衡"
        case .compact: "更小体积"
        }
    }

    public var imageQuality: Double {
        switch self {
        case .high: 0.86
        case .balanced: 0.72
        case .compact: 0.52
        }
    }

    /// Maximum estimated output size relative to the source video.
    ///
    /// AVFoundation's named video presets use fixed encoding targets that can
    /// be much larger than an already-efficient source. YCompress uses these
    /// ratios to select the best compatible preset that is still expected to
    /// reduce the file.
    public var videoTargetSizeRatio: Double {
        switch self {
        case .high: 0.95
        case .balanced: 0.88
        case .compact: 0.80
        }
    }
}

public enum ImageOutputFormat: String, Codable, CaseIterable, Sendable {
    case automatic
    case jpeg
    case png
    case heic

    public var title: String {
        switch self {
        case .automatic: "自动"
        case .jpeg: "JPEG"
        case .png: "PNG"
        case .heic: "HEIC"
        }
    }
}

public enum VideoResolution: String, Codable, CaseIterable, Sendable {
    case source
    case fullHD
    case hd
    case compact

    public var title: String {
        switch self {
        case .source: "保持原分辨率"
        case .fullHD: "最高 1080p"
        case .hd: "最高 720p"
        case .compact: "最高 540p"
        }
    }
}

public struct WorkflowAdvancedOptions: Codable, Hashable, Sendable {
    public var outputSuffix: String
    public var revealWhenFinished: Bool
    public var continueOnError: Bool
    public var imageFormat: ImageOutputFormat
    public var imageMaxDimension: Int?
    public var videoResolution: VideoResolution
    public var videoOptimizeForNetwork: Bool
    public var archiveKeepParentFolder: Bool
    public var archivePreserveMacMetadata: Bool
    public var extractCreateSubfolder: Bool

    public init(
        outputSuffix: String = "",
        revealWhenFinished: Bool = false,
        continueOnError: Bool = true,
        imageFormat: ImageOutputFormat = .automatic,
        imageMaxDimension: Int? = nil,
        videoResolution: VideoResolution = .hd,
        videoOptimizeForNetwork: Bool = true,
        archiveKeepParentFolder: Bool = true,
        archivePreserveMacMetadata: Bool = true,
        extractCreateSubfolder: Bool = true
    ) {
        self.outputSuffix = outputSuffix
        self.revealWhenFinished = revealWhenFinished
        self.continueOnError = continueOnError
        self.imageFormat = imageFormat
        self.imageMaxDimension = imageMaxDimension
        self.videoResolution = videoResolution
        self.videoOptimizeForNetwork = videoOptimizeForNetwork
        self.archiveKeepParentFolder = archiveKeepParentFolder
        self.archivePreserveMacMetadata = archivePreserveMacMetadata
        self.extractCreateSubfolder = extractCreateSubfolder
    }

    public static func defaults(for action: JobAction) -> WorkflowAdvancedOptions {
        switch action {
        case .smart:
            .init(imageMaxDimension: 2560, videoResolution: .hd)
        case .compressImage:
            .init(imageFormat: .jpeg, imageMaxDimension: 1920)
        case .compressVideo:
            .init(videoResolution: .compact)
        case .createArchive:
            .init()
        case .extractArchive:
            .init()
        }
    }
}

public struct WorkflowPreset: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var detail: String
    public var symbol: String
    public var action: JobAction
    public var quality: CompressionQuality
    public var maxImageDimension: Int?
    public var isBuiltIn: Bool
    public var advanced: WorkflowAdvancedOptions

    public init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        symbol: String,
        action: JobAction,
        quality: CompressionQuality,
        maxImageDimension: Int? = nil,
        isBuiltIn: Bool = false,
        advanced: WorkflowAdvancedOptions? = nil
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.action = action
        self.quality = quality
        self.maxImageDimension = maxImageDimension
        self.isBuiltIn = isBuiltIn
        var resolvedAdvanced = advanced ?? .defaults(for: action)
        if resolvedAdvanced.imageMaxDimension == nil {
            resolvedAdvanced.imageMaxDimension = maxImageDimension
        }
        self.advanced = resolvedAdvanced
    }

    public static let builtIns: [WorkflowPreset] = [
        .init(
            id: UUID(uuidString: "A4C1613A-9289-4A40-8D39-2C6F67519501")!,
            name: "智能压缩",
            detail: "自动识别图片、视频和普通文件",
            symbol: "wand.and.stars",
            action: .smart,
            quality: .balanced,
            maxImageDimension: 2560,
            isBuiltIn: true
        ),
        .init(
            id: UUID(uuidString: "A4C1613A-9289-4A40-8D39-2C6F67519502")!,
            name: "网页图片",
            detail: "转为 JPEG，最长边 1920 px",
            symbol: "photo.on.rectangle.angled",
            action: .compressImage,
            quality: .balanced,
            maxImageDimension: 1920,
            isBuiltIn: true
        ),
        .init(
            id: UUID(uuidString: "A4C1613A-9289-4A40-8D39-2C6F67519503")!,
            name: "分享视频",
            detail: "使用 H.264 兼容预设压缩视频",
            symbol: "video.badge.waveform",
            action: .compressVideo,
            quality: .compact,
            isBuiltIn: true
        ),
        .init(
            id: UUID(uuidString: "A4C1613A-9289-4A40-8D39-2C6F67519504")!,
            name: "归档打包",
            detail: "将每个项目打包为兼容性良好的 ZIP",
            symbol: "archivebox",
            action: .createArchive,
            quality: .balanced,
            isBuiltIn: true
        ),
        .init(
            id: UUID(uuidString: "A4C1613A-9289-4A40-8D39-2C6F67519505")!,
            name: "安全解压",
            detail: "检查路径后解压 ZIP、TAR、TGZ",
            symbol: "shippingbox.and.arrow.backward",
            action: .extractArchive,
            quality: .balanced,
            isBuiltIn: true
        )
    ]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case detail
        case symbol
        case action
        case quality
        case maxImageDimension
        case isBuiltIn
        case advanced
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        detail = try container.decode(String.self, forKey: .detail)
        symbol = try container.decode(String.self, forKey: .symbol)
        action = try container.decode(JobAction.self, forKey: .action)
        quality = try container.decode(CompressionQuality.self, forKey: .quality)
        maxImageDimension = try container.decodeIfPresent(Int.self, forKey: .maxImageDimension)
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        if let decodedAdvanced = try container.decodeIfPresent(
            WorkflowAdvancedOptions.self,
            forKey: .advanced
        ) {
            advanced = decodedAdvanced
        } else {
            advanced = .defaults(for: action)
            if let maxImageDimension {
                advanced.imageMaxDimension = maxImageDimension
            }
        }
    }
}

public struct CompressionOptions: Sendable {
    public var action: JobAction
    public var quality: CompressionQuality
    public var maxImageDimension: Int?
    public var outputDirectory: URL
    public var advanced: WorkflowAdvancedOptions

    public init(
        action: JobAction,
        quality: CompressionQuality,
        maxImageDimension: Int?,
        outputDirectory: URL,
        advanced: WorkflowAdvancedOptions
    ) {
        self.action = action
        self.quality = quality
        self.maxImageDimension = maxImageDimension
        self.outputDirectory = outputDirectory
        self.advanced = advanced
    }
}
