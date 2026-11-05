# BaixaTudo

**English** | [Português (Brasil)](README.pt-BR.md)

A macOS app for downloading videos, audio, and Instagram content from links, with a native SwiftUI interface.

BaixaTudo builds on [DLYT, originally created by Mentor Neto](https://github.com/Neto/DLYT). This version adds improved quality selection, Instagram photo and carousel downloads, experimental Stories support, and separate cookie settings for videos and Stories. The original project's credits and authorship history have been preserved.

Only download content you have permission to download.

## Features

- Downloads from YouTube, Instagram, TikTok, Vimeo, and other yt-dlp-compatible sites. Availability varies by site and content.
- Per-video quality selection, including up to 4K when available, and MP3 audio extraction.
- H.264 + AAC video output for QuickTime playback, with conversion when needed.
- Instagram photos and carousels, plus experimental support for Stories and highlights.
- Download queue, configurable destination folder, and options to reveal or open completed files.
- yt-dlp, ffmpeg, ffprobe, and deno bundled with the compiled app.

## Requirements and installation

- Mac with Apple Silicon (arm64).
- macOS 15 or later.

Source code is available in this repository. Installer packages, when published, are available under [Releases](https://github.com/rcava/BaixaTudo/releases). To build your own copy, see below.

## Usage

Paste a link, select an available quality, and start the download. Files are saved to Downloads by default; you can change the destination in preferences.

If the content requires login, configure browser cookies as described below.

## Preferences and browser cookies

Cookies may contain session information. BaixaTudo uses yt-dlp to read cookies from the selected browser and include them in requests to the source website. You do not need to enter your password in the app.

The app currently uses Portuguese labels for most preferences. The original labels are included below to help you find them.

### Cookies for videos

**Cookies para vídeos** applies to YouTube, Reels, Instagram posts, and other links.

| Option | Behavior |
| --- | --- |
| None (Nenhum) | Does not read browser cookies. This is the default for videos and the starting point for public content. |
| Automatic (Automático) | Tries without login first and may fall back to browsers if needed. |
| A specific browser | Uses cookies from that browser. |

Available browsers are Safari, Brave, Chrome, Firefox, and Edge. Sign in through the browser before attempting to download content that requires login.

### Cookies for Instagram Stories

Image and video Stories, including highlights, use a separate setting: **Cookies para Instagram Stories**. Select a browser where you are signed in to Instagram and have access to the content. This setting uses only the selected browser.

The default on a fresh installation is Brave; change it if you use another browser. Selecting a browser does not guarantee that Instagram will accept its session.

Reading Safari cookies requires **Full Disk Access**, under System Settings → Privacy & Security. This permission provides broad access to protected files; grant it only if you want to use this feature and trust your copy of the app.

### Other preferences

Under **Geral** (General), you can choose the destination folder, default quality, and whether to reveal or open completed files. Under **Motor** (Engine), you can check the detected tools and optionally specify another yt-dlp executable. Leave that path empty to use the bundled copy.

## Limitations and troubleshooting

Websites may change their rules and interfaces, causing previously working links to fail. Available quality depends on the source content. Video conversion can take time.

Stories support is experimental and uses a customized yt-dlp extractor. Locally available cookies do not guarantee access to content. The app does not grant access to content your account cannot view.

If a download requires login, check the selected browser and make sure you are signed in there. If Safari cookie extraction fails, check Full Disk Access permissions.

### Diagnostics

Under Preferences → **Motor**, **Registrar diagnóstico detalhado** (Enable detailed diagnostics) records tool information and errors. It starts disabled in Release builds and enabled by default in Debug builds, subject to saved preferences. **Mostrar logs no Finder** (Show logs in Finder) opens `~/Library/Logs/BaixaTudo/`. A short error summary is stored at `~/Library/Logs/BaixaTudo.log`.

Diagnostics filter known cookie, token, and credential values, as well as URL query strings and fragments. Review logs before sharing: they may still contain local paths and content information. Detailed mode uses zero internal retries in yt-dlp; browser fallback may still occur in Automatic mode.

**Check Instagram session (offline)** looks for the session cookie in the browser selected for Stories. It does not contact Instagram, display the cookie value, or confirm server acceptance. It creates a log even when detailed diagnostics are disabled.

Never publish cookies, passwords, or tokens in bug reports.

## Build from source

You need Xcode with its command-line tools and Homebrew. Install the dependencies:

```zsh
brew install xcodegen ffmpeg deno dylibbundler python@3.11
```

Clone and build:

```zsh
git clone https://github.com/rcava/BaixaTudo.git
cd BaixaTudo
./scripts/bundle-helpers.sh
xcodegen generate
xcodebuild -project BaixaTudo.xcodeproj -scheme BaixaTudo -configuration Debug \
  -destination 'platform=macOS,arch=arm64' build
```

The bundling script downloads dependencies and copies the tools into `Vendor/Helpers`, which is excluded from the repository. Run it before your first build. It assumes Homebrew is installed at `/opt/homebrew`.

`build-and-install.zsh` builds the app and reveals it in Finder. Drag the `.app` to Applications to install it.

### Signed installer

`scripts/make-installer.sh` creates a signed and notarized package. It requires Developer ID Application and Developer ID Installer certificates, plus a notarytool profile named `BaixaTudo`. The team identifiers and certificate names inherited from the original author must be adapted to your account. Certificates and private keys are not provided in this repository.

### Local checks

The following tests check diagnostics and local fixtures; they do not verify live Instagram downloads:

```sh
xcrun swiftc -swift-version 6 -D DEBUG BaixaTudo/Services/DiagnosticLog.swift tests/DiagnosticLogTests.swift -o /tmp/baixatudo-diagnostic-tests
/tmp/baixatudo-diagnostic-tests
python3 tests/test_session_diagnostic.py
python3 tests/test_instagram_stories.py
```

## Project layout

| Folder or file | Contents |
| --- | --- |
| `BaixaTudo/Models` | Platforms, quality options, and download jobs |
| `BaixaTudo/Services` | yt-dlp integration, tools, and diagnostics |
| `BaixaTudo/ViewModels` | State and queue management |
| `BaixaTudo/Views` | SwiftUI interface |
| `scripts` | Bundling, builds, and installer |
| `tests` | Local checks and fixtures |
| `project.yml` | XcodeGen project definition |

Technologies: Swift 6, SwiftUI, and XcodeGen. See also the [technical changelog](CHANGELOG.md).

## Reporting issues and contributing

Open an [issue](https://github.com/rcava/BaixaTudo/issues) with your app and macOS versions, the affected website, reproduction steps, and the error message. Use public links where possible and remove personal information from screenshots and logs.

Improvements can be discussed in issues and pull requests. Code reuse terms depend on a license being defined, as explained below.

## Credits and license

- Original project: [DLYT, by Mentor Neto / Spinoff](https://github.com/Neto/DLYT).
- Further development of BaixaTudo: Ricardo Cavallini, with authorship preserved in Git history.
- Tools: [yt-dlp](https://github.com/yt-dlp/yt-dlp), [FFmpeg](https://ffmpeg.org/), and [Deno](https://deno.com/), subject to their respective licenses.
- Experimental Stories fix adapted from [yt-dlp PR #17885](https://github.com/yt-dlp/yt-dlp/pull/17885), with details in [STORIES-FIX.md](BaixaTudo/Resources/Diagnostics/STORIES-FIX.md).

Neither this repository nor the original project, as reviewed, includes a license file. Publishing the source code does not by itself grant a license to reuse, modify, or redistribute it. No new license has been assigned to the inherited code.

© 2026 Spinoff and the respective authors.
