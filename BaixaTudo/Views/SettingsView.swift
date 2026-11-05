import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryModel.self) private var model
    @State private var checkingSession = false
    @State private var sessionReport: String?

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

                Picker("Cookies para vídeos", selection: $settings.videoCookiesBrowser) {
                    ForEach(BrowserCookies.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                Text("YouTube, Reels, posts do Instagram e outros links. Nenhum evita a leitura dos cookies; Automático tenta primeiro sem login e usa um navegador se necessário.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Cookies para Instagram Stories", selection: $settings.storyCookiesBrowser) {
                    ForEach(BrowserCookies.allCases.filter { $0.ytDlpName != nil }) { option in
                        Text(option.title).tag(option)
                    }
                }
                Text("Stories de vídeo e imagem usam somente este navegador. Para o Safari, o app precisa de Full Disk Access em System Settings → Privacy & Security.")
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
                Text("Em branco, o BaixaTudo usa as ferramentas que vêm dentro do app.")
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

            Section("Diagnóstico") {
                Toggle("Registrar diagnóstico detalhado", isOn: $settings.diagnosticLogging)
                Text("Registra versões, navegador, leitura de cookies e erros de cada execução. Não faz consultas extras. Valores de cookies e tokens são omitidos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(checkingSession ? "Checking local cookies…" : "Check Instagram session (offline)") {
                    let browser = settings.storyCookiesBrowser
                    let binary = settings.customYTDLPPath
                    checkingSession = true
                    sessionReport = nil
                    Task {
                        defer { checkingSession = false }
                        do {
                            sessionReport = try await YTDLPClient.checkInstagramSession(customBinary: binary, cookies: browser)
                        } catch {
                            sessionReport = error.localizedDescription
                        }
                    }
                }
                .disabled(checkingSession)
                Text("Uses Cookies para Instagram Stories in Geral. This check reads local cookies only; it does not contact Instagram or show cookie values.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let sessionReport {
                    Text(sessionReport)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                Button("Mostrar logs no Finder") {
                    let folder = DiagnosticLog.directory
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(folder)
                    } catch {
                        model.banner = "Não foi possível abrir a pasta de logs: \(error.localizedDescription)"
                    }
                }
            }

            Section("Versão") {
                LabeledContent("BaixaTudo") {
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
