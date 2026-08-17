#!/bin/bash
# Builds Peony.app from the Swift package. No Xcode required.
#
# (The Swift target is still named PositiveVibeOnlyApp internally — that's
# plumbing, renaming it buys nothing user-facing. Peony is the product name:
# the .app filename, the bundle identifier, the menu bar tooltip.)

set -euo pipefail

# Bump this to match the git tag before cutting a release — the update
# nudge (UpdateChecker.swift) compares this against GitHub's latest tag.
VERSION="1.3.2"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "Building..."
swift build -c release

APP="$DIR/dist/Peony.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

BIN_DIR="$(swift build -c release --show-bin-path)"
cp "$BIN_DIR/PositiveVibeOnlyApp" "$APP/Contents/MacOS/Peony"

# Standard macOS bundle layout: resources live in Contents/Resources, which
# codesign seals correctly. (ContentStore.load() checks this path first, and
# only falls back to SPM's own Bundle.module — which expects a nonstandard
# flat layout — for `swift run` during development.)
RES_BUNDLE=$(find "$BIN_DIR" -maxdepth 1 -name '*_PositiveVibeOnlyApp.bundle' -print -quit)
if [ -n "$RES_BUNDLE" ] && [ -f "$RES_BUNDLE/content.json" ]; then
  cp "$RES_BUNDLE/content.json" "$APP/Contents/Resources/content.json"
  cp "$RES_BUNDLE/Fraunces.ttf" "$APP/Contents/Resources/Fraunces.ttf"
  cp "$RES_BUNDLE/Karla.ttf" "$APP/Contents/Resources/Karla.ttf"
else
  echo "error: resource bundle not found next to build output ($BIN_DIR)" >&2
  exit 1
fi

# App icon isn't looked up at runtime by the app itself (Finder/Dock read it
# straight from Info.plist's CFBundleIconFile), so it's copied directly from
# source rather than routed through SPM's resource bundle.
cp "$DIR/Sources/PositiveVibeOnlyApp/Resources/Icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>Peony</string>
  <key>CFBundleIdentifier</key>
  <string>com.positivevibeonly.peony</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleExecutable</key>
  <string>Peony</string>
  <key>PeonyBuildDate</key>
  <string>$(date "+%b %-d")</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSUIElement</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
</dict>
</plist>
PLIST_EOF

# Ad-hoc sign so Gatekeeper stops flagging it as "damaged" on other Macs.
codesign --force --deep --sign - "$APP" 2>&1 | grep -v '^$' || true

echo "Built: $APP"
