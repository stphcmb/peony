#!/bin/bash
# Builds Peony.app (if needed), installs it to /Applications, and sets it
# to start at login. No Xcode, no Apple Developer account, no App Store.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SRC="$DIR/dist/Peony.app"
APP_DEST="/Applications/Peony.app"
LABEL="com.positivevibeonly.peony.login"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

# One-time migration: remove the app under its old name (Flowers) so two
# copies don't both run at login.
pkill -x Flowers 2>/dev/null || true
launchctl unload "$HOME/Library/LaunchAgents/com.positivevibeonly.flowers.login.plist" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.positivevibeonly.flowers.login.plist"
rm -rf "/Applications/Flowers.app"

if [ ! -d "$APP_SRC" ]; then
  echo "Building Peony.app..."
  "$DIR/scripts/build-app.sh"
fi

echo "Installing to /Applications..."
# Quit a running copy first — otherwise `open -a` below finds it already
# running and never launches the freshly installed build.
pkill -x Peony 2>/dev/null || true
rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"

# Ad-hoc signed and unsigned by Apple, so a fresh git clone/download carries a
# quarantine flag that would otherwise show a "damaged app" dialog. Clearing
# it here is the same effect as right-click-Open, done once at install time.
xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true

# Start-at-login now lives in the app itself (LoginItem.swift registers it on
# first launch, and the menu bar's right-click menu toggles it), so this
# script's old LaunchAgent is removed — leaving it would mean two mechanisms
# racing to launch the same app.
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

open -a "$APP_DEST"

echo "Installed. Look for 🌸 in your menu bar — it starts automatically at login from now on."
echo "Turn that off any time: right-click 🌸 > Start at Login."
echo "Remove it any time: ./uninstall.sh"
