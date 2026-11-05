import SwiftUI

enum BaixaTudoTheme {
    static let base = Color(red: 0.03, green: 0.03, blue: 0.05)
    static let indigo = Color(red: 0.17, green: 0.13, blue: 0.48)
    static let indigoDeep = Color(red: 0.10, green: 0.08, blue: 0.30)
    static let pill = Color.white.opacity(0.12)
}

extension View {
    /// Liquid Glass no macOS 26 ou mais novo. Material translúcido nas versões anteriores.
    @ViewBuilder
    func glassPill<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(macOS 26.0, *) {
            let base: Glass = tint.map { Glass.regular.tint($0) } ?? .regular
            self.glassEffect(interactive ? base.interactive() : base, in: shape)
        } else {
            self.background(shape.fill(tint?.opacity(0.5) ?? BaixaTudoTheme.pill))
        }
    }
}

/// Barra de topo arredondada: gradiente índigo até o preto, nome do app em branco e controles em pílulas.
struct HeaderBarView: View {
    @Environment(LibraryModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    private var canClear: Bool {
        model.jobs.contains { $0.status.isFinished }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("BaixaTudo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                if model.activeCount > 0 {
                    Text(model.activeCount == 1 ? "1 em andamento" : "\(model.activeCount) em andamento")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 34, height: 34)
                        .glassPill(Circle())
                        .foregroundStyle(.white)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Preferências — escolher o navegador, pasta de destino e mais.")
                .accessibilityLabel("Preferências")

                Button {
                    model.clearFinished()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 34, height: 34)
                        .glassPill(Circle(), interactive: canClear)
                        .foregroundStyle(.white.opacity(canClear ? 1 : 0.35))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canClear)
                .help("Remove da lista os itens já concluídos, cancelados ou com erro.")
                .accessibilityLabel("Limpar Concluídos")
            }
            .padding(.leading, 68)
            .frame(height: 32)

            ComposerView()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 28, bottomTrailingRadius: 28, topTrailingRadius: 0, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: BaixaTudoTheme.indigo, location: 0),
                            .init(color: BaixaTudoTheme.indigoDeep, location: 0.5),
                            .init(color: Color.black, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .overlay {
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 28, bottomTrailingRadius: 28, topTrailingRadius: 0, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

#Preview {
    let settings = AppSettings()
    HeaderBarView()
        .environment(settings)
        .environment(LibraryModel(settings: settings))
        .padding(8)
        .frame(width: 760, height: 200)
        .background(BaixaTudoTheme.base)
}
