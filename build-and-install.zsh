#!/bin/zsh
# Compila o DLYT e publica em /Applications/DLYT.app
set -euo pipefail

if [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
elif [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

PROJ="${HOME}/ARDUINO/XCODE/DLYT"
cd "$PROJ"

"$PROJ/scripts/bundle-helpers.sh"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi

xcodebuild -project DLYT.xcodeproj -scheme DLYT -configuration Debug \
  -destination 'platform=macOS,arch=arm64' build

# A fase de build já copia; reforça o destino caso o sandbox tenha bloqueado.
APP="$(/usr/bin/find "${HOME}/Library/Developer/Xcode/DerivedData" \
  -path '*/Build/Products/Debug/DLYT.app' -type d 2>/dev/null \
  | /usr/bin/head -1)"

"${PROJ}/scripts/install-to-applications.sh" "$APP"
open -a /Applications/DLYT.app
print "Substituído e aberto: /Applications/DLYT.app"
