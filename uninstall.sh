#!/bin/bash
# Removes Flowers from login items and /Applications.

set -uo pipefail

LABEL="com.positivevibeonly.flowers.login"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

pkill -x Flowers 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "/Applications/Flowers.app"

echo "Removed."
