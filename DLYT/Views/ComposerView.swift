import SwiftUI

struct ComposerView: View {
    @Environment(LibraryModel.self) private var model
    @FocusState private var urlFocused: Bool

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                TextField("Cole o URL do vídeo", text: $model.draftURL)
                    .textFieldStyle(.roundedBorder)
                    .focused($urlFocused)
                    .onSubmit(submit)
                    .accessibilityLabel("URL do vídeo")

                Picker("Qualidade", selection: $model.quality) {
                    ForEach(VideoQuality.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 160)
                .accessibilityLabel("Qualidade")
                .help("Qualidade do arquivo baixado.")

                Button("Baixar", systemImage: "arrow.down.circle.fill", action: submit)
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canSubmit)
                    .keyboardShortcut(.defaultAction)
                    .help("Busca o vídeo e inicia o download.")
            }

            HStack(spacing: 12) {
                platformHint
                Spacer()
                Button("Colar", systemImage: "doc.on.clipboard") {
                    model.pasteFromClipboard()
                    urlFocused = true
                }
                .buttonStyle(.borderless)
                .help("Cola um URL da área de transferência.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .onAppear {
            urlFocused = true
        }
    }

    @ViewBuilder
    private var platformHint: some View {
        if let url = URLExtractor.firstHTTPURL(in: model.draftURL) {
            let platform = MediaPlatform.detect(from: url)
            Label(platform.title, systemImage: platform.systemImage)
                .foregroundStyle(platform == .other ? .secondary : .primary)
        } else {
            Text("YouTube, Instagram, TikTok ou Vimeo")
        }
    }

    private func submit() {
        model.enqueueDraft()
    }
}
