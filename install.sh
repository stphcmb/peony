#!/bin/bash
# Builds Flowers.app (if needed), installs it to /Applications, and sets it
# to start at login. No Xcode, no Apple Developer account, no App Store.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SRC="$DIR/dist/Flowers.app"
APP_DEST="/Applications/Flowers.app"
LABEL="com.positivevibeonly.flowers.login"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

if [ ! -d "$APP_SRC" ]; then
  echo "Building Flowers.app..."
  "$DIR/scripts/build-app.sh"
fi

echo "Installing to /Applications..."
rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"

# Ad-hoc signed and unsigned by Apple, so a fresh git clone/download carries a
# quarantine flag that would otherwise show a "damaged app" dialog. Clearing
# it here is the same effect as right-click-Open, done once at install time.
xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-a</string>
    <string>$APP_DEST</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST_EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

open -a "$APP_DEST"

echo "Installed. Look for 🌸 in your menu bar — it starts automatically at login from now on."
echo "Remove it any time: ./uninstall.sh"
