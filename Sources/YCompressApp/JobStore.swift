import AppKit
import Combine
import Foundation
import YCompressCore

enum JobStatus: Equatable {
    case waiting
    case running
    case completed
    case failed(String)

    var title: String {
        switch self {
        case .waiting: "等待中"
        case .running: "处理中"
        case .completed: "已完成"
        case .failed: "失败"
        }
    }
}

struct CompressionJob: Identifiable {
    let id = UUID()
    let sourceURL: URL
    let kind: MediaKind
    let originalBytes: Int64
    var outputURL: URL?
    var outputBytes: Int64?
    var status: JobStatus = .waiting
}

@MainActor
final class JobStore: ObservableObject {
    @Published var jobs: [CompressionJob] = []
    @Published var selectedPreset: WorkflowPreset = WorkflowPreset.builtIns[0]
    @Published var isRunning = false
    @Published var isDropTargeted = false
    @Published var outputDirectory: URL

    private let engine = CompressionEngine()

    init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        outputDirectory = downloads.appendingPathComponent("YCompress", isDirectory: true)
    }

    func add(_ urls: [URL]) {
        let existing = Set(jobs.map(\.sourceURL.standardizedFileURL))
        let newJobs = urls
            .filter { !existing.contains($0.standardizedFileURL) }
            .map { url in
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
                let bytes = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
                return CompressionJob(
                    sourceURL: url,
                    kind: FileClassifier.kind(for: url),
                    originalBytes: bytes
                )
            }
        jobs.append(contentsOf: newJobs)
    }

    func remove(_ id: UUID) {
        guard !isRunning else { return }
        jobs.removeAll { $0.id == id }
    }

    func clearFinished() {
        guard !isRunning else { return }
        jobs.removeAll {
            if case .completed = $0.status { return true }
            if case .failed = $0.status { return true }
            return false
        }
    }

    func runSelectedWorkflow() {
        guard !isRunning, !jobs.isEmpty else { return }
        isRunning = true
        let preset = selectedPreset
        let destination = outputDirectory
        Task {
            defer { isRunning = false }
            for index in jobs.indices {
                guard jobs[index].status != .completed else { continue }
                jobs[index].status = .running
                let options = CompressionOptions(
                    action: preset.action,
                    quality: preset.quality,
                    maxImageDimension: preset.maxImageDimension,
                    outputDirectory: destination
                )
                do {
                    let output = try await engine.process(
                        url: jobs[index].sourceURL,
                        options: options
                    )
                    let values = try? output.resourceValues(
                        forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey]
                    )
                    jobs[index].outputURL = output
                    jobs[index].outputBytes = Int64(
                        values?.totalFileAllocatedSize ?? values?.fileSize ?? 0
                    )
                    jobs[index].status = .completed
                } catch {
                    jobs[index].status = .failed(error.localizedDescription)
                }
            }
        }
    }

    func revealOutput(_ job: CompressionJob) {
        guard let outputURL = job.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
    }
}

@MainActor
final class WorkflowStore: ObservableObject {
    @Published private(set) var custom: [WorkflowPreset] = []

    var all: [WorkflowPreset] { WorkflowPreset.builtIns + custom }

    init() {
        if let data = UserDefaults.standard.data(forKey: "customWorkflows"),
           let decoded = try? JSONDecoder().decode([WorkflowPreset].self, from: data) {
            custom = decoded
        }
    }

    func add(name: String, action: JobAction, quality: CompressionQuality) {
        let preset = WorkflowPreset(
            name: name.isEmpty ? "自定义工作流" : name,
            detail: "\(action.title) · \(quality.title)",
            symbol: "slider.horizontal.3",
            action: action,
            quality: quality
        )
        custom.append(preset)
        save()
    }

    func delete(_ preset: WorkflowPreset) {
        custom.removeAll { $0.id == preset.id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(custom) else { return }
        UserDefaults.standard.set(data, forKey: "customWorkflows")
    }
}
