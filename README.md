# BaixaTudo

BaixaTudo is a macOS app that downloads a video from a URL. It uses `yt-dlp` and `ffmpeg` inside the app bundle. The user does not install anything else.

Use BaixaTudo only with content that you have the right to download.

## Features

* Paste a URL. BaixaTudo finds the platform: YouTube, Instagram, TikTok, Vimeo, or other.
* Select the quality: best, 1080p, 720p, 480p, or audio only (MP3).
* Video output uses H.264 and AAC, so QuickTime can open the file. If the site has no H.264 stream, BaixaTudo converts the file.
* Optional browser cookies (Safari) for videos that need a signed in account. This also helps with the YouTube bot check.
* Download queue with a row for each job.

## Requirements

* Mac with Apple Silicon (arm64)
* macOS 15 or later

## Build from source

You need Xcode, XcodeGen, Homebrew, and these Homebrew packages: `ffmpeg`, `deno`, `dylibbundler`.

```zsh
brew install xcodegen ffmpeg deno dylibbundler
git clone https://github.com/Neto/BaixaTudo.git
cd BaixaTudo
./scripts/bundle-helpers.sh
xcodegen generate
xcodebuild -project BaixaTudo.xcodeproj -scheme BaixaTudo -configuration Debug \
  -destination 'platform=macOS,arch=arm64' build
```

`scripts/bundle-helpers.sh` copies `yt-dlp`, `ffmpeg`, `ffprobe`, and `deno` into `Vendor/Helpers`. This folder is not in the repository. Run the script one time before the first build.

`build-and-install.zsh` builds the app and reveals it in Finder. It does not touch `/Applications`; drag the `.app` there yourself.

## Installer

`scripts/make-installer.sh` makes a signed and notarized `BaixaTudo.pkg`. It needs the Developer ID Application and Developer ID Installer certificates of the Apple developer team, and a `notarytool` profile named `BaixaTudo`. The team ID and certificate names in the script are those of the author. Change them to build with your own account.

## Diagnostic logging

In Preferences → Motor, enable “Registrar diagnóstico detalhado”. Debug builds enable it by default unless the preference was explicitly saved. “Mostrar logs no Finder” opens `~/Library/Logs/BaixaTudo/`.

Each subprocess gets its own timestamped file with an ID, app/build version, executable, arguments, complete verbose diagnostics, exit status and elapsed time. Metadata JSON is omitted; cookie/authentication headers, known credential assignments, URL credentials, query strings and fragments are filtered. The existing `~/Library/Logs/BaixaTudo.log` remains a short error summary.

Diagnostic mode adds `--verbose --retries 0 --extractor-retries 0` to existing yt-dlp operations. It does not start extra operations, but automatic browser fallback and the app's existing quality probe still apply. Select a specific browser to avoid trying multiple browsers. These logs do not establish that an extracted session is accepted by Instagram.

“Check Instagram session (offline)” reads cookies from the selected browser using the bundled yt-dlp and a bundled local extractor. It reports only whether Instagram's `sessionid` is present, its domain/path, expiration in UTC, whether it is expired and whether it has a value. The value is never printed or exported. This action writes a new diagnostic log even when detailed logging is off, makes no network requests and does not test server acceptance. Select a specific browser in Geral first; it does not try other browsers automatically.

Run the local logging checks without accessing any website:

```sh
xcrun swiftc -swift-version 6 -D DEBUG BaixaTudo/Services/DiagnosticLog.swift tests/DiagnosticLogTests.swift -o /tmp/baixatudo-diagnostic-tests
/tmp/baixatudo-diagnostic-tests
python3 tests/test_session_diagnostic.py
python3 tests/test_instagram_stories.py
```

Build 12 includes a Stories-only plugin adapted from [yt-dlp PR #17885](https://github.com/yt-dlp/yt-dlp/pull/17885), pinned to `3e089b44ea159f6057d8792ae0abc0e9e33127b9`. This experimental patch prefers embedded page data, then the reels API and a GraphQL fallback. Local adaptations bound profile lookup, preserve the existing API shape and retain photo Stories. It requires a specific browser, disables internal retries for Stories and skips the automatic quality probe when pasting a Story URL. Clicking download starts metadata extraction; successful downloads can still perform a second extraction in the existing download phase. Other websites retain their existing extractor. No live Instagram test is run during builds or fixture tests.

Build 13 separates “Cookies para vídeos” (YouTube, Reels, Instagram posts and other links) from “Cookies para Instagram Stories” (both images and videos, including highlights). On migration, the old specific browser choice is retained for Stories and videos default to “Nenhum”. The last successful Stories browser never becomes a preferred browser for video probes. The offline session check uses the Stories preference.

Release 1.5.3 (build 14) disables detailed diagnostics on its first launch, including the preference inherited from the debug builds. Afterwards it respects deliberate changes to the toggle. The offline cookie check and short error log remain available. Stories retain their extractor fix, disabled automatic quality probe and zero internal retries.

## Project layout

* `BaixaTudo/Models`: platform detection, quality options, download jobs
* `BaixaTudo/Services`: `yt-dlp` client and helper binary locator
* `BaixaTudo/ViewModels`: library of jobs
* `BaixaTudo/Views`: SwiftUI views
* `scripts`: helper bundling, install, and installer scripts
* `project.yml`: XcodeGen project definition

## Technology

Swift 6, SwiftUI, XcodeGen. Bundle identifier: `com.baixatudo.BaixaTudo`.

## License

No license file exists yet. Without a license, all rights stay with the author.

© 2026 Spinoff
