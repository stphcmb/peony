#!/bin/bash
# Removes Peony from login items and /Applications.

set -uo pipefail

LABEL="com.positivevibeonly.peony.login"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

pkill -x Peony 2>/dev/null || true

# Legacy: older installs started the app from this LaunchAgent. Current builds
# register themselves (LoginItem.swift), and macOS drops that registration when
# the bundle disappears below.
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

rm -rf "/Applications/Peony.app"

# The app records which bundle path it already applied its start-at-login
# default to. Clearing it means a later reinstall to the same path starts
# fresh instead of assuming the (now removed) registration is still there.
defaults delete com.positivevibeonly.peony LoginItemDefaultAppliedForPath 2>/dev/null || true

echo "Removed."
