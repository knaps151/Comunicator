#!/usr/bin/env bash
# Build a Release Comunicator.app into ./releases for distribution.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASES="$ROOT/releases"
DERIVED="${DERIVED_DATA_PATH:-}"
APP_NAME="Comunicator"

# Use default Xcode location if not set
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  fi
fi

cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found. Install with: brew install xcodegen" >&2
  exit 1
fi

if [[ -n "${DEVELOPER_DIR:-}" ]] && [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "error: Xcode not found at $DEVELOPER_DIR" >&2
  exit 1
fi

echo "→ Generating Xcode project…"
xcodegen generate

# Use a temporary directory for derived data if not specified
if [[ -z "$DERIVED" ]]; then
  DERIVED=$(mktemp -d)
  trap 'rm -rf "$DERIVED"' EXIT
fi

echo "→ Building Release…"
if [[ -d "$DERIVED" ]]; then
  rm -rf "${DERIVED:?}/Build"
fi
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
ditto -c -k --norsrc --noextattr --keepParent "$RELEASES/${APP_NAME}.app" "$RELEASES/${APP_NAME}.zip"

echo ""
echo "Done."
echo "  App:  $RELEASES/${APP_NAME}.app"
echo "  Zip:  $RELEASES/${APP_NAME}.zip"
echo ""
echo "Share the zip. Recipients: right-click → Open (no Apple Developer Program required)."
