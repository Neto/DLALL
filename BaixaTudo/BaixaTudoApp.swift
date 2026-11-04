import SwiftUI

@main
struct BaixaTudoApp: App {
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
                    model.refreshEngine()
                }
        }
        .defaultSize(width: 760, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Sobre o BaixaTudo") {
                    AppVersion.showAboutPanel()
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Baixar da Área de Transferência") {
                    model.pasteFromClipboard()
                    model.enqueueDraft()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Baixar URL") {
                    model.enqueueDraft()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Limpar Concluídos") {
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
