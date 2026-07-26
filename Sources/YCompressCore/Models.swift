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

    public init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        symbol: String,
        action: JobAction,
        quality: CompressionQuality,
        maxImageDimension: Int? = nil,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.action = action
        self.quality = quality
        self.maxImageDimension = maxImageDimension
        self.isBuiltIn = isBuiltIn
    }

    public static let builtIns: [WorkflowPreset] = [
        .init(
            name: "智能压缩",
            detail: "自动识别图片、视频和普通文件",
            symbol: "wand.and.stars",
            action: .smart,
            quality: .balanced,
            maxImageDimension: 2560,
            isBuiltIn: true
        ),
        .init(
            name: "网页图片",
            detail: "转为 JPEG，最长边 1920 px",
            symbol: "photo.on.rectangle.angled",
            action: .compressImage,
            quality: .balanced,
            maxImageDimension: 1920,
            isBuiltIn: true
        ),
        .init(
            name: "分享视频",
            detail: "使用 H.264 兼容预设压缩视频",
            symbol: "video.badge.waveform",
            action: .compressVideo,
            quality: .compact,
            isBuiltIn: true
        ),
        .init(
            name: "归档打包",
            detail: "将每个项目打包为兼容性良好的 ZIP",
            symbol: "archivebox",
            action: .createArchive,
            quality: .balanced,
            isBuiltIn: true
        ),
        .init(
            name: "安全解压",
            detail: "检查路径后解压 ZIP、TAR、TGZ",
            symbol: "shippingbox.and.arrow.backward",
            action: .extractArchive,
            quality: .balanced,
            isBuiltIn: true
        )
    ]
}

public struct CompressionOptions: Sendable {
    public var action: JobAction
    public var quality: CompressionQuality
    public var maxImageDimension: Int?
    public var outputDirectory: URL

    public init(
        action: JobAction,
        quality: CompressionQuality,
        maxImageDimension: Int?,
        outputDirectory: URL
    ) {
        self.action = action
        self.quality = quality
        self.maxImageDimension = maxImageDimension
        self.outputDirectory = outputDirectory
    }
}
