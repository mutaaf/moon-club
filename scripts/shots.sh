#!/bin/sh
# Screenshot every main screen in demo mode (offline fakes + a seeded week) on an iPhone and an iPad.
# Usage: scripts/shots.sh [outdir]
set -e
cd "$(dirname "$0")/.."
OUT="${1:-build/shots}"; mkdir -p "$OUT"
APP=build/dd/Build/Products/Debug-iphonesimulator/MoonClub.app
PHONE="${PHONE:-iPhone 17}"; PAD="${PAD:-iPad Pro 11-inch (M5)}"
id_of() { xcrun simctl list devices available | grep -F "    $1 (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'; }
# Some freshly-installed simulator runtimes hang on `simctl launch`; every call gets a timeout.
t() { "$@" & p=$!; ( sleep "${T:-60}"; kill $p 2>/dev/null ) 2>/dev/null & w=$!; wait $p 2>/dev/null || true; kill $w 2>/dev/null || true; }
for NAME in "$PHONE" "$PAD"; do
  ID=$( [ "$NAME" = "$PHONE" ] && echo "${PHONE_ID:-}" || echo "${PAD_ID:-}" ); [ -n "$ID" ] || ID=$(id_of "$NAME")
  [ -n "$ID" ] || { echo "no simulator named $NAME"; continue; }
  xcrun simctl boot "$ID" 2>/dev/null || true
  T=240 t xcrun simctl bootstatus "$ID" -b >/dev/null
  xcrun simctl status_bar "$ID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 2>/dev/null || true
  T=180 t xcrun simctl install "$ID" "$APP"
  TAG=$(echo "$NAME" | tr ' ()' '___' | tr -s '_')
  for SHOT in story guess piggy school luna quest:lemonade quest:save:tree quest:dividends:real lesson; do
    xcrun simctl terminate "$ID" com.mutaafaziz.moonclub 2>/dev/null || true
    case $SHOT in
      quest:*) t xcrun simctl launch "$ID" com.mutaafaziz.moonclub -demo -quest "${SHOT#quest:}" >/dev/null ;;
      lesson) t xcrun simctl launch "$ID" com.mutaafaziz.moonclub -demo -tab school -lesson needs >/dev/null ;;
      *) t xcrun simctl launch "$ID" com.mutaafaziz.moonclub -demo -tab "$SHOT" >/dev/null ;;
    esac
    sleep "${WAIT:-4}"
    xcrun simctl io "$ID" screenshot "$OUT/$TAG-$(echo $SHOT | tr ':' '-').png" >/dev/null 2>&1
  done
done
echo "screenshots in $OUT"
