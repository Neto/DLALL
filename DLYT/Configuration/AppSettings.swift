import Foundation

@Observable
@MainActor
final class AppSettings {
    var defaultQuality: VideoQuality {
        didSet { defaults.set(defaultQuality.rawValue, forKey: Keys.quality) }
    }

    var cookiesBrowser: BrowserCookies {
        didSet { defaults.set(cookiesBrowser.rawValue, forKey: Keys.cookies) }
    }

    var openWhenDone: Bool {
        didSet { defaults.set(openWhenDone, forKey: Keys.openWhenDone) }
    }

    var revealWhenDone: Bool {
        didSet { defaults.set(revealWhenDone, forKey: Keys.revealWhenDone) }
    }

    var customYTDLPPath: String {
        didSet { defaults.set(customYTDLPPath, forKey: Keys.ytDlpPath) }
    }

    /// Pasta de destino. `nil` = Pasta Downloads do usuário.
    var outputFolderPath: String {
        didSet { defaults.set(outputFolderPath, forKey: Keys.outputFolder) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let quality = "defaultQuality"
        static let cookies = "cookiesBrowser"
        static let openWhenDone = "openWhenDone"
        static let revealWhenDone = "revealWhenDone"
        static let ytDlpPath = "customYTDLPPath"
        static let outputFolder = "outputFolderPath"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let qualityRaw = defaults.string(forKey: Keys.quality) ?? VideoQuality.best.rawValue
        defaultQuality = VideoQuality(rawValue: qualityRaw) ?? .best
        let cookiesRaw = defaults.string(forKey: Keys.cookies) ?? BrowserCookies.none.rawValue
        cookiesBrowser = BrowserCookies(rawValue: cookiesRaw) ?? .none
        openWhenDone = defaults.object(forKey: Keys.openWhenDone) as? Bool ?? false
        revealWhenDone = defaults.object(forKey: Keys.revealWhenDone) as? Bool ?? true
        customYTDLPPath = defaults.string(forKey: Keys.ytDlpPath) ?? ""
        outputFolderPath = defaults.string(forKey: Keys.outputFolder) ?? ""
    }

    var resolvedOutputFolder: URL {
        if !outputFolderPath.isEmpty {
            return URL(fileURLWithPath: outputFolderPath, isDirectory: true)
        }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Downloads", isDirectory: true)
    }
}
