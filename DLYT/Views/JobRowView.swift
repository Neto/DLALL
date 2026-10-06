import SwiftUI

struct JobRowView: View {
    @Environment(LibraryModel.self) private var model
    let job: DownloadJob

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(job.title)
                        .font(.headline)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Spacer(minLength: 8)
                    Label(job.platform.title, systemImage: job.platform.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }

                metadataLine

                statusBlock
            }
            actions
        }
        .padding(.vertical, 4)
        .contextMenu { menuItems }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var thumbnail: some View {
        Group {
            if let url = job.info?.thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    default:
                        placeholder
                            .overlay { ProgressView().controlSize(.small) }
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
                Image(systemName: job.platform.systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }

    @ViewBuilder
    private var metadataLine: some View {
        HStack(spacing: 8) {
            if let uploader = job.info?.uploader, !uploader.isEmpty {
                Text(uploader)
                    .lineLimit(1)
            }
            if let duration = job.info?.durationLabel {
                Text(duration)
                    .monospacedDigit()
            }
            Text(job.quality.title)
            if let output = job.outputURL {
                Text(output.lastPathComponent)
                    .lineLimit(1)
                    .help(output.path)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var statusBlock: some View {
        switch job.status {
        case .fetchingInfo:
            ProgressView(job.statusDetail ?? "Buscando informações…")
                .controlSize(.small)
        case .downloading(let fraction, let speed, let eta):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                HStack {
                    Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    if let speed { Text(speed) }
                    if let eta { Text("resta \(eta)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        case .processing:
            ProgressView(job.statusDetail ?? "Preparando o arquivo…")
                .controlSize(.small)
        case .completed:
            Label("Concluído", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .failed(let message):
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        case .cancelled:
            Label("Cancelado", systemImage: "xmark.circle")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if job.status.isActive {
                Button("Cancelar") {
                    model.cancel(job.id)
                }
            } else if case .completed = job.status {
                Button("Mostrar") { model.reveal(job.id) }
                Button("Abrir") { model.open(job.id) }
            } else {
                Button("Tentar de Novo") { model.retry(job.id) }
                Button("Remover", role: .destructive) { model.remove(job.id) }
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .frame(minWidth: 88, alignment: .trailing)
    }

    @ViewBuilder
    private var menuItems: some View {
        if case .completed = job.status {
            Button("Mostrar no Finder", systemImage: "folder") { model.reveal(job.id) }
            Button("Abrir", systemImage: "play.circle") { model.open(job.id) }
        }
        if job.status.isActive {
            Button("Cancelar") { model.cancel(job.id) }
        } else {
            Button("Tentar de Novo", systemImage: "arrow.clockwise") { model.retry(job.id) }
        }
        Button("Copiar URL", systemImage: "doc.on.clipboard") { model.copyURL(job.id) }
        Divider()
        Button("Remover da Lista", role: .destructive) { model.remove(job.id) }
    }

    private var accessibilitySummary: String {
        var parts = [job.platform.title, job.title]
        switch job.status {
        case .fetchingInfo: parts.append("buscando informações")
        case .downloading(let fraction, _, _):
            parts.append("baixando \(Int(fraction * 100)) por cento")
        case .processing: parts.append("processando")
        case .completed: parts.append("concluído")
        case .failed(let message): parts.append("falhou: \(message)")
        case .cancelled: parts.append("cancelado")
        }
        return parts.joined(separator: ", ")
    }
}
