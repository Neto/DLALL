import AppKit
import Foundation

@Observable
@MainActor
final class LibraryModel {
    var jobs: [DownloadJob] = []
    var draftURL: String = ""
    var quality: VideoQuality
    var engineStatus: EngineStatus = .unknown
    var banner: String?

    private let settings: AppSettings
    private var tasks: [UUID: Task<Void, Never>] = [:]

    enum EngineStatus: Equatable {
        case unknown
        case ready(ytDlp: String, ffmpeg: String, deno: Bool)
        case missing(String)
    }

    init(settings: AppSettings) {
        self.settings = settings
        self.quality = settings.defaultQuality
    }

    var canSubmit: Bool {
        URLExtractor.firstHTTPURL(in: draftURL) != nil && !isEngineMissing
    }

    var isEngineMissing: Bool {
        if case .missing = engineStatus { return true }
        return false
    }

    var activeCount: Int {
        jobs.filter { $0.status.isActive }.count
    }

    func refreshEngine() {
        if let yt = BinaryLocator.findYTDLP(customPath: settings.customYTDLPPath) {
            if let ffmpeg = BinaryLocator.findFFmpeg() {
                engineStatus = .ready(
                    ytDlp: yt.path,
                    ffmpeg: ffmpeg.path,
                    deno: BinaryLocator.findDeno() != nil
                )
                if banner?.contains("não encontrado") == true {
                    banner = nil
                }
            } else {
                engineStatus = .missing("Falta o conversor de vídeo neste app. Reinstale o DLYT.")
            }
        } else {
            engineStatus = .missing("Faltam os componentes de download neste app. Reinstale o DLYT.")
        }
    }

    func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
              let url = URLExtractor.firstHTTPURL(in: text) else { return }
        draftURL = url
    }

    func enqueueDraft() {
        let chunks = URLExtractor.allHTTPURLs(in: draftURL)
        let urls = chunks.isEmpty ? [URLExtractor.firstHTTPURL(in: draftURL)].compactMap { $0 } : chunks
        guard !urls.isEmpty else {
            banner = "Cole um link do YouTube, Instagram, TikTok ou Vimeo."
            return
        }
        banner = nil
        draftURL = ""
        for url in urls {
            startJob(url: url, quality: quality)
        }
    }

    func enqueue(url: String) {
        guard let clean = URLExtractor.firstHTTPURL(in: url) else { return }
        startJob(url: clean, quality: quality)
    }

    func cancel(_ id: UUID) {
        tasks[id]?.cancel()
        tasks[id] = nil
        update(id) { job in
            if job.status.isActive {
                job.status = .cancelled
                job.finishedAt = .now
            }
        }
    }

    func retry(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }) else { return }
        startJob(url: job.sourceURL, quality: job.quality)
    }

    func remove(_ id: UUID) {
        cancel(id)
        jobs.removeAll { $0.id == id }
    }

    func clearFinished() {
        jobs.removeAll { $0.status.isFinished }
    }

    func reveal(_ id: UUID) {
        guard let url = jobs.first(where: { $0.id == id })?.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func open(_ id: UUID) {
        guard let url = jobs.first(where: { $0.id == id })?.outputURL else { return }
        NSWorkspace.shared.open(url)
    }

    func copyURL(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(job.sourceURL, forType: .string)
    }

    // MARK: - Private

    private func startJob(url: String, quality: VideoQuality) {
        refreshEngine()
        if isEngineMissing {
            banner = {
                if case .missing(let message) = engineStatus { return message }
                return nil
            }()
            return
        }

        let job = DownloadJob(
            sourceURL: url,
            platform: MediaPlatform.detect(from: url),
            quality: quality
        )
        let id = job.id
        jobs.insert(job, at: 0)

        let settings = self.settings
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let info = try await YTDLPClient.fetchInfo(
                    url: url,
                    customBinary: settings.customYTDLPPath,
                    cookies: settings.cookiesBrowser
                ) { [weak self] line in
                    guard let detail = YTDLPClient.statusLine(from: line) else { return }
                    Task { @MainActor in
                        self?.update(id) { current in
                            guard case .fetchingInfo = current.status else { return }
                            current.statusDetail = detail
                        }
                    }
                }
                if Task.isCancelled { return }
                self.update(id) { current in
                    current.info = info
                    if current.platform == .other, let extractor = info.extractor?.lowercased() {
                        if extractor.contains("youtube") { current.platform = .youtube }
                        else if extractor.contains("instagram") { current.platform = .instagram }
                        else if extractor.contains("tiktok") { current.platform = .tiktok }
                        else if extractor.contains("vimeo") { current.platform = .vimeo }
                    }
                    current.status = .downloading(fraction: 0, speed: nil, eta: nil)
                }

                let file = try await YTDLPClient.download(
                    url: url,
                    quality: quality,
                    outputFolder: settings.resolvedOutputFolder,
                    customBinary: settings.customYTDLPPath,
                    cookies: info.resolvedCookies
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.update(id) { current in
                            guard current.status.isActive else { return }
                            if progress.isProcessing {
                                current.status = .processing
                                current.statusDetail = progress.detail ?? "Preparando o arquivo…"
                            } else {
                                current.status = .downloading(
                                    fraction: progress.fraction,
                                    speed: progress.speed,
                                    eta: progress.eta
                                )
                            }
                        }
                    }
                }

                if Task.isCancelled { return }
                self.update(id) { current in
                    current.outputURL = file
                    current.status = .completed
                    current.finishedAt = .now
                }
                if settings.revealWhenDone {
                    NSWorkspace.shared.activateFileViewerSelecting([file])
                }
                if settings.openWhenDone {
                    NSWorkspace.shared.open(file)
                }
            } catch is CancellationError {
                self.update(id) { current in
                    current.status = .cancelled
                    current.finishedAt = .now
                }
            } catch let error as YTDLPError {
                if case .cancelled = error {
                    self.update(id) { current in
                        current.status = .cancelled
                        current.finishedAt = .now
                    }
                } else {
                    self.update(id) { current in
                        current.status = .failed(error.localizedDescription)
                        current.finishedAt = .now
                    }
                }
            } catch {
                if Task.isCancelled {
                    self.update(id) { current in
                        current.status = .cancelled
                        current.finishedAt = .now
                    }
                } else {
                    self.update(id) { current in
                        current.status = .failed(error.localizedDescription)
                        current.finishedAt = .now
                    }
                }
            }
            self.tasks[id] = nil
        }
        tasks[id] = task
    }

    private func update(_ id: UUID, mutate: (inout DownloadJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&jobs[index])
    }
}
