#!/bin/zsh
# Gera DLYT.pkg assinado e notarizado (abre com duplo clique em qualquer Mac Apple Silicon).
# Pré-requisitos (uma vez):
#   1) Certificado "Developer ID Installer: Mentor Neto (FDWHNL3X82)" no Keychain
#   2) xcrun notarytool store-credentials "DLYT" --apple-id <email> --team-id FDWHNL3X82 --password <senha de app>
set -euo pipefail

TEAM="FDWHNL3X82"
APP_ID="Developer ID Application: Mentor Neto (${TEAM})"
PKG_ID="Developer ID Installer: Mentor Neto (${TEAM})"
NOTARY_PROFILE="DLYT"

if [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
elif [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

PROJ="${HOME}/ARDUINO/XCODE/DLYT"
cd "$PROJ"

# --- Pré-checagens (falha cedo, antes de compilar) ---
if ! security find-identity -v | grep -q "$PKG_ID"; then
  print -u2 "Falta o certificado: $PKG_ID"
  print -u2 "Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Installer"
  exit 1
fi
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  print -u2 "Falta o perfil de notarização '$NOTARY_PROFILE'."
  print -u2 "Rode: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <email> --team-id $TEAM --password <senha de app>"
  exit 1
fi

"$PROJ/scripts/bundle-helpers.sh"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi

xcodebuild -project DLYT.xcodeproj -scheme DLYT -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY="$APP_ID" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM" \
  build

APP="$(/usr/bin/find "${HOME}/Library/Developer/Xcode/DerivedData" \
  -path '*/Build/Products/Release/DLYT.app' -type d -print0 2>/dev/null \
  | xargs -0 ls -dt 2>/dev/null | /usr/bin/head -1)"

if [[ ! -d "$APP" ]]; then
  print -u2 "Release DLYT.app não encontrado."
  exit 1
fi

rm -rf "$APP/Contents/Helpers"
mkdir -p "$APP/Contents/Helpers"
/usr/bin/rsync -a "$PROJ/Vendor/Helpers/" "$APP/Contents/Helpers/"

if [[ ! -x "$APP/Contents/Helpers/yt-dlp" ]]; then
  print -u2 "Helpers não foram copiados para o app."
  exit 1
fi

# --- Assinatura: de dentro para fora ---
# dylibs e ffmpeg/ffprobe: sem entitlements
find "$APP/Contents/Helpers" -name '*.dylib' -print0 \
  | xargs -0 -n1 codesign --force --options runtime --timestamp --sign "$APP_ID"
for b in ffmpeg ffprobe; do
  codesign --force --options runtime --timestamp --sign "$APP_ID" "$APP/Contents/Helpers/$b"
done
# yt-dlp (PyInstaller) e deno (V8/JIT) precisam de entitlements próprios sob hardened runtime
for b in yt-dlp deno; do
  codesign --force --options runtime --timestamp \
    --entitlements "$PROJ/scripts/helpers.entitlements" \
    --sign "$APP_ID" "$APP/Contents/Helpers/$b"
done
# app por último
codesign --force --options runtime --timestamp \
  --entitlements "$PROJ/DLYT/DLYT.entitlements" \
  --sign "$APP_ID" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

# --- Teste de fumaça: os helpers assinados precisam executar ---
"$APP/Contents/Helpers/yt-dlp" --version
"$APP/Contents/Helpers/ffmpeg" -version | head -1
"$APP/Contents/Helpers/ffprobe" -version | head -1
"$APP/Contents/Helpers/deno" --version | head -1

"$PROJ/scripts/install-to-applications.sh" "$APP"

STAGE="/tmp/dlyt-pkgroot"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/DLYT.app"

PKG_DIR="/tmp/dlyt-pkg"
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"

MARKETING="$(defaults read "$APP/Contents/Info" CFBundleShortVersionString)"
BUILD="$(defaults read "$APP/Contents/Info" CFBundleVersion)"

pkgbuild --identifier com.spinoff.DLYT \
  --version "$MARKETING" \
  --install-location /Applications \
  --component "$STAGE/DLYT.app" \
  "$PKG_DIR/DLYT-component.pkg"

cat > "$PKG_DIR/distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>DLYT</title>
    <organization>com.spinoff</organization>
    <options customize="never" require-scripts="false" hostArchitectures="arm64"/>
    <welcome file="welcome.html" mime-type="text/html"/>
    <pkg-ref id="com.spinoff.DLYT"/>
    <choices-outline>
        <line choice="default">
            <line choice="com.spinoff.DLYT"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.spinoff.DLYT" visible="false">
        <pkg-ref id="com.spinoff.DLYT"/>
    </choice>
    <pkg-ref id="com.spinoff.DLYT" version="$MARKETING" onConclusion="none">DLYT-component.pkg</pkg-ref>
</installer-gui-script>
EOF

cp "$PROJ/scripts/installer/welcome.html" "$PKG_DIR/welcome.html"

ARCHIVE_DIR="${PROJ}/dist"
mkdir -p "$ARCHIVE_DIR"
ARCHIVED_PKG="${ARCHIVE_DIR}/DLYT-${MARKETING}-${BUILD}.pkg"
OUT_PKG="${HOME}/Desktop/DLYT.pkg"

productbuild --distribution "$PKG_DIR/distribution.xml" \
  --package-path "$PKG_DIR" \
  --resources "$PKG_DIR" \
  --sign "$PKG_ID" \
  --timestamp \
  "$OUT_PKG"

# --- Notarização ---
print "Enviando para a Apple (costuma levar 1 a 10 min)…"
NOTARY_OUT="$(xcrun notarytool submit "$OUT_PKG" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)"
print "$NOTARY_OUT"
if ! print "$NOTARY_OUT" | grep -q "status: Accepted"; then
  SUB_ID="$(print "$NOTARY_OUT" | awk '/id:/ {print $2; exit}')"
  [[ -n "$SUB_ID" ]] && xcrun notarytool log "$SUB_ID" --keychain-profile "$NOTARY_PROFILE" || true
  print -u2 "Notarização rejeitada. Veja o log acima."
  exit 1
fi

xcrun stapler staple "$OUT_PKG"
xcrun stapler validate "$OUT_PKG"
spctl -a -vv -t install "$OUT_PKG"
pkgutil --check-signature "$OUT_PKG"

/bin/cp -f "$OUT_PKG" "$ARCHIVED_PKG"

print "Instalador (Mesa): $OUT_PKG"
print "Arquivo: $ARCHIVED_PKG"
ls -lh "$OUT_PKG" "$ARCHIVED_PKG"
open -R "$OUT_PKG"
