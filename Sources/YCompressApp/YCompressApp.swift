import SwiftUI

@main
struct YCompressApp: App {
    @StateObject private var jobs = JobStore()
    @StateObject private var workflows = WorkflowStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(jobs)
                .environmentObject(workflows)
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
