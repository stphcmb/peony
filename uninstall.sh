#!/bin/bash
# Removes Peony from login items and /Applications.

set -uo pipefail

LABEL="com.positivevibeonly.peony.login"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

pkill -x Peony 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "/Applications/Peony.app"

echo "Removed."
