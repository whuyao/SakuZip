import AppKit
import SwiftUI

@MainActor
final class ExternalOpenStore: ObservableObject {
    @Published private(set) var urls: [URL] = []

    func enqueue(_ incomingURLs: [URL]) {
        var seen = Set(urls.map(\.standardizedFileURL))
        let uniqueURLs = incomingURLs.filter {
            $0.isFileURL && seen.insert($0.standardizedFileURL).inserted
        }
        urls.append(contentsOf: uniqueURLs)
    }

    func consume(_ consumedURLs: [URL]) {
        let consumed = Set(consumedURLs.map(\.standardizedFileURL))
        urls.removeAll { consumed.contains($0.standardizedFileURL) }
    }
}

@MainActor
final class YCompressApplicationDelegate: NSObject, NSApplicationDelegate {
    let externalOpenStore = ExternalOpenStore()

    func application(_ application: NSApplication, open urls: [URL]) {
        externalOpenStore.enqueue(urls)
        application.activate(ignoringOtherApps: true)
    }
}

@main
struct YCompressApp: App {
    @NSApplicationDelegateAdaptor(YCompressApplicationDelegate.self)
    private var applicationDelegate
    @StateObject private var jobs = JobStore()
    @StateObject private var workflows = WorkflowStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(jobs)
                .environmentObject(workflows)
                .environmentObject(applicationDelegate.externalOpenStore)
                .frame(minWidth: 980, minHeight: 650)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加文件…") {
                    FilePicker.addFiles(to: jobs)
                }
                .keyboardShortcut("o")
            }
            CommandGroup(after: .help) {
                Link(
                    "UrbanComp 团队网站",
                    destination: URL(string: "https://urbancomp.net")!
                )
            }
        }

        Settings {
            SettingsView()
                .environmentObject(jobs)
                .frame(width: 520, height: 260)
        }
    }
}
