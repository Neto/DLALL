import Foundation

enum BrowserCookies: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case safari
    case chrome
    case firefox
    case edge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Nenhum"
        case .safari: "Safari"
        case .chrome: "Chrome"
        case .firefox: "Firefox"
        case .edge: "Edge"
        }
    }

    /// Valor passado a `--cookies-from-browser`.
    var ytDlpName: String? {
        switch self {
        case .none: nil
        case .safari: "safari"
        case .chrome: "chrome"
        case .firefox: "firefox"
        case .edge: "edge"
        }
    }
}
