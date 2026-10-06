#!/bin/sh
# Empacota yt-dlp, ffmpeg, ffprobe e deno em Vendor/Helpers (arm64, sem Homebrew no Mac de destino).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPERS="$ROOT/Vendor/Helpers"
mkdir -p "$HELPERS/lib"

if [ -x "$HELPERS/ffmpeg" ] && [ -x "$HELPERS/ffprobe" ] && [ -x "$HELPERS/yt-dlp" ] && [ -x "$HELPERS/deno" ]; then
  echo "Helpers já existem em $HELPERS ($(du -sh "$HELPERS" | awk '{print $1}'))"
  exit 0
fi

if [ ! -x /opt/homebrew/opt/ffmpeg/bin/ffmpeg ]; then
  echo "ffmpeg do Homebrew não encontrado. Rode: brew install ffmpeg" >&2
  exit 1
fi
if [ ! -x /opt/homebrew/opt/deno/bin/deno ]; then
  echo "deno do Homebrew não encontrado. Rode: brew install deno" >&2
  exit 1
fi
if ! command -v dylibbundler >/dev/null 2>&1; then
  echo "Instale dylibbundler: brew install dylibbundler" >&2
  exit 1
fi

cp /opt/homebrew/opt/ffmpeg/bin/ffmpeg /opt/homebrew/opt/ffmpeg/bin/ffprobe "$HELPERS/"
chmod u+w "$HELPERS/ffmpeg" "$HELPERS/ffprobe"
dylibbundler -od -b -x "$HELPERS/ffmpeg" -d "$HELPERS/lib" -p @executable_path/lib/ >/dev/null
dylibbundler -od -b -x "$HELPERS/ffprobe" -d "$HELPERS/lib" -p @executable_path/lib/ >/dev/null

cp /opt/homebrew/opt/deno/bin/deno "$HELPERS/deno.tmp"
mv -f "$HELPERS/deno.tmp" "$HELPERS/deno"

TMP_YT="/tmp/yt-dlp_macos"
if [ ! -f "$TMP_YT" ]; then
  curl -fsSL -o "$TMP_YT" "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
fi
cp "$TMP_YT" "$HELPERS/yt-dlp"
chmod +x "$HELPERS/yt-dlp" "$HELPERS/deno" "$HELPERS/ffmpeg" "$HELPERS/ffprobe"

echo "Helpers prontos em $HELPERS ($(du -sh "$HELPERS" | awk '{print $1}'))"
