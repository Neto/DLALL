import AppKit
import Foundation

@Observable
@MainActor
final class LibraryModel {
    var jobs: [DownloadJob] = []
    var draftURL: String = "" {
        didSet {
            guard draftURL != oldValue else { return }
            scheduleQualityProbe()
        }
    }
    var quality: VideoQuality
    /// Opções do seletor para o URL atual; vazio enquanto não há URL válido ou a busca não terminou.
    var availableQualities: [VideoQuality] = []
    var isProbingQuality = false
    /// true quando o URL atual é uma foto/carrossel do Instagram: sem seletor de qualidade, baixa tudo.
    var isImageOnly = false
    /// Quantidade de itens do carrossel (1 pra post único); só relevante quando `isImageOnly`.
    var imageCount = 1
    var engineStatus: EngineStatus = .unknown
    var banner: String?

    private let settings: AppSettings
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var probeTask: Task<Void, Never>?
    /// Info já buscada pela sondagem de qualidade, reaproveitada no download pra não buscar de novo.
    private var probedInfo: (url: String, info: VideoInfo)?
    /// Navegador que funcionou da última vez, tentado primeiro no modo Automático.
    private var lastWorkingCookies: BrowserCookies?
    /// Início de uma etapa de conversão sem % real (Merger/ExtractAudio), pra estimar com o tempo decorrido.
    private var processingStartedAt: [UUID: Date] = [:]
    /// Última vez que aplicamos uma % de download pra esse job — o yt-dlp manda dezenas de
    /// linhas por segundo numa conexão rápida, mais rápido do que a tela consegue redesenhar;
    /// sem isso, a SwiftUI só chega a pintar a primeira e a última (parece "pula de 0% pra 100%").
    private var lastDownloadUpdateAt: [UUID: Date] = [:]

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
            && !isProbingQuality && (!availableQualities.isEmpty || isImageOnly)
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
                engineStatus = .missing("Falta o conversor de vídeo neste app. Reinstale o BaixaTudo.")
            }
        } else {
            engineStatus = .missing("Faltam os componentes de download neste app. Reinstale o BaixaTudo.")
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

    /// Busca os formatos disponíveis do URL colado para popular o seletor de qualidade
    /// e pré-selecionar o maior H.264 encontrado. Enquanto roda, o seletor e o botão
    /// de baixar ficam desabilitados (ver `canSubmit`).
    private func scheduleQualityProbe() {
        probeTask?.cancel()
        guard let url = URLExtractor.firstHTTPURL(in: draftURL) else {
            probeTask = nil
            isProbingQuality = false
            availableQualities = []
            isImageOnly = false
            probedInfo = nil
            return
        }

        isProbingQuality = true
        availableQualities = []
        isImageOnly = false
        let settings = self.settings
        probeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            do {
                let info = try await YTDLPClient.fetchInfo(
                    url: url,
                    customBinary: settings.customYTDLPPath,
                    cookies: settings.cookiesBrowser,
                    preferringCookies: self.lastWorkingCookies
                )
                guard !Task.isCancelled else { return }
                self.probedInfo = (url: url, info: info)
                self.lastWorkingCookies = info.resolvedCookies
                if info.isImagePost {
                    self.availableQualities = []
                    self.isImageOnly = true
                    self.imageCount = max(info.imageCount, 1)
                } else if let maxHeight = info.availableHeights.max() {
                    self.availableQualities = VideoQuality.options(
                        forMaxHeight: maxHeight,
                        highFPSHeights: info.highFPSHeights
                    )
                    self.quality = info.bestH264Height.map(VideoQuality.bestH264Tier(forHeight:)) ?? .best
                } else {
                    // Extrator não informou formatos (ou falhou em listá-los): cai nas opções genéricas.
                    self.availableQualities = VideoQuality.allCases
                    self.quality = settings.defaultQuality
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.probedInfo = nil
                self.availableQualities = VideoQuality.allCases
                self.quality = settings.defaultQuality
            }
            self.isProbingQuality = false
        }
    }

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

        // Reaproveita a info já buscada pela sondagem de qualidade pra esse mesmo URL,
        // em vez de buscar tudo de novo (webpage, formatos, cookies...).
        let reusedInfo: VideoInfo? = probedInfo?.url == url ? probedInfo?.info : nil
        if reusedInfo != nil { probedInfo = nil }
        let preferredCookies = lastWorkingCookies

        let settings = self.settings
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let info: VideoInfo
                if let reusedInfo {
                    info = reusedInfo
                } else {
                    info = try await YTDLPClient.fetchInfo(
                        url: url,
                        customBinary: settings.customYTDLPPath,
                        cookies: settings.cookiesBrowser,
                        preferringCookies: preferredCookies
                    ) { [weak self] line in
                        guard let detail = YTDLPClient.statusLine(from: line) else { return }
                        Task { @MainActor in
                            self?.update(id) { current in
                                guard case .fetchingInfo = current.status else { return }
                                current.statusDetail = detail
                            }
                        }
                    }
                }
                self.lastWorkingCookies = info.resolvedCookies
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

                let onProgress: @Sendable (DownloadProgress) -> Void = { [weak self] progress in
                    Task { @MainActor in
                        guard let self else { return }
                        if progress.isProcessing {
                            let fraction = self.estimatedProcessingFraction(id: id, known: progress.fraction)
                            self.update(id) { current in
                                guard current.status.isActive else { return }
                                current.status = .processing(fraction: fraction)
                                current.statusDetail = progress.detail ?? "Convertendo…"
                            }
                        } else {
                            self.processingStartedAt[id] = nil
                            guard self.shouldApplyDownloadUpdate(id: id, fraction: progress.fraction) else { return }
                            self.update(id) { current in
                                guard current.status.isActive else { return }
                                current.status = .downloading(
                                    fraction: progress.fraction,
                                    speed: progress.speed,
                                    eta: progress.eta
                                )
                            }
                        }
                    }
                }

                // Instagram sem legenda: título vem "Video by X"/"Photo by X" — troca pelo
                // username limpo (`channel`) só nesse caso; outras plataformas ficam com o
                // `%(title)` normal do yt-dlp (preserva a sanitização dele pro nome do arquivo).
                let titleOverride: String? = info.fileNameTitle != info.title ? info.fileNameTitle : nil

                let file: URL
                if info.isImagePost {
                    let postFolder = settings.resolvedOutputFolder
                        .appendingPathComponent(Self.postFolderName(title: info.fileNameTitle, id: info.id))
                    _ = try await YTDLPClient.downloadImages(
                        url: url,
                        outputFolder: postFolder,
                        customBinary: settings.customYTDLPPath,
                        cookies: info.resolvedCookies,
                        onProgress: onProgress
                    )
                    file = postFolder
                } else {
                    file = try await YTDLPClient.download(
                        url: url,
                        quality: quality,
                        outputFolder: settings.resolvedOutputFolder,
                        customBinary: settings.customYTDLPPath,
                        cookies: info.resolvedCookies,
                        titleOverride: titleOverride,
                        onProgress: onProgress
                    )
                }

                if Task.isCancelled { return }
                processingStartedAt[id] = nil
                self.update(id) { current in
                    current.outputURL = file
                    current.status = .completed
                    current.finishedAt = .now
                }
                Self.playCompletionSound()
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
            self.processingStartedAt[id] = nil
            self.lastDownloadUpdateAt[id] = nil
        }
        tasks[id] = task
    }

    /// Limita a cadência de atualizações de % de download pra ~1 a cada 150ms, deixando a
    /// primeira e a conclusão (fraction nil ou >= 1) sempre passarem direto.
    private func shouldApplyDownloadUpdate(id: UUID, fraction: Double?) -> Bool {
        guard let fraction, fraction < 1 else {
            lastDownloadUpdateAt[id] = nil
            return true
        }
        let now = Date()
        if let last = lastDownloadUpdateAt[id], now.timeIntervalSince(last) < 0.15 {
            return false
        }
        lastDownloadUpdateAt[id] = now
        return true
    }

    /// Quando o yt-dlp não informa % real de conversão (Merger/ExtractAudio), estima com uma
    /// curva que sobe rápido e desacelera perto de 95%, até a etapa de fato terminar.
    private func estimatedProcessingFraction(id: UUID, known: Double?) -> Double? {
        guard let known else {
            let start = processingStartedAt[id] ?? Date()
            processingStartedAt[id] = start
            let elapsed = Date().timeIntervalSince(start)
            return min(1 - exp(-elapsed / 4), 0.95)
        }
        processingStartedAt[id] = nil
        return known
    }

    private func update(_ id: UUID, mutate: (inout DownloadJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&jobs[index])
    }

    /// Nome da subpasta de um post de imagens: "<título> [<id>]", sem barras.
    private static func postFolderName(title: String, id: String) -> String {
        let base = title.isEmpty ? id : title
        let sanitized = base.replacingOccurrences(of: "/", with: "-")
        return "\(sanitized.prefix(120)) [\(id)]"
    }

    /// Avisa que terminou (download + conversão, se teve).
    private static func playCompletionSound() {
        guard let url = Bundle.main.url(forResource: "Funk", withExtension: "aiff") else { return }
        NSSound(contentsOf: url, byReference: true)?.play()
    }
}
