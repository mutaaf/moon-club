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
# Readiness: debug builds append "root" (the app is on screen) and "play" (a game, boss or lesson is open) to
# Library/Caches/moonclub.ready. Wait for the token instead of a fixed sleep: boss screens on iPad used to be
# captured blank because the app hadn't finished launching. Falls back to the timeout if no token comes.
clear_ready() { d=$(xcrun simctl get_app_container "$1" com.mutaafaziz.moonclub data 2>/dev/null) && rm -f "$d/Library/Caches/moonclub.ready"; }
wait_ready() { # <sim> <token>
  d=$(xcrun simctl get_app_container "$1" com.mutaafaziz.moonclub data 2>/dev/null)
  for _ in $(seq 1 "${READY_TRIES:-80}"); do grep -q "$2" "$d/Library/Caches/moonclub.ready" 2>/dev/null && break; sleep 0.5; done
  sleep "${SETTLE:-1.5}"  # let enter animations finish
}
for NAME in "$PHONE" "$PAD"; do
  ID=$( [ "$NAME" = "$PHONE" ] && echo "${PHONE_ID:-}" || echo "${PAD_ID:-}" ); [ -n "$ID" ] || ID=$(id_of "$NAME")
  [ -n "$ID" ] || { echo "no simulator named $NAME"; continue; }
  xcrun simctl boot "$ID" 2>/dev/null || true
  T=240 t xcrun simctl bootstatus "$ID" -b >/dev/null
  xcrun simctl status_bar "$ID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 2>/dev/null || true
  T=180 t xcrun simctl install "$ID" "$APP"
  TAG=$(echo "$NAME" | tr ' ()' '___' | tr -s '_')
  for SHOT in story guess piggy school luna garden quest:lemonade quest:save:tree quest:dividends:real lesson boss:canyon-boss boss:coast-boss game:canyon-read; do
    xcrun simctl terminate "$ID" com.mutaafaziz.moonclub 2>/dev/null || true
    clear_ready "$ID"; TOKEN=root
    case $SHOT in
      quest:*) t xcrun simctl launch "$ID" com.mutaafaziz.moonclub -demo -quest "${SHOT#quest:}" >/dev/null ;;
      lesson) TOKEN=play; t xcrun simctl launch "$ID" com.mutaafaziz.moonclub -demo -tab school -lesson needs >/dev/null ;;
      boss:*|game:*) TOKEN=play; t xcrun simctl launch "$ID" com.mutaafaziz.moonclub -demo -tab school -world mid -play "${SHOT#*:}" >/dev/null ;;
      garden) t xcrun simctl launch "$ID" com.mutaafaziz.moonclub -demo -tab piggy -garden >/dev/null ;;
      *) t xcrun simctl launch "$ID" com.mutaafaziz.moonclub -demo -tab "$SHOT" >/dev/null ;;
    esac
    wait_ready "$ID" "$TOKEN"
    xcrun simctl io "$ID" screenshot "$OUT/$TAG-$(echo $SHOT | tr ':' '-').png" >/dev/null 2>&1
  done
done

# ── iPhone Duo (App Store: outer 1398×2034, inner 2007×2853 — the simulator's native framebuffers) ──
# The simulator boots closed, so the outer display ("primary") is always captured. The inner display
# ("primary-1") is captured only when the device is open: unfold it in Device Hub first (there's no
# simctl hinge control). `-pose` (debug builds) pins a hinge reading so the hinge *effects* (Luna's
# moon, the piggy lid, Game Night hints) can be captured on any display.
DUO="${DUO:-Moon Club Duo}"
DID="${DUO_ID:-$(id_of "$DUO")}"
[ -n "$DID" ] || DID=$(xcrun simctl create "$DUO" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1 2>/dev/null || true)
if [ -n "$DID" ]; then
  xcrun simctl boot "$DID" 2>/dev/null || true
  T=240 t xcrun simctl bootstatus "$DID" -b >/dev/null
  xcrun simctl status_bar "$DID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 2>/dev/null || true
  T=180 t xcrun simctl install "$DID" "$APP"
  for SHOT in story guess piggy school gamenight lesson pose-book-school pose-book-piggy; do
    xcrun simctl terminate "$DID" com.mutaafaziz.moonclub 2>/dev/null || true
    clear_ready "$DID"
    case $SHOT in
      gamenight) t xcrun simctl launch "$DID" com.mutaafaziz.moonclub -demo -tab guess -gamenight >/dev/null ;;
      lesson) t xcrun simctl launch "$DID" com.mutaafaziz.moonclub -demo -tab school -lesson needs >/dev/null ;;
      pose-book-*) t xcrun simctl launch "$DID" com.mutaafaziz.moonclub -demo -tab "${SHOT#pose-book-}" -pose book -hinge 95 >/dev/null ;;
      *) t xcrun simctl launch "$DID" com.mutaafaziz.moonclub -demo -tab "$SHOT" >/dev/null ;;
    esac
    wait_ready "$DID" "$([ "$SHOT" = lesson ] && echo play || echo root)"
    xcrun simctl io "$DID" screenshot --display=primary "$OUT/iPhone_Duo-outer-$SHOT.png" >/dev/null 2>&1
    T=20 t xcrun simctl io "$DID" screenshot --display=primary-1 "$OUT/iPhone_Duo-inner-$SHOT.png" >/dev/null 2>&1
    # Drop the inner shot when the device is closed (the inner framebuffer is all black).
    [ -f "$OUT/iPhone_Duo-inner-$SHOT.png" ] && [ "$(sips -g pixelWidth "$OUT/iPhone_Duo-inner-$SHOT.png" 2>/dev/null | awk '/pixelWidth/ {print $2}')" = "2007" ] && \
      python3 -c "import sys,zlib;d=open(sys.argv[1],'rb').read();sys.exit(0 if len(d)>60000 else 1)" "$OUT/iPhone_Duo-inner-$SHOT.png" || rm -f "$OUT/iPhone_Duo-inner-$SHOT.png"
  done
fi
echo "screenshots in $OUT"
