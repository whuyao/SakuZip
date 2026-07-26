import Foundation

public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case image
    case video
    case archive
    case file

    public var title: String {
        switch self {
        case .image: L10n.string("图片")
        case .video: L10n.string("视频")
        case .archive: L10n.string("压缩包")
        case .file: L10n.string("文件")
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
        case .smart: L10n.string("智能处理")
        case .compressImage: L10n.string("压缩图片")
        case .compressVideo: L10n.string("压缩视频")
        case .createArchive: L10n.string("创建 ZIP")
        case .extractArchive: L10n.string("解压文件")
        }
    }
}

public enum CompressionQuality: String, Codable, CaseIterable, Sendable {
    case high
    case balanced
    case compact

    public var title: String {
        switch self {
        case .high: L10n.string("高质量")
        case .balanced: L10n.string("均衡")
        case .compact: L10n.string("更小体积")
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
    /// be much larger than an already-efficient source. SakuZip uses these
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
        case .automatic: L10n.string("自动")
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
        case .source: L10n.string("保持原分辨率")
        case .fullHD: L10n.string("最高 1080p")
        case .hd: L10n.string("最高 720p")
        case .compact: L10n.string("最高 540p")
        }
    }
}

public enum ArchiveEncryptionMode: String, Codable, CaseIterable, Sendable {
    case none
    case aes256
    case traditional

    public var title: String {
        switch self {
        case .none: L10n.string("不使用密码")
        case .aes256: L10n.string("AES-256（推荐）")
        case .traditional: L10n.string("传统 ZIP 密码（兼容模式）")
        }
    }

    public var requiresPassword: Bool {
        self != .none
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
    public var archiveEncryption: ArchiveEncryptionMode
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
        archiveEncryption: ArchiveEncryptionMode = .none,
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
        self.archiveEncryption = archiveEncryption
        self.extractCreateSubfolder = extractCreateSubfolder
    }

    private enum CodingKeys: String, CodingKey {
        case outputSuffix
        case revealWhenFinished
        case continueOnError
        case imageFormat
        case imageMaxDimension
        case videoResolution
        case videoOptimizeForNetwork
        case archiveKeepParentFolder
        case archivePreserveMacMetadata
        case archiveEncryption
        case extractCreateSubfolder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputSuffix = try container.decodeIfPresent(String.self, forKey: .outputSuffix) ?? ""
        revealWhenFinished =
            try container.decodeIfPresent(Bool.self, forKey: .revealWhenFinished) ?? false
        continueOnError =
            try container.decodeIfPresent(Bool.self, forKey: .continueOnError) ?? true
        imageFormat =
            try container.decodeIfPresent(ImageOutputFormat.self, forKey: .imageFormat) ?? .automatic
        imageMaxDimension = try container.decodeIfPresent(Int.self, forKey: .imageMaxDimension)
        videoResolution =
            try container.decodeIfPresent(VideoResolution.self, forKey: .videoResolution) ?? .hd
        videoOptimizeForNetwork =
            try container.decodeIfPresent(Bool.self, forKey: .videoOptimizeForNetwork) ?? true
        archiveKeepParentFolder =
            try container.decodeIfPresent(Bool.self, forKey: .archiveKeepParentFolder) ?? true
        archivePreserveMacMetadata =
            try container.decodeIfPresent(Bool.self, forKey: .archivePreserveMacMetadata) ?? true
        archiveEncryption =
            try container.decodeIfPresent(ArchiveEncryptionMode.self, forKey: .archiveEncryption) ?? .none
        extractCreateSubfolder =
            try container.decodeIfPresent(Bool.self, forKey: .extractCreateSubfolder) ?? true
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
            name: L10n.string("智能压缩"),
            detail: L10n.string("自动识别图片、视频和普通文件"),
            symbol: "wand.and.stars",
            action: .smart,
            quality: .balanced,
            maxImageDimension: 2560,
            isBuiltIn: true
        ),
        .init(
            id: UUID(uuidString: "A4C1613A-9289-4A40-8D39-2C6F67519502")!,
            name: L10n.string("网页图片"),
            detail: L10n.string("转为 JPEG，最长边 1920 px"),
            symbol: "photo.on.rectangle.angled",
            action: .compressImage,
            quality: .balanced,
            maxImageDimension: 1920,
            isBuiltIn: true
        ),
        .init(
            id: UUID(uuidString: "A4C1613A-9289-4A40-8D39-2C6F67519503")!,
            name: L10n.string("分享视频"),
            detail: L10n.string("使用 H.264 兼容预设压缩视频"),
            symbol: "video.badge.waveform",
            action: .compressVideo,
            quality: .compact,
            isBuiltIn: true
        ),
        .init(
            id: UUID(uuidString: "A4C1613A-9289-4A40-8D39-2C6F67519504")!,
            name: L10n.string("归档打包"),
            detail: L10n.string("将每个项目打包为兼容性良好的 ZIP"),
            symbol: "archivebox",
            action: .createArchive,
            quality: .balanced,
            isBuiltIn: true
        ),
        .init(
            id: UUID(uuidString: "A4C1613A-9289-4A40-8D39-2C6F67519505")!,
            name: L10n.string("安全解压"),
            detail: L10n.string("检查路径后解压 ZIP、TAR、TGZ"),
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
