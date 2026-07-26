import AppKit
import Combine
import Foundation
import YCompressCore

enum JobStatus: Equatable {
    case waiting
    case running
    case completed
    case failed(String)
    case cancelled

    var title: String {
        switch self {
        case .waiting: L10n.string("等待中")
        case .running: L10n.string("处理中")
        case .completed: L10n.string("已完成")
        case .failed: L10n.string("失败")
        case .cancelled: L10n.string("已取消")
        }
    }
}

struct CompressionJob: Identifiable {
    let id = UUID()
    let sourceURL: URL
    let kind: MediaKind
    var originalBytes: Int64
    var outputURL: URL?
    var outputBytes: Int64?
    var status: JobStatus = .waiting
    var progress: Double = 0
    var progressDetail: String = L10n.string("等待中")
}

@MainActor
final class JobStore: ObservableObject {
    @Published var jobs: [CompressionJob] = []
    @Published var selectedPreset: WorkflowPreset = WorkflowPreset.builtIns[0]
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var isDropTargeted = false
    @Published var outputDirectory: URL

    private let engine = CompressionEngine()
    private var processingTask: Task<Void, Never>?

    init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        outputDirectory = downloads.appendingPathComponent("YCompress", isDirectory: true)
    }

    func add(_ urls: [URL]) {
        let shouldAdoptSourceDirectory = jobs.isEmpty
        var seen = Set(jobs.map(\.sourceURL.standardizedFileURL))
        let newJobs = urls
            .filter { seen.insert($0.standardizedFileURL).inserted }
            .map { url in
                return CompressionJob(
                    sourceURL: url,
                    kind: FileClassifier.kind(for: url),
                    originalBytes: FileSizeResolver.logicalSize(for: url)
                )
            }
        if shouldAdoptSourceDirectory,
           let sourceDirectory = OutputDirectoryResolver.defaultDirectory(
               for: newJobs.map(\.sourceURL)
           ) {
            outputDirectory = sourceDirectory
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
            if case .cancelled = $0.status { return true }
            return false
        }
    }

    func runSelectedWorkflow() {
        guard !isRunning, !jobs.isEmpty else { return }
        isRunning = true
        isPaused = false
        let preset = selectedPreset
        let destination = outputDirectory
        processingTask = Task {
            defer {
                isRunning = false
                isPaused = false
                processingTask = nil
            }
            for index in jobs.indices {
                do {
                    try await waitWhilePaused()
                } catch {
                    break
                }
                guard jobs[index].status != .completed else { continue }
                jobs[index].status = .running
                jobs[index].progress = 0
                jobs[index].progressDetail = L10n.string("正在准备")
                let jobID = jobs[index].id
                refreshOriginalSize(for: jobID)
                let options = CompressionOptions(
                    action: preset.action,
                    quality: preset.quality,
                    maxImageDimension: preset.maxImageDimension,
                    outputDirectory: destination,
                    advanced: preset.advanced
                )
                do {
                    let output = try await engine.process(
                        url: jobs[index].sourceURL,
                        options: options,
                        progress: { [weak self] value, detail in
                            guard let self,
                                  let currentIndex = self.jobs.firstIndex(
                                      where: { $0.id == jobID }
                                  ) else { return }
                            self.jobs[currentIndex].progress = min(max(value, 0), 1)
                            self.jobs[currentIndex].progressDetail = detail
                            if self.jobs[currentIndex].originalBytes <= 0 {
                                self.refreshOriginalSize(for: jobID)
                            }
                        }
                    )
                    refreshOriginalSize(for: jobID)
                    let values = try? output.resourceValues(
                        forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey]
                    )
                    jobs[index].outputURL = output
                    jobs[index].outputBytes = Int64(
                        values?.fileSize ?? values?.totalFileAllocatedSize ?? 0
                    )
                    jobs[index].progress = 1
                    jobs[index].progressDetail = L10n.string("已完成")
                    jobs[index].status = .completed
                    if preset.advanced.revealWhenFinished {
                        NSWorkspace.shared.activateFileViewerSelecting([output])
                    }
                } catch is CancellationError {
                    refreshOriginalSize(for: jobID)
                    jobs[index].status = .cancelled
                    jobs[index].progressDetail = L10n.string("已取消")
                    break
                } catch {
                    refreshOriginalSize(for: jobID)
                    jobs[index].status = .failed(error.localizedDescription)
                    jobs[index].progressDetail = L10n.string("处理失败")
                    if !preset.advanced.continueOnError {
                        break
                    }
                }
            }
        }
    }

    func togglePause() {
        guard isRunning else { return }
        isPaused.toggle()
    }

    func cancelProcessing() {
        guard isRunning else { return }
        isPaused = false
        processingTask?.cancel()
        Task {
            await engine.cancelCurrent()
        }
    }

    func revealOutput(_ jobID: UUID) {
        guard let job = jobs.first(where: { $0.id == jobID }),
              let outputURL = job.outputURL?.standardizedFileURL,
              FileManager.default.fileExists(atPath: outputURL.path) else { return }
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: outputURL.path, isDirectory: &isDirectory)
        if isDirectory.boolValue {
            NSWorkspace.shared.open(outputURL)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([outputURL])
        }
    }

    private func waitWhilePaused() async throws {
        while isPaused {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func refreshOriginalSize(for jobID: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        let refreshedBytes = FileSizeResolver.logicalSize(for: jobs[index].sourceURL)
        if refreshedBytes > 0 {
            jobs[index].originalBytes = refreshedBytes
        }
    }
}

@MainActor
final class WorkflowStore: ObservableObject {
    @Published private(set) var presets: [WorkflowPreset]

    var all: [WorkflowPreset] { presets }

    private let storageKey = "workflowPresetsV2"

    init() {
        let builtIns = WorkflowPreset.builtIns
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([WorkflowPreset].self, from: data) {
            var merged = builtIns
            for preset in saved where preset.isBuiltIn {
                if let index = merged.firstIndex(where: { $0.id == preset.id }) {
                    var localizedPreset = preset
                    localizedPreset.name = merged[index].name
                    localizedPreset.detail = merged[index].detail
                    merged[index] = localizedPreset
                }
            }
            merged.append(contentsOf: saved.filter { !$0.isBuiltIn })
            presets = merged
        } else {
            var initial = builtIns
            if let legacyData = UserDefaults.standard.data(forKey: "customWorkflows"),
               let legacy = try? JSONDecoder().decode([WorkflowPreset].self, from: legacyData) {
                initial.append(contentsOf: legacy.map { preset in
                    var migrated = preset
                    migrated.isBuiltIn = false
                    return migrated
                })
            }
            presets = initial
            save()
        }
    }

    func add(name: String, action: JobAction, quality: CompressionQuality) {
        let preset = WorkflowPreset(
            name: name.isEmpty ? L10n.string("自定义工作流") : name,
            detail: "\(action.title) · \(quality.title)",
            symbol: "slider.horizontal.3",
            action: action,
            quality: quality
        )
        presets.append(preset)
        save()
    }

    func update(_ preset: WorkflowPreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
        save()
    }

    func reset(_ preset: WorkflowPreset) {
        guard preset.isBuiltIn,
              let original = WorkflowPreset.builtIns.first(where: { $0.id == preset.id }),
              let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = original
        save()
    }

    func delete(_ preset: WorkflowPreset) {
        guard !preset.isBuiltIn else { return }
        presets.removeAll { $0.id == preset.id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
