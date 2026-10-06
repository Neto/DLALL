import Foundation

struct VideoInfo: Sendable, Equatable {
    var id: String
    var title: String
    var thumbnailURL: URL?
    var duration: TimeInterval?
    var uploader: String?
    var webpageURL: String?
    var extractor: String?

    var durationLabel: String? {
        guard let duration, duration.isFinite, duration > 0 else { return nil }
        let total = Int(duration.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Subconjunto do JSON do `yt-dlp -J`.
struct YTDLPInfoDTO: Decodable, Sendable {
    var id: String?
    var title: String?
    var thumbnail: String?
    var duration: Double?
    var uploader: String?
    var channel: String?
    var webpageUrl: String?
    var originalUrl: String?
    var extractor: String?
    var extractorKey: String?

    enum CodingKeys: String, CodingKey {
        case id, title, thumbnail, duration, uploader, channel, extractor
        case webpageUrl = "webpage_url"
        case originalUrl = "original_url"
        case extractorKey = "extractor_key"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        thumbnail = try c.decodeIfPresent(String.self, forKey: .thumbnail)
        uploader = try c.decodeIfPresent(String.self, forKey: .uploader)
        channel = try c.decodeIfPresent(String.self, forKey: .channel)
        webpageUrl = try c.decodeIfPresent(String.self, forKey: .webpageUrl)
        originalUrl = try c.decodeIfPresent(String.self, forKey: .originalUrl)
        extractor = try c.decodeIfPresent(String.self, forKey: .extractor)
        extractorKey = try c.decodeIfPresent(String.self, forKey: .extractorKey)
        if let value = try? c.decode(Double.self, forKey: .duration) {
            duration = value
        } else if let value = try? c.decode(Int.self, forKey: .duration) {
            duration = Double(value)
        } else {
            duration = nil
        }
    }

    func asVideoInfo(fallbackURL: String) -> VideoInfo {
        let thumb = thumbnail.flatMap(URL.init(string:))
        return VideoInfo(
            id: id ?? UUID().uuidString,
            title: (title?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? fallbackURL,
            thumbnailURL: thumb,
            duration: duration,
            uploader: uploader ?? channel,
            webpageURL: webpageUrl ?? originalUrl ?? fallbackURL,
            extractor: extractorKey ?? extractor
        )
    }
}
