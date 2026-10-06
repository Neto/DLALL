import Foundation

enum VideoQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case best
    case p1080
    case p720
    case p480
    case audioOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .best: "Melhor qualidade"
        case .p1080: "1080p"
        case .p720: "720p"
        case .p480: "480p"
        case .audioOnly: "Só áudio (MP3)"
        }
    }

    /// Seletor do yt-dlp. Prioriza H.264 + AAC, que o QuickTime abre.
    var ytDlpFormat: String {
        switch self {
        case .best:
            Self.mp4Format(maxHeight: nil)
        case .p1080:
            Self.mp4Format(maxHeight: 1080)
        case .p720:
            Self.mp4Format(maxHeight: 720)
        case .p480:
            Self.mp4Format(maxHeight: 480)
        case .audioOnly:
            "bestaudio/best"
        }
    }

    var extractsAudio: Bool { self == .audioOnly }

    var prefersQuickTime: Bool { !extractsAudio }

    /// `avc1` = H.264. Se o YouTube não oferecer, cai no melhor disponível e o app reconverte.
    private static func mp4Format(maxHeight: Int?) -> String {
        let h = maxHeight.map { "[height<=\($0)]" } ?? ""
        return "bv*\(h)[vcodec^=avc1]+ba[acodec^=mp4a]/bv*\(h)[vcodec^=avc1]+ba[ext=m4a]/bv*\(h)+ba[ext=m4a]/bv*\(h)+ba/b\(h)"
    }
}
