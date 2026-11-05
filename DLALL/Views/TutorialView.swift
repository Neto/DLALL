import SwiftUI

// MARK: - Frame tracking

/// Collects the frames of the mock controls so the animated cursor can move to the real positions.
private struct TutorialFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension View {
    func tutorialAnchor(_ id: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TutorialFrames.self,
                    value: [id: proxy.frame(in: .named("mock"))]
                )
            }
        )
    }
}

// MARK: - Tutorial

/// Animated first-run tutorial. A mock window shows a cursor that clicks the real controls
/// and shows an example for each step.
struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var frames: [String: CGRect] = [:]

    @State private var cursor = CGPoint(x: 340, y: 300)
    @State private var cursorVisible = false
    @State private var pressing = false
    @State private var target = ""

    @State private var url = ""
    @State private var quality = "Best quality"
    @State private var menuOpen = false
    @State private var progress: Double?
    @State private var phase = "Download"
    @State private var finished = false
    @State private var historyTab = false
    @State private var settingsOpen = false

    private let exampleURL = "https://www.youtube.com/watch?v=example"

    private let steps: [(title: String, text: String)] = [
        ("Paste a link",
         "Click Paste, or type a link in the field. DLALL works with YouTube, Instagram, TikTok, and Vimeo."),
        ("Choose the quality",
         "Pick a resolution. Choose Audio only to save an MP3. The options depend on the video."),
        ("Click Download",
         "DLALL downloads the video and converts it for QuickTime. The progress shows in the list."),
        ("Find it again in History",
         "DLALL saves each finished download in History. Click Download Again to repeat it."),
        ("Set your preferences",
         "Open Preferences to choose the destination folder and a browser for sign in. Some videos and Stories need browser cookies."),
        ("You are ready",
         "Paste a link and click Download. To see this tutorial again, choose Help > Show Tutorial."),
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Welcome to DLALL")
                    .font(.title2.bold())
                Spacer()
                Button("Skip") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityHint("Closes the tutorial")
            }

            VStack(spacing: 6) {
                Text("Step \(step + 1) of \(steps.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(steps[step].title)
                    .font(.title3.weight(.semibold))
                Text(steps[step].text)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560, minHeight: 44, alignment: .top)
            }

            mock

            HStack {
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { index in
                        Circle()
                            .fill(index == step ? Color.white : Color.white.opacity(0.25))
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                if step == steps.count - 1 {
                    Button("Start Using DLALL") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Next") { step += 1 }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 740)
        .background(DLALLTheme.base)
        .preferredColorScheme(.dark)
        .task(id: step) {
            try? await run(step)
        }
    }

    // MARK: Mock window

    private var mock: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                mockHeader
                mockTabs
                mockContent
                Spacer(minLength: 0)
            }
            if menuOpen { qualityMenu }
            if settingsOpen { settingsCard }
            if cursorVisible { cursorView }
        }
        .frame(width: 680, height: 330)
        .coordinateSpace(name: "mock")
        .background(DLALLTheme.base)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .onPreferenceChange(TutorialFrames.self) { frames = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Animated example of the DLALL window")
    }

    private func scale(_ id: String) -> CGFloat {
        pressing && target == id ? 0.92 : 1
    }

    private var mockHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("DLALL")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: "gearshape")
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0.14)))
                    .scaleEffect(scale("gear"))
                    .tutorialAnchor("gear")
            }

            HStack(spacing: 8) {
                HStack {
                    Text(url.isEmpty ? "Paste a video URL" : url)
                        .lineLimit(1)
                        .foregroundStyle(url.isEmpty ? Color.white.opacity(0.45) : Color.white)
                    Spacer(minLength: 0)
                }
                .font(.callout)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Capsule().fill(.white.opacity(0.12)))
                .tutorialAnchor("field")

                HStack(spacing: 5) {
                    Text(url.isEmpty ? "Quality" : quality)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .font(.callout)
                .foregroundStyle(url.isEmpty ? Color.white.opacity(0.4) : Color.white)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(.white.opacity(0.12)))
                .scaleEffect(scale("quality"))
                .tutorialAnchor("quality")

                Label("Download", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(url.isEmpty ? Color.white.opacity(0.4) : Color.white)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(Capsule().fill(url.isEmpty ? DLALLTheme.pill : DLALLTheme.indigo))
                    .scaleEffect(scale("download"))
                    .tutorialAnchor("download")
            }

            HStack {
                if url.isEmpty {
                    Text("YouTube, Instagram, TikTok, or Vimeo")
                } else {
                    Label("YouTube", systemImage: "play.rectangle.fill")
                }
                Spacer()
                Label("Paste", systemImage: "doc.on.clipboard")
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Capsule().fill(.white.opacity(0.12)))
                    .scaleEffect(scale("paste"))
                    .tutorialAnchor("paste")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [DLALLTheme.indigo, DLALLTheme.indigoDeep, .black],
                    startPoint: .top,
                    endPoint: .bottom
                ))
        )
    }

    private var mockTabs: some View {
        HStack(spacing: 0) {
            Text("Downloads")
                .frame(width: 120, height: 24)
                .background(Capsule().fill(historyTab ? Color.clear : Color.white.opacity(0.2)))
            Text("History")
                .frame(width: 120, height: 24)
                .background(Capsule().fill(historyTab ? Color.white.opacity(0.2) : Color.clear))
                .scaleEffect(scale("tabHistory"))
                .tutorialAnchor("tabHistory")
        }
        .font(.caption)
        .padding(2)
        .background(Capsule().fill(.white.opacity(0.08)))
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var mockContent: some View {
        if historyTab {
            mockRow(
                subtitle: "YouTube · 1080p · 1 download",
                trailing: AnyView(
                    Text("Download Again")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Capsule().fill(DLALLTheme.indigo))
                        .scaleEffect(scale("redownload"))
                        .tutorialAnchor("redownload")
                )
            )
        } else if let progress {
            mockRow(
                subtitle: finished ? "Finished" : "\(phase): \(Int(progress * 100))%",
                trailing: AnyView(
                    Group {
                        if finished {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            ProgressView(value: progress).frame(width: 140)
                        }
                    }
                )
            )
        } else {
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 30))
                Text("No downloads yet")
                    .font(.callout.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        }
    }

    private func mockRow(subtitle: String, trailing: AnyView) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "play.rectangle.fill")
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.1)))
            VStack(alignment: .leading, spacing: 3) {
                Text("Example video").font(.callout.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            trailing
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
        .padding(.horizontal, 16)
    }

    private var qualityMenu: some View {
        let options = ["Best quality", "2160p (4K)", "1080p", "720p", "Audio only (MP3)"]
        let origin = frames["quality"].map { CGPoint(x: $0.minX, y: $0.maxY + 4) } ?? CGPoint(x: 430, y: 90)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(options, id: \.self) { option in
                HStack {
                    Text(option)
                    Spacer(minLength: 10)
                    if option == quality { Image(systemName: "checkmark") }
                }
                .font(.callout)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(option == "1080p" && target == "opt1080" ? Color.accentColor.opacity(0.5) : .clear)
                .modifier(OptionAnchor(isTarget: option == "1080p"))
            }
        }
        .frame(width: 170)
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.16)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.15)))
        .shadow(radius: 8)
        .offset(x: origin.x, y: origin.y)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preferences").font(.callout.weight(.semibold))
            settingsLine("Destination folder", "Downloads")
            settingsLine("Cookies for videos", "Automatic")
            settingsLine("Cookies for Instagram Stories", "Brave")
            settingsLine("When finished", "Show in Finder")
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.16)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.15)))
        .shadow(radius: 8)
        .offset(x: 340, y: 46)
    }

    private func settingsLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.white.opacity(0.65))
        }
        .font(.caption)
    }

    private var cursorView: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.7), lineWidth: 2)
                .frame(width: 30, height: 30)
                .scaleEffect(pressing ? 1 : 0.3)
                .opacity(pressing ? 1 : 0)
            Image(systemName: "cursorarrow")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 2)
                .offset(x: 8, y: 10)
        }
        .position(cursor)
        .allowsHitTesting(false)
    }

    // MARK: Script

    private func pause(_ milliseconds: Int) async throws {
        try await Task.sleep(for: .milliseconds(milliseconds))
    }

    private func move(to id: String, dx: CGFloat = 0, dy: CGFloat = 0) async throws {
        target = id
        if let frame = frames[id] {
            withAnimation(.easeInOut(duration: 0.8)) {
                cursor = CGPoint(x: frame.midX + dx, y: frame.midY + dy)
            }
        }
        try await pause(900)
    }

    private func click() async throws {
        withAnimation(.easeIn(duration: 0.1)) { pressing = true }
        try await pause(160)
        withAnimation(.easeOut(duration: 0.25)) { pressing = false }
        try await pause(300)
    }

    private func typeURL() async throws {
        url = ""
        for character in exampleURL {
            url.append(character)
            try await pause(28)
        }
    }

    private func setBaseline(
        url: String = "",
        quality: String = "Best quality",
        job: Bool = false,
        history: Bool = false,
        settings: Bool = false,
        menu: Bool = false
    ) {
        self.url = url
        self.quality = quality
        progress = job ? 1 : nil
        finished = job
        phase = "Download"
        historyTab = history
        settingsOpen = settings
        menuOpen = menu
        pressing = false
        target = ""
    }

    private func advance() {
        if step < steps.count - 1 { step += 1 }
    }

    private func run(_ current: Int) async throws {
        try await pause(250)
        switch current {
        case 0:
            setBaseline()
            cursor = CGPoint(x: 340, y: 300)
            withAnimation { cursorVisible = true }
            try await pause(500)
            try await move(to: "paste")
            try await click()
            try await typeURL()
            try await pause(1400)
            advance()

        case 1:
            setBaseline(url: exampleURL)
            cursorVisible = true
            try await move(to: "quality")
            try await click()
            withAnimation(.easeOut(duration: 0.15)) { menuOpen = true }
            try await pause(500)
            try await move(to: "opt1080")
            try await click()
            quality = "1080p"
            withAnimation { menuOpen = false }
            try await pause(1300)
            advance()

        case 2:
            setBaseline(url: exampleURL, quality: "1080p")
            cursorVisible = true
            try await move(to: "download")
            try await click()
            url = ""
            progress = 0
            phase = "Download"
            for index in 1...40 {
                withAnimation(.linear(duration: 0.06)) { progress = Double(index) / 40 }
                try await pause(55)
            }
            phase = "Converting"
            progress = 0
            for index in 1...15 {
                withAnimation(.linear(duration: 0.06)) { progress = Double(index) / 15 }
                try await pause(50)
            }
            finished = true
            try await pause(1500)
            advance()

        case 3:
            setBaseline(job: true)
            cursorVisible = true
            try await move(to: "tabHistory")
            try await click()
            withAnimation { historyTab = true }
            try await pause(600)
            try await move(to: "redownload")
            try await click()
            try await pause(1200)
            advance()

        case 4:
            setBaseline()
            cursorVisible = true
            try await move(to: "gear")
            try await click()
            withAnimation(.easeOut(duration: 0.2)) { settingsOpen = true }
            try await pause(3200)
            advance()

        default:
            setBaseline()
            withAnimation { cursorVisible = false }
        }
    }
}

/// Anchors the 1080p row of the mock quality menu so the cursor can move to it.
private struct OptionAnchor: ViewModifier {
    let isTarget: Bool

    func body(content: Content) -> some View {
        if isTarget {
            content.tutorialAnchor("opt1080")
        } else {
            content
        }
    }
}

#Preview {
    TutorialView()
}
