#!/usr/bin/env bash
# Build a Release Comunicator.app into ./releases for distribution.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASES="$ROOT/releases"
DERIVED="${DERIVED_DATA_PATH:-/tmp/ComunicatorRelease}"
APP_NAME="Comunicator"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found. Install with: brew install xcodegen" >&2
  exit 1
fi

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "error: Xcode not found at $DEVELOPER_DIR" >&2
  exit 1
fi

echo "→ Generating Xcode project…"
xcodegen generate

echo "→ Building Release…"
rm -rf "$DERIVED"
xcodebuild \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -quiet \
  build

SRC="$DERIVED/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$SRC" ]]; then
  echo "error: build product missing: $SRC" >&2
  exit 1
fi

mkdir -p "$RELEASES"
rm -rf "$RELEASES/${APP_NAME}.app" "$RELEASES/${APP_NAME}.zip"
cp -R "$SRC" "$RELEASES/${APP_NAME}.app"

# Clear extended attributes that sometimes confuse Gatekeeper on copy
xattr -cr "$RELEASES/${APP_NAME}.app" 2>/dev/null || true

echo "→ Zipping…"
ditto -c -k --keepParent "$RELEASES/${APP_NAME}.app" "$RELEASES/${APP_NAME}.zip"

echo ""
echo "Done."
echo "  App:  $RELEASES/${APP_NAME}.app"
echo "  Zip:  $RELEASES/${APP_NAME}.zip"
echo ""
echo "Share the zip. Recipients: right-click → Open (no Apple Developer Program required)."
