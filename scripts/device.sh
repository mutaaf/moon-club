#!/bin/sh
# Build Moon Club and install it on a paired iPhone/iPad over USB or Wi-Fi.
# Usage: make device      or   DEVICE=<udid> TEAM_ID=<team> scripts/device.sh
set -e
cd "$(dirname "$0")/.."
TEAM_ID="${TEAM_ID:-Z73865R687}"
DEVICE="${DEVICE:-$(xcrun devicectl list devices 2>/dev/null | awk '/available \(paired\)/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/) {print $i; exit}}')}"
[ -n "$DEVICE" ] || { echo "No paired device available. Unlock the phone, connect it (or same Wi-Fi), and trust this Mac."; exit 1; }
xcodegen generate >/dev/null
xcodebuild -project MoonClub.xcodeproj -scheme MoonClub -configuration Release -destination "generic/platform=iOS" \
  -derivedDataPath build/device DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates -quiet build
xcrun devicectl device install app --device "$DEVICE" build/device/Build/Products/Release-iphoneos/MoonClub.app
xcrun devicectl device process launch --device "$DEVICE" com.mutaafaziz.moonclub
echo "✓ Moon Club is on your device."
