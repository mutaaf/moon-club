#!/bin/sh
# Build Moon Club and install it on a paired iPhone/iPad over USB or Wi-Fi.
# Usage: make device      or   DEVICE=<udid> TEAM_ID=<team> scripts/device.sh
set -e
cd "$(dirname "$0")/.."
TEAM_ID="${TEAM_ID:-Z73865R687}"
# Physical UDIDs look like 00008130-001614883021401C (8-16 hex), not the 8-4-4-4-12 simulator form.
# A paired device stays "available" over Wi-Fi (same network, Mac and phone awake), so no cable is needed after the first trust.
list=$(xcrun devicectl list devices 2>/dev/null | grep 'physical' | grep 'available (paired)' || true)
DEVICE="${DEVICE:-$(echo "$list" | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1)}"
[ -n "$DEVICE" ] || { echo "No paired device available. Unlock the phone; cable it once (Trust this Mac), after that same Wi-Fi is enough."; exit 1; }
xcodegen generate >/dev/null
xcodebuild -project MoonClub.xcodeproj -scheme MoonClub -configuration Release -destination "generic/platform=iOS" \
  -derivedDataPath build/device DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates -quiet build
xcrun devicectl device install app --device "$DEVICE" build/device/Build/Products/Release-iphoneos/MoonClub.app
xcrun devicectl device process launch --device "$DEVICE" com.mutaafaziz.moonclub
echo "✓ Moon Club is on your device."
