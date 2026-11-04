#!/bin/sh
# Copia yt-dlp, ffmpeg, ffprobe e deno (Vendor/Helpers) para dentro do app recém-buildado.
# Não toca em /Applications.
set -e

if [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${FULL_PRODUCT_NAME:-}" ]; then
  APP="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
  case "${TARGET_BUILD_DIR}" in
    *Index.noindex*|*Preview*|*Previews*)
      exit 0
      ;;
  esac
else
  APP="${1:-}"
fi

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "BaixaTudo.app não encontrado para empacotar helpers." >&2
  exit 1
fi

if [ ! -f "$APP/Contents/Info.plist" ]; then
  echo "Pacote inválido: $APP" >&2
  exit 1
fi

HELPERS_SRC=""
if [ -n "${SRCROOT:-}" ] && [ -d "${SRCROOT}/Vendor/Helpers" ]; then
  HELPERS_SRC="${SRCROOT}/Vendor/Helpers"
elif [ -d "$(dirname "$0")/../Vendor/Helpers" ]; then
  HELPERS_SRC="$(cd "$(dirname "$0")/../Vendor/Helpers" && pwd)"
fi
if [ -n "$HELPERS_SRC" ] && [ -x "$HELPERS_SRC/yt-dlp" ] && [ ! -x "$APP/Contents/Helpers/yt-dlp" ]; then
  /bin/mkdir -p "$APP/Contents/Helpers"
  /usr/bin/rsync -a "$HELPERS_SRC/" "$APP/Contents/Helpers/"
  if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ] && [ "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]; then
    ENT="${CODE_SIGN_ENTITLEMENTS:-}"
    if [ -n "${SRCROOT:-}" ] && [ -f "${SRCROOT}/BaixaTudo/BaixaTudo.entitlements" ]; then
      ENT="${SRCROOT}/BaixaTudo/BaixaTudo.entitlements"
    fi
    if [ -n "$ENT" ] && [ -f "$ENT" ]; then
      /usr/bin/codesign --force --deep --options runtime --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --entitlements "$ENT" "$APP" >/dev/null 2>&1 || true
    else
      /usr/bin/codesign --force --deep --options runtime --sign "${EXPANDED_CODE_SIGN_IDENTITY}" "$APP" >/dev/null 2>&1 || true
    fi
  fi
fi

echo "Helpers embutidos em: $APP/Contents/Helpers"
