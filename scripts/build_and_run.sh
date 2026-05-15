#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="snaptex"
PRODUCT_NAME="snaptex"
BUNDLE_ID="${SNAPTEX_BUNDLE_ID:-dev.snaptex.app}"
ALLOW_BUNDLE_ID_MISMATCH="${SNAPTEX_ALLOW_BUNDLE_ID_MISMATCH:-0}"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
INSTALL_BUNDLE="/Applications/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Sources/SnapTexApp/Resources/logo.png"
MATHJAX_SOURCE="$ROOT_DIR/Sources/SnapTexApp/Resources/MathJax.js"
PYTHON_SOURCE="$ROOT_DIR/python/snaptex_worker"

signing_identity() {
  if [[ -n "${SNAPTEX_SIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$SNAPTEX_SIGN_IDENTITY"
    return
  fi

  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  printf '%s\n' "$identities" | awk -F\" '/valid identities found/ { next } NF >= 2 { print $2; exit }'
}

sign_app() {
  local bundle="$1"
  local identity="$2"
  local log_path="$DIST_DIR/codesign.log"
  rm -f "$log_path"

  codesign --force --deep --timestamp=none --sign "$identity" "$bundle" >"$log_path" 2>&1
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build --product "$PRODUCT_NAME"
BUILD_BINARY="$(swift build --show-bin-path)/$PRODUCT_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$APP_RESOURCES/logo.png"
  ICONSET="$DIST_DIR/AppIcon.iconset"
  rm -rf "$ICONSET"
  python scripts/make_app_icon.py "$ICON_SOURCE" "$ICONSET" --app-icon-png "$APP_RESOURCES/AppIcon.png"
  iconutil -c icns "$ICONSET" -o "$APP_RESOURCES/AppIcon.icns"
  rm -rf "$ICONSET"
fi

if [[ -f "$MATHJAX_SOURCE" ]]; then
  cp "$MATHJAX_SOURCE" "$APP_RESOURCES/MathJax.js"
fi

if [[ -d "$PYTHON_SOURCE" ]]; then
  mkdir -p "$APP_RESOURCES/python"
  ditto "$PYTHON_SOURCE" "$APP_RESOURCES/python/snaptex_worker"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

install_app() {
  if [[ -d "$INSTALL_BUNDLE" ]]; then
    EXISTING_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INSTALL_BUNDLE/Contents/Info.plist" 2>/dev/null || true)"
    if [[ -n "$EXISTING_ID" && "$EXISTING_ID" != "$BUNDLE_ID" && "$ALLOW_BUNDLE_ID_MISMATCH" != "1" ]]; then
      echo "Refusing to overwrite $INSTALL_BUNDLE because it has bundle id $EXISTING_ID" >&2
      exit 1
    fi
  fi

  if [[ -d "$INSTALL_BUNDLE" ]]; then
    rm -rf "$INSTALL_BUNDLE/Contents"
    mkdir -p "$INSTALL_BUNDLE"
    ditto "$APP_BUNDLE/Contents" "$INSTALL_BUNDLE/Contents"
  else
    ditto "$APP_BUNDLE" "$INSTALL_BUNDLE"
  fi
}

SIGN_IDENTITY="$(signing_identity)"
if [[ -n "$SIGN_IDENTITY" ]] && security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  echo "signing with identity: $SIGN_IDENTITY"
  if ! sign_app "$APP_BUNDLE" "$SIGN_IDENTITY"; then
    echo "warning: code-signing identity failed; used ad-hoc signing" >&2
    codesign --force --deep --timestamp=none --sign - "$APP_BUNDLE" >/dev/null
  fi
else
  codesign --force --deep --timestamp=none --sign - "$APP_BUNDLE" >/dev/null
  echo "warning: no matching code-signing identity found; used ad-hoc signing" >&2
fi

install_app
/usr/bin/touch "$INSTALL_BUNDLE"

open_app() {
  /usr/bin/open -n "$INSTALL_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
