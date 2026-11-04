import Foundation

enum VideoQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case best
    case p2160
    case p2160p30
    case p1440
    case p1440p30
    case p1080
    case p720
    case p480
    case audioOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .best: "Melhor qualidade"
        case .p2160: "2160p (4K)"
        case .p2160p30: "2160p 30fps"
        case .p1440: "1440p (2K)"
        case .p1440p30: "1440p 30fps"
        case .p1080: "1080p"
        case .p720: "720p"
        case .p480: "480p"
        case .audioOnly: "Só áudio (MP3)"
        }
    }

    /// Altura máxima do tier, ou nil para `.best`/`.audioOnly`.
    var height: Int? {
        switch self {
        case .p2160, .p2160p30: 2160
        case .p1440, .p1440p30: 1440
        case .p1080: 1080
        case .p720: 720
        case .p480: 480
        case .best, .audioOnly: nil
        }
    }

    /// Fps forçado na reconversão pós-download (quando ela for necessária); nil mantém o fps original.
    var targetFPS: Int? {
        switch self {
        case .p2160p30, .p1440p30: 30
        default: nil
        }
    }

    /// Variante "30fps" do tier, se houver.
    private var thirtyFPSVariant: VideoQuality? {
        switch self {
        case .p2160: .p2160p30
        case .p1440: .p1440p30
        default: nil
        }
    }

    /// Seletor do yt-dlp. A resolução manda; o `-S` (ver YTDLPClient) escolhe H.264
    /// quando ele existir naquela resolução, senão cai no melhor disponível e o app reconverte.
    var ytDlpFormat: String {
        switch self {
        case .audioOnly:
            "bestaudio/best"
        default:
            Self.mp4Format(maxHeight: height)
        }
    }

    var extractsAudio: Bool { self == .audioOnly }

    var prefersQuickTime: Bool { !extractsAudio }

    private static func mp4Format(maxHeight: Int?) -> String {
        let h = maxHeight.map { "[height<=\($0)]" } ?? ""
        return "bv*\(h)+ba/b\(h)"
    }

    /// Tiers de resolução, da maior para a menor.
    private static let resolutionTiers: [VideoQuality] = [.p2160, .p1440, .p1080, .p720, .p480]

    /// Opções a mostrar no seletor, dado o maior height encontrado e os heights com fps > 30.
    static func options(forMaxHeight maxHeight: Int, highFPSHeights: Set<Int> = []) -> [VideoQuality] {
        var result: [VideoQuality] = [.best]
        for tier in resolutionTiers where (tier.height ?? 0) <= maxHeight {
            result.append(tier)
            if let height = tier.height, highFPSHeights.contains(height), let p30 = tier.thirtyFPSVariant {
                result.append(p30)
            }
        }
        result.append(.audioOnly)
        return result
    }

    /// Tier mais próximo (por baixo) do maior height H.264 encontrado.
    static func bestH264Tier(forHeight height: Int) -> VideoQuality {
        resolutionTiers.first { ($0.height ?? 0) <= height } ?? .p480
    }
}
