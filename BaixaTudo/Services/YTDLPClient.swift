import Foundation

enum YTDLPError: LocalizedError, Sendable {
    case binaryMissing
    case ffmpegMissing
    case invalidURL
    case cancelled
    case badJSON
    case timeout
    case failed(status: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .binaryMissing:
            "Faltam os componentes de download neste app. Reinstale o BaixaTudo."
        case .ffmpegMissing:
            "Falta o conversor de vídeo neste app. Reinstale o BaixaTudo."
        case .invalidURL:
            "URL inválida."
        case .cancelled:
            "Download cancelado."
        case .badJSON:
            "Não foi possível ler as informações do vídeo."
        case .timeout:
            "O yt-dlp demorou demais para responder. Tente de novo."
        case .failed(_, let message):
            message
        }
    }
}

enum YTDLPClient: Sendable {
    private static let infoJSONFields =
        "%(.{id,title,thumbnail,duration,uploader,channel,webpage_url,original_url,extractor,extractor_key,formats})j"

    static let loginMessage =
        "Este link exige login. Entre na sua conta no Safari ou no Chrome (o BaixaTudo usa os cookies do navegador sozinho) e tente de novo."
    static let permissionMessage =
        "O BaixaTudo não conseguiu ler os cookies do navegador. Abra System Settings > Privacy & Security > Full Disk Access, ative o BaixaTudo e tente de novo."

    static func cookieCandidates(for cookies: BrowserCookies) -> [BrowserCookies] {
        cookies == .auto ? [.none] + BrowserCookies.automaticChain : [cookies]
    }

    private static func needsAnotherBrowser(_ error: YTDLPError) -> Bool {
        if case .failed(_, let message) = error {
            return message == loginMessage || message == permissionMessage
        }
        return false
    }

    /// Prefere o erro de permissão (acionável); senão o primeiro.
    private static func pickError(_ errors: [Error]) -> Error {
        for case let error as YTDLPError in errors {
            if case .failed(_, let message) = error, message == permissionMessage { return error }
        }
        return errors.first ?? YTDLPError.invalidURL
    }

    static func fetchInfo(
        url: String,
        customBinary: String,
        cookies: BrowserCookies,
        onLine: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> VideoInfo {
        var errors: [Error] = []
        for candidate in candidateURLs(for: url) {
            for cookie in cookieCandidates(for: cookies) {
                if cookie != .none, cookies == .auto {
                    onLine("Tentando com os cookies do \(cookie.title)…")
                }
                do {
                    var info = try await fetchInfoOnce(
                        url: candidate,
                        customBinary: customBinary,
                        cookies: cookie,
                        onLine: onLine
                    )
                    if candidate != url, info.webpageURL == candidate { info.webpageURL = url }
                    info.resolvedCookies = cookie
                    return info
                } catch let error as YTDLPError {
                    if case .cancelled = error { throw error }
                    errors.append(error)
                    if !needsAnotherBrowser(error) { break }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    errors.append(error)
                    break
                }
            }
        }
        throw pickError(errors)
    }

    private static func fetchInfoOnce(
        url: String,
        customBinary: String,
        cookies: BrowserCookies,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> VideoInfo {
        let binary = try requireBinary(customPath: customBinary)
        var arguments = baseArguments(cookies: cookies)
        arguments += [
            "--skip-download",
            "--no-playlist",
            "--print", infoJSONFields,
            url,
        ]

        let result = try await run(
            binary: binary,
            arguments: arguments,
            timeout: .seconds(90),
            onLine: onLine
        )
        if result.status != 0 {
            DiagnosticLog.write("fetchInfo cookies=\(cookies.rawValue) url=\(url) status=\(result.status) log=\(result.log)")
            throw YTDLPError.failed(status: result.status, message: friendlyMessage(from: result.log, url: url))
        }
        let trimmed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let data = String(trimmed[start...]).data(using: .utf8) else {
            throw YTDLPError.badJSON
        }
        let dto = try JSONDecoder().decode(YTDLPInfoDTO.self, from: data)
        return dto.asVideoInfo(fallbackURL: url)
    }

    static func download(
        url: String,
        quality: VideoQuality,
        outputFolder: URL,
        customBinary: String,
        cookies: BrowserCookies,
        onProgress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> URL {
        var errors: [Error] = []
        for candidate in candidateURLs(for: url) {
            for cookie in cookieCandidates(for: cookies) {
                do {
                    return try await downloadOnce(
                        url: candidate,
                        quality: quality,
                        outputFolder: outputFolder,
                        customBinary: customBinary,
                        cookies: cookie,
                        onProgress: onProgress
                    )
                } catch let error as YTDLPError {
                    if case .cancelled = error { throw error }
                    errors.append(error)
                    if !needsAnotherBrowser(error) { break }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    errors.append(error)
                    break
                }
            }
        }
        throw pickError(errors)
    }

    private static func downloadOnce(
        url: String,
        quality: VideoQuality,
        outputFolder: URL,
        customBinary: String,
        cookies: BrowserCookies,
        onProgress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> URL {
        let binary = try requireBinary(customPath: customBinary)
        guard BinaryLocator.findFFmpeg() != nil else { throw YTDLPError.ffmpegMissing }

        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        let template = outputFolder
            .appendingPathComponent("%(title).180B [%(id)s].%(ext)s")
            .path

        var arguments = baseArguments(cookies: cookies)
        arguments += [
            "--newline",
            "--no-playlist",
            "--no-mtime",
            "-f", quality.ytDlpFormat,
            "-o", template,
            "--print", "after_move:filepath",
        ]

        if quality.extractsAudio {
            arguments += ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        } else {
            arguments += [
                "-S", "res,vcodec:h264,acodec:mp4a,ext:mp4:m4a",
                "--merge-output-format", "mp4",
            ]
        }

        arguments.append(url)

        let destination = PathBox()
        let result = try await run(
            binary: binary,
            arguments: arguments,
            timeout: nil,
            onLine: { line in
                if let parsed = ProgressParser.parse(line) {
                    if let dest = parsed.destinationPath {
                        destination.set(dest)
                    }
                    onProgress(parsed)
                } else if looksLikeFilePath(line) {
                    destination.set(line.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        )

        if Task.isCancelled { throw YTDLPError.cancelled }
        if result.status != 0 {
            DiagnosticLog.write("download cookies=\(cookies.rawValue) url=\(url) status=\(result.status) log=\(result.log)")
            throw YTDLPError.failed(status: result.status, message: friendlyMessage(from: result.log, url: url))
        }

        let file: URL
        if let lastDestination = destination.get(), FileManager.default.fileExists(atPath: lastDestination) {
            file = URL(fileURLWithPath: lastDestination)
        } else if let newest = newestFile(in: outputFolder, createdAfter: result.startedAt) {
            file = newest
        } else {
            throw YTDLPError.failed(
                status: result.status,
                message: "O download terminou, mas o arquivo não foi encontrado na pasta de destino."
            )
        }

        if quality.prefersQuickTime {
            return try await ensureQuickTimeCompatible(file, targetFPS: quality.targetFPS, onProgress: onProgress)
        }
        return file
    }

    // MARK: - Vimeo

    /// Ordem de tentativa. Vimeo: o player embutido funciona sem login; a página normal vem como reserva.
    static func candidateURLs(for url: String) -> [String] {
        if let player = vimeoPlayerURL(from: url), player != url {
            return [player, url]
        }
        return [url]
    }

    /// vimeo.com/ID, vimeo.com/ID/HASH, /channels/x/ID, /groups/x/videos/ID, /album/n/video/ID → player.vimeo.com/video/ID[?h=HASH]
    static func vimeoPlayerURL(from rawURL: String) -> String? {
        guard let components = URLComponents(string: rawURL),
              let host = components.host?.lowercased(),
              host == "vimeo.com" || host.hasSuffix(".vimeo.com"),
              host != "player.vimeo.com" else { return nil }

        let parts = components.path.split(separator: "/").map(String.init)
        func isDigits(_ s: String) -> Bool { !s.isEmpty && s.allSatisfy(\.isNumber) }

        var idIndex: Int?
        if let marker = parts.firstIndex(where: { $0 == "video" || $0 == "videos" }),
           marker + 1 < parts.count, isDigits(parts[marker + 1]) {
            idIndex = marker + 1
        } else if let first = parts.first, ["channels", "groups"].contains(first) {
            idIndex = parts.lastIndex(where: isDigits)
        } else if let first = parts.first, isDigits(first) {
            idIndex = 0
        }
        guard let index = idIndex else { return nil }

        var hash: String?
        if index + 1 < parts.count {
            let candidate = parts[index + 1]
            if candidate.count >= 8, candidate.allSatisfy({ $0.isLetter || $0.isNumber }) {
                hash = candidate
            }
        }
        if hash == nil {
            hash = components.queryItems?.first(where: { $0.name == "h" })?.value
        }

        var result = "https://player.vimeo.com/video/\(parts[index])"
        if let hash, !hash.isEmpty { result += "?h=\(hash)" }
        return result
    }

    // MARK: - QuickTime

    private static let quickTimeVideo = Set(["h264", "hevc", "h265", "mpeg4", "prores", "mjpeg"])
    private static let quickTimeAudio = Set(["aac", "alac", "mp3", "ac3", "eac3", "pcm_s16le", "pcm_s24le", "mp2"])

    private static func ensureQuickTimeCompatible(
        _ url: URL,
        targetFPS: Int?,
        onProgress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> URL {
        let probe = try await probeMedia(url)
        let videoOK = probe.videoCodec.map { quickTimeVideo.contains($0) } ?? true
        let audioOK = probe.audioCodec.map { quickTimeAudio.contains($0) } ?? true
        if videoOK && audioOK {
            return url
        }

        onProgress(
            DownloadProgress(
                fraction: 1,
                speed: nil,
                eta: nil,
                isProcessing: true,
                destinationPath: url.path,
                detail: "Convertendo para QuickTime…"
            )
        )

        guard let ffmpeg = BinaryLocator.findFFmpeg() else { throw YTDLPError.ffmpegMissing }
        let temp = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.deletingPathExtension().lastPathComponent).baixatudo-qt.mp4")

        // `-r` só se aplica reconvertendo; com `-c:v copy` ffmpeg recusa mudar o fps.
        let fpsArgs = (videoOK ? nil : targetFPS).map { ["-r", "\($0)"] } ?? []

        var videoArgs: [String]
        if videoOK {
            videoArgs = ["-c:v", "copy"]
        } else {
            videoArgs = fpsArgs + ["-c:v", "h264_videotoolbox", "-b:v", "8M", "-allow_sw", "1", "-tag:v", "avc1"]
        }
        let audioArgs = audioOK
            ? ["-c:a", "copy"]
            : ["-c:a", "aac", "-b:a", "192k"]

        let duration = probe.duration
        func runFFmpeg(video: [String]) async throws -> YTDLPClientRunResult {
            try await run(
                binary: ffmpeg,
                arguments: ["-y", "-i", url.path] + video + audioArgs + [
                    "-movflags", "+faststart",
                    "-progress", "pipe:1",
                    "-nostats",
                    temp.path,
                ],
                timeout: nil,
                onLine: { line in
                    if let fraction = ffmpegFraction(from: line, duration: duration) {
                        onProgress(
                            DownloadProgress(
                                fraction: fraction,
                                speed: nil,
                                eta: nil,
                                isProcessing: true,
                                destinationPath: temp.path,
                                detail: "Convertendo para QuickTime…"
                            )
                        )
                    }
                }
            )
        }

        var result = try await runFFmpeg(video: videoArgs)
        if result.status != 0, !videoOK {
            result = try await runFFmpeg(
                video: fpsArgs + ["-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p"]
            )
        }
        if result.status != 0 {
            try? FileManager.default.removeItem(at: temp)
            throw YTDLPError.failed(
                status: result.status,
                message: "O vídeo baixou, mas a conversão para QuickTime falhou."
            )
        }

        let replacement = url.deletingPathExtension().appendingPathExtension("mp4")
        if FileManager.default.fileExists(atPath: replacement.path) {
            try FileManager.default.removeItem(at: replacement)
        }
        try FileManager.default.moveItem(at: temp, to: replacement)
        if url != replacement, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        return replacement
    }

    private struct MediaProbe: Sendable {
        var videoCodec: String?
        var audioCodec: String?
        var duration: Double?
    }

    private struct FFProbeDTO: Decodable {
        struct Stream: Decodable {
            var codecType: String?
            var codecName: String?
            enum CodingKeys: String, CodingKey {
                case codecType = "codec_type"
                case codecName = "codec_name"
            }
        }
        struct Format: Decodable {
            var duration: String?
        }
        var streams: [Stream]?
        var format: Format?
    }

    private static func probeMedia(_ url: URL) async throws -> MediaProbe {
        guard let ffprobe = BinaryLocator.findFFprobe() ?? BinaryLocator.ffprobeBesideFFmpeg() else {
            return MediaProbe(videoCodec: nil, audioCodec: nil, duration: nil)
        }
        let result = try await run(
            binary: ffprobe,
            arguments: [
                "-v", "error",
                "-print_format", "json",
                "-show_streams",
                "-show_format",
                url.path,
            ],
            timeout: .seconds(30),
            onLine: { _ in }
        )
        guard result.status == 0,
              let data = result.stdout.data(using: .utf8),
              let dto = try? JSONDecoder().decode(FFProbeDTO.self, from: data) else {
            return MediaProbe(videoCodec: nil, audioCodec: nil, duration: nil)
        }
        let video = dto.streams?.first(where: { $0.codecType == "video" })?.codecName
        let audio = dto.streams?.first(where: { $0.codecType == "audio" })?.codecName
        let duration = dto.format?.duration.flatMap(Double.init)
        return MediaProbe(videoCodec: video, audioCodec: audio, duration: duration)
    }

    private static func ffmpegFraction(from line: String, duration: Double?) -> Double? {
        guard let duration, duration > 0 else { return nil }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("out_time_ms=") {
            let value = Double(trimmed.dropFirst("out_time_ms=".count)) ?? 0
            return min(max(value / (duration * 1_000_000), 0), 1)
        }
        if trimmed.hasPrefix("out_time_us=") {
            let value = Double(trimmed.dropFirst("out_time_us=".count)) ?? 0
            return min(max(value / (duration * 1_000_000), 0), 1)
        }
        return nil
    }

    // MARK: - Process

    private static func requireBinary(customPath: String) throws -> URL {
        guard let url = BinaryLocator.findYTDLP(customPath: customPath) else {
            throw YTDLPError.binaryMissing
        }
        return url
    }

    private static func baseArguments(cookies: BrowserCookies) -> [String] {
        var args = [
            "--no-update",
            "--ignore-config",
            "--encoding", "utf-8",
            "--no-colors",
        ]
        if let ffmpeg = BinaryLocator.findFFmpeg() {
            args += ["--ffmpeg-location", ffmpeg.path]
        }
        if let deno = BinaryLocator.findDeno() {
            args += ["--js-runtimes", "deno:\(deno.path)"]
        } else if let node = BinaryLocator.findNode() {
            args += ["--js-runtimes", "node:\(node.path)"]
        }
        if let browser = cookies.ytDlpName {
            args += ["--cookies-from-browser", browser]
        }
        return args
    }

    private static func run(
        binary: URL,
        arguments: [String],
        timeout: Duration?,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> YTDLPClientRunResult {
        let session = ProcessSession()
        let work = Task.detached(priority: .userInitiated) {
            try session.runSync(binary: binary, arguments: arguments, onLine: onLine)
        }

        return try await withTaskCancellationHandler {
            if let timeout {
                try await withThrowingTaskGroup(of: YTDLPClientRunResult.self) { group in
                    group.addTask { try await work.value }
                    group.addTask {
                        try await Task.sleep(for: timeout)
                        session.terminate()
                        throw YTDLPError.timeout
                    }
                    let result = try await group.next()!
                    group.cancelAll()
                    if Task.isCancelled {
                        session.terminate()
                        throw YTDLPError.cancelled
                    }
                    return result
                }
            } else {
                try await work.value
            }
        } onCancel: {
            session.terminate()
            work.cancel()
        }
    }

    private static func newestFile(in folder: URL, createdAfter: Date) -> URL? {
        let cutoff = createdAfter.addingTimeInterval(-2)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        return files
            .compactMap { url -> (URL, Date)? in
                let values = try? url.resourceValues(forKeys: Set(keys))
                guard values?.isRegularFile == true, let date = values?.contentModificationDate, date >= cutoff else {
                    return nil
                }
                return (url, date)
            }
            .max(by: { $0.1 < $1.1 })?
            .0
    }

    private static func looksLikeFilePath(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return false }
        let ext = URL(fileURLWithPath: trimmed).pathExtension.lowercased()
        let known = ["mp4", "m4a", "mp3", "webm", "mkv", "mov", "wav", "opus", "aac"]
        return known.contains(ext)
    }

    static func friendlyMessage(from log: String, url: String) -> String {
        let lower = log.lowercased()
        if lower.contains("vimeo"), lower.contains("password") {
            return "Este vídeo do Vimeo tem senha. O BaixaTudo ainda não aceita vídeos protegidos por senha."
        }
        if lower.contains("vimeo"), lower.contains("referer") || lower.contains("embedding") {
            return "Este vídeo do Vimeo só toca incorporado em outro site. Abra a página do site que o exibe e cole o link dessa página."
        }
        if lower.contains("operation not permitted") || lower.contains("permissionerror")
            || lower.contains("full disk access") || lower.contains("could not find") && lower.contains("cookies") {
            return permissionMessage
        }
        if lower.contains("login") || lower.contains("logged-in") || lower.contains("cookies")
            || lower.contains("sign in") || lower.contains("not a bot") {
            return loginMessage
        }
        if lower.contains("private") || lower.contains("unavailable") {
            return "O vídeo está privado, foi removido ou não está disponível nesta região."
        }
        if lower.contains("unsupported url") || lower.contains("no video") {
            return "Este URL não parece ser um vídeo compatível."
        }
        if lower.contains("http error 429") || lower.contains("too many requests") {
            return "Muitos pedidos seguidos. Espere um pouco e tente de novo."
        }
        let last = log
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty && !$0.hasPrefix("[debug]") && !$0.hasPrefix("WARNING:") }
        return last ?? "Falha ao baixar \(url)."
    }

    static func statusLine(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("[debug]") { return nil }
        if trimmed.hasPrefix("{") { return nil }
        if trimmed.hasPrefix("WARNING:") { return nil }
        if trimmed.hasPrefix("ERROR:") {
            return String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }
}

/// Registro simples em ~/Library/Logs/BaixaTudo.log para diagnosticar falhas (cookies, permissões, bot check).
enum DiagnosticLog: Sendable {
    private static let lock = NSLock()

    static func write(_ message: String) {
        let tail = String(message.suffix(1500)).replacingOccurrences(of: "\n", with: " | ")
        let line = "\(Date().formatted(.iso8601)) \(tail)\n"
        lock.lock()
        defer { lock.unlock() }
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("BaixaTudo.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}

/// Isola o `Process` para cancelamento e leitura incremental (evita deadlock de pipe).
private final class ProcessSession: @unchecked Sendable {
    let process = Process()
    private let lock = NSLock()
    private var didTerminate = false

    func runSync(
        binary: URL,
        arguments: [String],
        onLine: @escaping @Sendable (String) -> Void
    ) throws -> YTDLPClientRunResult {
        process.executableURL = binary
        process.arguments = arguments
        process.environment = BinaryLocator.processEnvironment
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        let stdoutReader = LineAssembler(onLine: onLine)
        let stderrReader = LineAssembler(onLine: onLine)
        let startedAt = Date()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            stdoutReader.ingest(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            stderrReader.ingest(handle.availableData)
        }

        try process.run()
        process.waitUntilExit()

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdoutReader.ingest(stdoutPipe.fileHandleForReading.availableData)
        stderrReader.ingest(stderrPipe.fileHandleForReading.availableData)
        stdoutReader.flush()
        stderrReader.flush()

        return YTDLPClientRunResult(
            status: process.terminationStatus,
            stdout: stdoutReader.text(),
            log: [stdoutReader.text(), stderrReader.text()].joined(separator: "\n"),
            startedAt: startedAt
        )
    }

    func terminate() {
        lock.lock()
        defer { lock.unlock() }
        guard !didTerminate else { return }
        didTerminate = true
        if process.isRunning {
            process.terminate()
        }
    }
}

struct YTDLPClientRunResult: Sendable {
    var status: Int32
    var stdout: String
    var log: String
    var startedAt: Date
}

/// Monta linhas a partir de blocos do pipe — não espera o JSON inteiro chegar.
private final class LineAssembler: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Data()
    private var collected = Data()
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    func ingest(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        collected.append(data)
        pending.append(data)
        while let range = pending.range(of: Data([0x0A])) {
            let lineData = pending.subdata(in: pending.startIndex..<range.lowerBound)
            pending.removeSubrange(pending.startIndex..<range.upperBound)
            lock.unlock()
            emit(lineData)
            lock.lock()
        }
        lock.unlock()
    }

    func flush() {
        lock.lock()
        let rest = pending
        pending.removeAll()
        lock.unlock()
        if !rest.isEmpty {
            emit(rest)
        }
    }

    func text() -> String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: collected, encoding: .utf8)
            ?? String(data: collected, encoding: .isoLatin1)
            ?? ""
    }

    private func emit(_ data: Data) {
        var slice = data
        if slice.last == 0x0D {
            slice.removeLast()
        }
        guard !slice.isEmpty else { return }
        let line = String(data: slice, encoding: .utf8)
            ?? String(data: slice, encoding: .isoLatin1)
            ?? ""
        onLine(line)
    }
}

private final class PathBox: @unchecked Sendable {
    private let lock = NSLock()
    private var path: String?

    func set(_ value: String) {
        lock.lock()
        path = value
        lock.unlock()
    }

    func get() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return path
    }
}

enum ProgressParser {
    private static let percentRegex = try! NSRegularExpression(
        pattern: #"\[download\]\s+(\d+(?:\.\d+)?)%"#
    )
    private static let speedRegex = try! NSRegularExpression(
        pattern: #"at\s+(\S+/s)"#
    )
    private static let etaRegex = try! NSRegularExpression(
        pattern: #"ETA\s+(\S+)"#
    )
    private static let destRegex = try! NSRegularExpression(
        pattern: #"\[download\] Destination:\s+(.+)"#
    )

    static func parse(_ line: String) -> DownloadProgress? {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)

        if ns.range(of: "[Merger]", options: .caseInsensitive).location != NSNotFound
            || ns.range(of: "[ExtractAudio]", options: .caseInsensitive).location != NSNotFound
            || ns.range(of: "[ffmpeg]", options: .caseInsensitive).location != NSNotFound {
            return DownloadProgress(fraction: 1, speed: nil, eta: nil, isProcessing: true, destinationPath: nil)
        }

        var destination: String?
        if let destMatch = destRegex.firstMatch(in: line, range: full), destMatch.numberOfRanges > 1 {
            destination = ns.substring(with: destMatch.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let percentMatch = percentRegex.firstMatch(in: line, range: full), percentMatch.numberOfRanges > 1 else {
            if let destination {
                return DownloadProgress(
                    fraction: 0,
                    speed: nil,
                    eta: nil,
                    isProcessing: false,
                    destinationPath: destination
                )
            }
            // Tamanho total desconhecido (CDN sem Content-Length): yt-dlp só informa
            // bytes e velocidade, sem %. Sem isso a barra fica presa em 0% até concluir.
            if ns.range(of: "[download]", options: .caseInsensitive).location != NSNotFound,
               let speed = firstCapture(speedRegex, in: ns) {
                return DownloadProgress(
                    fraction: nil,
                    speed: speed,
                    eta: firstCapture(etaRegex, in: ns),
                    isProcessing: false,
                    destinationPath: nil
                )
            }
            return nil
        }

        let percentString = ns.substring(with: percentMatch.range(at: 1))
        let fraction = (Double(percentString) ?? 0) / 100.0
        let speed = firstCapture(speedRegex, in: ns)
        let eta = firstCapture(etaRegex, in: ns)
        return DownloadProgress(
            fraction: min(max(fraction, 0), 1),
            speed: speed,
            eta: eta,
            isProcessing: false,
            destinationPath: destination
        )
    }

    private static func firstCapture(_ regex: NSRegularExpression, in ns: NSString) -> String? {
        let full = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: ns as String, range: full), match.numberOfRanges > 1 else {
            return nil
        }
        return ns.substring(with: match.range(at: 1))
    }
}
