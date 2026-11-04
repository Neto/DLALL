import SwiftUI

struct HistoryView: View {
    @Environment(LibraryModel.self) private var model
    @State private var search = ""
    @State private var confirmClear = false

    private var filtered: [HistoryEntry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.history }
        return model.history.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.sourceURL.localizedCaseInsensitiveContains(query)
                || ($0.uploader?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        if model.history.isEmpty {
            ContentUnavailableView {
                Label("Histórico vazio", systemImage: "clock.arrow.circlepath")
            } description: {
                Text("Os links que você baixar aparecem aqui.\nDepois, é possível baixar o mesmo link de novo.")
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    TextField("Buscar no histórico", text: $search)
                        .textFieldStyle(.roundedBorder)
                    Text(model.history.count == 1 ? "1 link" : "\(model.history.count) links")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Limpar Histórico", role: .destructive) {
                        confirmClear = true
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                List {
                    ForEach(filtered) { entry in
                        HistoryRowView(entry: entry)
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .alternatingRowBackgrounds(.disabled)
                .overlay {
                    if filtered.isEmpty {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }
            .confirmationDialog(
                "Apagar todo o histórico?",
                isPresented: $confirmClear,
                titleVisibility: .visible
            ) {
                Button("Apagar Histórico", role: .destructive) {
                    model.clearHistory()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Os arquivos baixados não são apagados.")
            }
        }
    }
}

struct HistoryRowView: View {
    @Environment(LibraryModel.self) private var model
    let entry: HistoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.title)
                        .font(.headline)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Spacer(minLength: 8)
                    Label(entry.platform.title, systemImage: entry.platform.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    if let uploader = entry.uploader, !uploader.isEmpty {
                        Text(uploader).lineLimit(1)
                    }
                    Text(entry.quality.title)
                    Text(entry.lastDownloadedAt.formatted(date: .abbreviated, time: .shortened))
                    if entry.downloadCount > 1 {
                        Text("\(entry.downloadCount) downloads")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(entry.sourceURL)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            VStack(alignment: .trailing, spacing: 6) {
                Button("Baixar de Novo") { model.redownload(entry.id) }
                if entry.fileExists {
                    Button("Mostrar") { model.revealHistory(entry.id) }
                }
                Button("Remover", role: .destructive) { model.removeHistory(entry.id) }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .frame(minWidth: 100, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Baixar de Novo", systemImage: "arrow.down.circle") { model.redownload(entry.id) }
            if entry.fileExists {
                Button("Mostrar no Finder", systemImage: "folder") { model.revealHistory(entry.id) }
            }
            Button("Copiar URL", systemImage: "doc.on.clipboard") { model.copyHistoryURL(entry.id) }
            Divider()
            Button("Remover do Histórico", role: .destructive) { model.removeHistory(entry.id) }
        }
    }

    private var thumbnail: some View {
        Group {
            if let url = entry.thumbnailURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 120, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.quaternary)
            .overlay {
                Image(systemName: entry.platform.systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}
