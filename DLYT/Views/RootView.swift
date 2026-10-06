import SwiftUI

struct RootView: View {
    @Environment(LibraryModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            VStack(spacing: 0) {
                ComposerView()
                    .padding(16)

                Divider()

                if let banner = model.banner {
                    bannerBar(banner)
                }

                engineBar

                if model.jobs.isEmpty {
                    EmptyQueueView()
                } else {
                    List {
                        ForEach(model.jobs) { job in
                            JobRowView(job: job)
                                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        }
                    }
                    .listStyle(.inset)
                    .alternatingRowBackgrounds(.disabled)
                }
            }
            .navigationTitle("DLYT")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if model.activeCount > 0 {
                        Text(model.activeCount == 1 ? "1 em andamento" : "\(model.activeCount) em andamento")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Limpar Concluídos", systemImage: "trash") {
                        model.clearFinished()
                    }
                    .disabled(!model.jobs.contains { $0.status.isFinished })
                    .help("Remove da lista os itens já concluídos, cancelados ou com erro.")
                }
            }
            .onDrop(of: [.url, .plainText], isTargeted: nil, perform: handleDrop)
            .onAppear { model.quality = settings.defaultQuality }
            .frame(minWidth: 640, minHeight: 460)
        }
    }

    @ViewBuilder
    private var engineBar: some View {
        switch model.engineStatus {
        case .missing(let message):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.yellow.opacity(0.12))
        case .ready, .unknown:
            EmptyView()
        }
    }

    private func bannerBar(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
            Spacer()
            Button("OK") { model.banner = nil }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.4))
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var found = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
                    Task { @MainActor in
                        model.enqueue(url: url.absoluteString)
                    }
                }
                found = true
            } else if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                    guard let string = string as? String else { return }
                    Task { @MainActor in
                        model.enqueue(url: string)
                    }
                }
                found = true
            }
        }
        return found
    }
}

struct EmptyQueueView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Nenhum download", systemImage: "arrow.down.circle")
        } description: {
            Text("Cole um link do YouTube, Instagram, TikTok ou Vimeo e clique em Baixar.\nUse apenas conteúdo que você tem direito de baixar.")
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let settings = AppSettings()
    RootView()
        .environment(settings)
        .environment(LibraryModel(settings: settings))
        .frame(width: 760, height: 560)
}
