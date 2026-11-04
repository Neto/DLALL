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
