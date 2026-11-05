import SwiftUI

struct ComposerView: View {
    @Environment(LibraryModel.self) private var model
    @FocusState private var urlFocused: Bool

    private let pillHeight: CGFloat = 36

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                TextField(
                    "",
                    text: $model.draftURL,
                    prompt: Text("Paste a video URL").foregroundStyle(.white.opacity(0.45))
                )
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: pillHeight)
                .glassPill(Capsule(), interactive: false)
                .focused($urlFocused)
                .accessibilityLabel("Video URL")

                Menu {
                    Picker("Quality", selection: $model.quality) {
                        ForEach(model.availableQualities) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack(spacing: 6) {
                        Text(qualityLabel)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(qualityMenuDisabled ? Color.white.opacity(0.4) : Color.white)
                    .padding(.horizontal, 14)
                    .frame(height: pillHeight)
                    .glassPill(Capsule(), interactive: !qualityMenuDisabled)
                    .contentShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .disabled(qualityMenuDisabled)
                .fixedSize()
                .accessibilityLabel("Quality")
                .help("Quality of the downloaded file.")

                Button(action: submit) {
                    Label("Download", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: pillHeight)
                        .foregroundStyle(model.canSubmit ? Color.white : Color.white.opacity(0.4))
                        .glassPill(Capsule(), tint: model.canSubmit ? DLALLTheme.indigo : nil, interactive: model.canSubmit)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!model.canSubmit)
                .keyboardShortcut(.defaultAction)
                .help("Fetch the video and start the download.")
            }

            HStack(spacing: 12) {
                platformHint
                Spacer()
                Button {
                    model.pasteFromClipboard()
                    urlFocused = true
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .glassPill(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Paste a URL from the clipboard.")
            }
            .font(.callout)
            .foregroundStyle(.white.opacity(0.7))
        }
        .onAppear {
            urlFocused = true
        }
    }

    private var qualityMenuDisabled: Bool {
        model.availableQualities.isEmpty || model.isImageOnly
    }

    private var qualityLabel: String {
        if model.isProbingQuality { return "Fetching…" }
        if model.isImageOnly { return model.imageCount > 1 ? "\(model.imageCount) images" : "Image" }
        if model.availableQualities.isEmpty { return "Quality" }
        return model.quality.title
    }

    @ViewBuilder
    private var platformHint: some View {
        if let url = URLExtractor.firstHTTPURL(in: model.draftURL) {
            let platform = MediaPlatform.detect(from: url)
            Label(platform.title, systemImage: platform.systemImage)
                .foregroundStyle(platform == .other ? Color.white.opacity(0.7) : Color.white)
        } else {
            Text("YouTube, Instagram, TikTok, or Vimeo")
        }
    }

    private func submit() {
        model.enqueueDraft()
    }
}
