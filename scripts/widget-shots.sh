#!/bin/sh
# Render every widget family and Live Activity view to PNGs for design review (light + dark, real iPhone sizes).
# Usage: scripts/widget-shots.sh [out dir]   (default build/widget-shots)
set -e
cd "$(dirname "$0")/.."
OUT="${1:-$PWD/build/widget-shots}"
mkdir -p "$OUT"
xcodegen generate >/dev/null
TEST_RUNNER_WIDGET_SHOTS_DIR="$OUT" xcodebuild -project MoonClub.xcodeproj -scheme MoonClub \
  -destination "platform=iOS Simulator,name=${SIM_PHONE:-iPhone 17}" -derivedDataPath build/dd -quiet \
  -only-testing:MoonClubTests/WidgetRenderTests test
echo "✓ $(ls "$OUT" | wc -l | tr -d ' ') images in $OUT"
