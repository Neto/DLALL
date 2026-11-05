import SwiftUI

@main
struct DLALLApp: App {
    @State private var settings: AppSettings
    @State private var model: LibraryModel

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _model = State(initialValue: LibraryModel(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(model)
                .task {
                    model.presentTutorialIfFirstLaunch()
                    model.refreshEngine()
                }
        }
        .defaultSize(width: 760, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About DLALL") {
                    AppVersion.showAboutPanel()
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Download from Clipboard") {
                    model.pasteFromClipboard()
                    model.enqueueDraft()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Download URL") {
                    model.enqueueDraft()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Button("Show Tutorial") {
                    model.showTutorial = true
                }
            }
            CommandGroup(after: .toolbar) {
                Button("Clear Finished") {
                    model.clearFinished()
                }
            }
        }

        Settings {
            SettingsView()
                .environment(settings)
                .environment(model)
        }
    }
}
