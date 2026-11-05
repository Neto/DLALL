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
if [ -n "$HELPERS_SRC" ] && [ -x "$HELPERS_SRC/yt-dlp" ]; then
  /bin/mkdir -p "$APP/Contents/Helpers"
  /usr/bin/rsync -a --delete "$HELPERS_SRC/" "$APP/Contents/Helpers/"
  if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ] && [ "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]; then
    HELPERS_ENT=""
    if [ -n "${SRCROOT:-}" ] && [ -f "${SRCROOT}/scripts/helpers.entitlements" ]; then
      HELPERS_ENT="${SRCROOT}/scripts/helpers.entitlements"
    elif [ -f "$(dirname "$0")/helpers.entitlements" ]; then
      HELPERS_ENT="$(dirname "$0")/helpers.entitlements"
    fi
    # Assina as .dylib do ffmpeg/ffprobe primeiro, com o mesmo Team ID — sem isso, hardened
    # runtime recusa carregá-las (Team ID diferente do binário que as carrega).
    if [ -d "$APP/Contents/Helpers/lib" ]; then
      find "$APP/Contents/Helpers/lib" -name '*.dylib' -print0 \
        | xargs -0 -I{} /usr/bin/codesign --force --options runtime --sign "${EXPANDED_CODE_SIGN_IDENTITY}" {} >/dev/null 2>&1 || true
    fi
    # yt-dlp (PyInstaller) e deno (V8/JIT) travam sob hardened runtime sem permissão de JIT —
    # assina os dois com entitlements próprios, nunca com --deep a partir do app (que aplicaria
    # os entitlements do app, sem allow-jit, e quebraria o solver de desafio JS do YouTube).
    for b in yt-dlp deno; do
      if [ -x "$APP/Contents/Helpers/$b" ] && [ -n "$HELPERS_ENT" ]; then
        /usr/bin/codesign --force --options runtime --entitlements "$HELPERS_ENT" --sign "${EXPANDED_CODE_SIGN_IDENTITY}" "$APP/Contents/Helpers/$b" >/dev/null 2>&1 || true
      fi
    done
    for b in ffmpeg ffprobe; do
      if [ -x "$APP/Contents/Helpers/$b" ]; then
        /usr/bin/codesign --force --options runtime --sign "${EXPANDED_CODE_SIGN_IDENTITY}" "$APP/Contents/Helpers/$b" >/dev/null 2>&1 || true
      fi
    done
  fi
fi

echo "Helpers embutidos em: $APP/Contents/Helpers"
