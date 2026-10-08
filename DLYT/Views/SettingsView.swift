import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryModel.self) private var model

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("Geral", systemImage: "gear") }
            engineTab
                .tabItem { Label("Motor", systemImage: "terminal") }
        }
        .frame(width: 520, height: 420)
        .onAppear { model.refreshEngine() }
    }

    @ViewBuilder
    private var generalTab: some View {
        @Bindable var settings = settings

        Form {
            Section("Download") {
                LabeledContent("Pasta de destino") {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(settings.resolvedOutputFolder.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .frame(maxWidth: 280, alignment: .trailing)
                            .help(settings.resolvedOutputFolder.path)
                        HStack {
                            Button("Escolher…") { pickFolder() }
                            if !settings.outputFolderPath.isEmpty {
                                Button("Usar Downloads") {
                                    settings.outputFolderPath = ""
                                }
                            }
                        }
                    }
                }

                Picker("Qualidade padrão", selection: $settings.defaultQuality) {
                    ForEach(VideoQuality.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                Text("Vídeos são salvos em H.264 + AAC para abrir no QuickTime e no app TV.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Cookies do navegador", selection: $settings.cookiesBrowser) {
                    ForEach(BrowserCookies.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                Text("Automático tenta sem cookies e, se o site pedir login (YouTube, Instagram, TikTok, Vimeo privado), usa os cookies do Safari, Chrome ou outro navegador onde você já está logado. O DLYT não vê sua senha, só lê os cookies locais. Para o Safari, o DLYT precisa de Full Disk Access em System Settings > Privacy & Security.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Ao concluir") {
                Toggle("Mostrar no Finder", isOn: $settings.revealWhenDone)
                Toggle("Abrir o arquivo", isOn: $settings.openWhenDone)
            }

            Section("Uso") {
                Text("Baixe apenas conteúdo que você criou, que é de domínio público ou para o qual você tem autorização. Os termos do YouTube, Instagram, TikTok e Vimeo restringem o download. Este app é uma ferramenta pessoal e não vai para a App Store.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    @ViewBuilder
    private var engineTab: some View {
        @Bindable var settings = settings

        Form {
            Section("Ferramentas") {
                LabeledContent("yt-dlp") {
                    Text(binaryLabel(BinaryLocator.findYTDLP(customPath: settings.customYTDLPPath)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                LabeledContent("ffmpeg") {
                    Text(binaryLabel(BinaryLocator.findFFmpeg()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                LabeledContent("deno") {
                    Text(binaryLabel(BinaryLocator.findDeno()) + (BinaryLocator.findDeno() == nil ? " (opcional, ajuda no YouTube)" : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                TextField("Caminho manual do yt-dlp", text: $settings.customYTDLPPath)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: settings.customYTDLPPath) {
                        model.refreshEngine()
                    }
                Text("Em branco, o DLYT usa as ferramentas que vêm dentro do app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Instalação") {
                Text("yt-dlp, ffmpeg e deno já vêm no aplicativo. Não é preciso instalar nada no Terminal.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Verificar de Novo") {
                    model.refreshEngine()
                }
            }

            Section("Versão") {
                LabeledContent("DLYT") {
                    Text(AppVersion.full)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    private func binaryLabel(_ url: URL?) -> String {
        url?.path ?? "não encontrado"
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Escolher"
        panel.message = "Pasta onde os vídeos serão salvos."
        panel.directoryURL = settings.resolvedOutputFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.outputFolderPath = url.path
    }
}

#Preview {
    let settings = AppSettings()
    SettingsView()
        .environment(settings)
        .environment(LibraryModel(settings: settings))
}
