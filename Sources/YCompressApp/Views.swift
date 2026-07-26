import AppKit
import SwiftUI
import UniformTypeIdentifiers
import YCompressCore

enum SidebarDestination: String, CaseIterable, Identifiable {
    case compress
    case workflows
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compress: "压缩与解压"
        case .workflows: "工作流"
        case .history: "处理记录"
        case .settings: "设置"
        }
    }

    var symbol: String {
        switch self {
        case .compress: "arrow.down.right.and.arrow.up.left"
        case .workflows: "square.stack.3d.up"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @State private var destination: SidebarDestination? = .compress

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(
                                LinearGradient(
                                    colors: [.indigo, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("YCompress")
                            .font(.headline)
                        Text("本地 · 私密 · 高效")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 18)

                List(SidebarDestination.allCases, selection: $destination) { item in
                    Label(item.title, systemImage: item.symbol)
                        .tag(item)
                        .padding(.vertical, 4)
                }
                .listStyle(.sidebar)

                VStack(alignment: .leading, spacing: 6) {
                    Label("完全离线处理", systemImage: "lock.shield")
                        .font(.caption.weight(.medium))
                    Text("文件不会离开这台 Mac")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 230)
        } detail: {
            switch destination ?? .compress {
            case .compress:
                CompressView()
            case .workflows:
                WorkflowsView()
            case .history:
                HistoryView()
            case .settings:
                SettingsView()
            }
        }
    }
}

struct CompressView: View {
    @EnvironmentObject private var jobs: JobStore
    @EnvironmentObject private var workflows: WorkflowStore

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 18) {
                    dropZone
                    if !jobs.jobs.isEmpty {
                        controls
                        jobList
                    }
                }
                .padding(24)
            }
            if !jobs.jobs.isEmpty {
                bottomBar
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("压缩与解压")
                    .font(.system(size: 26, weight: .bold))
                Text("图片、视频与通用文件，一次完成")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                FilePicker.addFiles(to: jobs)
            } label: {
                Label("添加文件", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.bar)
    }

    private var dropZone: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.indigo.opacity(0.12))
                    .frame(width: 68, height: 68)
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.indigo)
            }
            Text("把文件或文件夹拖到这里")
                .font(.title3.weight(.semibold))
            Text("支持图片、视频、ZIP、TAR、TGZ 和任意文件归档")
                .foregroundStyle(.secondary)
            Button("选择文件…") {
                FilePicker.addFiles(to: jobs)
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity)
        .frame(height: jobs.jobs.isEmpty ? 290 : 180)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(jobs.isDropTargeted ? Color.indigo.opacity(0.10) : Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            jobs.isDropTargeted ? Color.indigo : Color.secondary.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1.5, dash: [7])
                        )
                }
        )
        .animation(.easeOut(duration: 0.15), value: jobs.isDropTargeted)
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: $jobs.isDropTargeted,
            perform: handleDrop
        )
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Text("工作流")
                .font(.subheadline.weight(.semibold))
            Picker("工作流", selection: $jobs.selectedPreset) {
                ForEach(workflows.all) { preset in
                    Label(preset.name, systemImage: preset.symbol)
                        .tag(preset)
                }
            }
            .labelsHidden()
            .frame(width: 240)
            Spacer()
            Text("\(jobs.jobs.count) 个项目")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("清理结果") {
                jobs.clearFinished()
            }
            .disabled(jobs.isRunning)
        }
    }

    private var jobList: some View {
        LazyVStack(spacing: 10) {
            ForEach(jobs.jobs) { job in
                JobRow(job: job)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("输出到")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(jobs.outputDirectory.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.subheadline)
            }
            Button {
                FilePicker.chooseOutput(for: jobs)
            } label: {
                Image(systemName: "folder")
            }
            .help("更改输出目录")
            .disabled(jobs.isRunning)
            Spacer()
            Button {
                jobs.runSelectedWorkflow()
            } label: {
                HStack {
                    if jobs.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(jobs.isRunning ? "处理中…" : "运行工作流")
                }
                .frame(minWidth: 112)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(jobs.isRunning)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matching.isEmpty else { return false }
        for provider in matching {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in jobs.add([url]) }
            }
        }
        return true
    }
}

struct JobRow: View {
    @EnvironmentObject private var jobs: JobStore
    let job: CompressionJob

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                Image(systemName: symbol)
                    .foregroundStyle(color)
                    .font(.system(size: 20, weight: .medium))
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 5) {
                Text(job.sourceURL.lastPathComponent)
                    .lineLimit(1)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(job.kind.title)
                    Text("·")
                    Text(ByteCountFormatter.string(fromByteCount: job.originalBytes, countStyle: .file))
                    if let outputBytes = job.outputBytes {
                        Text("→")
                        Text(ByteCountFormatter.string(fromByteCount: outputBytes, countStyle: .file))
                            .foregroundStyle(.green)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if case .failed(let message) = job.status {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            Spacer()
            statusView
            if job.outputURL != nil {
                Button {
                    jobs.revealOutput(job)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help("在 Finder 中显示")
            }
            Button {
                jobs.remove(job.id)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .disabled(jobs.isRunning)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    @ViewBuilder
    private var statusView: some View {
        switch job.status {
        case .waiting:
            Text("等待中").foregroundStyle(.secondary)
        case .running:
            ProgressView().controlSize(.small)
        case .completed:
            Label("完成", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Label("失败", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private var symbol: String {
        switch job.kind {
        case .image: "photo"
        case .video: "film"
        case .archive: "archivebox"
        case .file: "doc"
        }
    }

    private var color: Color {
        switch job.kind {
        case .image: .purple
        case .video: .blue
        case .archive: .orange
        case .file: .teal
        }
    }
}

struct WorkflowsView: View {
    @EnvironmentObject private var jobs: JobStore
    @EnvironmentObject private var workflows: WorkflowStore
    @State private var showingCreator = false

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("工作流")
                            .font(.system(size: 26, weight: .bold))
                        Text("一键复用常见压缩与解压配置")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showingCreator = true
                    } label: {
                        Label("新建工作流", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(workflows.all) { preset in
                        WorkflowCard(preset: preset)
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingCreator) {
            WorkflowCreator()
                .environmentObject(workflows)
        }
    }
}

struct WorkflowCard: View {
    @EnvironmentObject private var jobs: JobStore
    @EnvironmentObject private var workflows: WorkflowStore
    let preset: WorkflowPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.indigo.opacity(0.12))
                    Image(systemName: preset.symbol)
                        .font(.title2)
                        .foregroundStyle(.indigo)
                }
                .frame(width: 48, height: 48)
                Spacer()
                if !preset.isBuiltIn {
                    Button {
                        workflows.delete(preset)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            Text(preset.name)
                .font(.headline)
            Text(preset.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
            HStack {
                Text(preset.quality.title)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                Spacer()
                Button("使用") {
                    jobs.selectedPreset = preset
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    if jobs.selectedPreset.id == preset.id {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.indigo, lineWidth: 2)
                    }
                }
        )
    }
}

struct WorkflowCreator: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workflows: WorkflowStore
    @State private var name = ""
    @State private var action: JobAction = .smart
    @State private var quality: CompressionQuality = .balanced

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("新建工作流")
                .font(.title2.weight(.bold))
            TextField("工作流名称", text: $name)
            Picker("操作", selection: $action) {
                ForEach(JobAction.allCases, id: \.self) {
                    Text($0.title).tag($0)
                }
            }
            Picker("质量", selection: $quality) {
                ForEach(CompressionQuality.allCases, id: \.self) {
                    Text($0.title).tag($0)
                }
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("创建") {
                    workflows.add(name: name, action: action, quality: quality)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 430)
    }
}

struct HistoryView: View {
    @EnvironmentObject private var jobs: JobStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("处理记录")
                .font(.system(size: 26, weight: .bold))
            if jobs.jobs.filter({ $0.status == .completed }).isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("完成的任务会显示在这里")
                        .font(.headline)
                    Text("记录仅保存在本次运行中")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(jobs.jobs.filter { $0.status == .completed }) { job in
                            JobRow(job: job)
                        }
                    }
                }
            }
        }
        .padding(24)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var jobs: JobStore

    var body: some View {
        Form {
            Section("输出") {
                LabeledContent("默认文件夹") {
                    HStack {
                        Text(jobs.outputDirectory.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("选择…") {
                            FilePicker.chooseOutput(for: jobs)
                        }
                    }
                    .frame(maxWidth: 340)
                }
            }
            Section("隐私") {
                Label("所有处理均在本机完成，不上传文件。", systemImage: "lock.shield.fill")
                    .foregroundStyle(.secondary)
            }
            Section("格式") {
                Text("图片：JPEG / PNG / HEIC 等；视频：macOS 可解码格式；归档：ZIP / TAR / TGZ")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

enum FilePicker {
    @MainActor
    static func addFiles(to jobs: JobStore) {
        let panel = NSOpenPanel()
        panel.title = "选择要处理的文件"
        panel.prompt = "添加"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.begin { response in
            guard response == .OK else { return }
            jobs.add(panel.urls)
        }
    }

    @MainActor
    static func chooseOutput(for jobs: JobStore) {
        let panel = NSOpenPanel()
        panel.title = "选择输出文件夹"
        panel.prompt = "选择"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = jobs.outputDirectory
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            jobs.outputDirectory = url
        }
    }
}
