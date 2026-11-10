#!/bin/sh
# App Store screenshots at Apple's exact sizes, from the simulator in demo mode (offline fakes + a seeded week):
#   build/store-shots/iphone-69/  1320×2868  ("Store 69": iPhone 17 Pro Max, 6.9")
#   build/store-shots/ipad-13/    2064×2752  ("Store iPad 13": iPad Pro 13-inch (M5))
#   build/store-shots/iphone-duo/ 1398×2034 outer (+ 2007×2853 inner when unfolded) ("Store Duo", iOS 27.1 runtime only):
#                                 Duo screenshots + a 27.1 SDK build earn the App Store's "Made for iPhone Duo" badge.
#                                 The simulator boots closed and simctl has no hinge control, so the inner display is
#                                 captured only if you unfold it in Device Hub first (blank inner frames are dropped).
# Upload them with `node scripts/asc.mjs store-shots` (idempotent). Usage: scripts/store-shots.sh [outdir]
# Needs the Debug simulator build (`make build`). The simulators are created on first use (iOS 27.0 runtime).
set -e
cd "$(dirname "$0")/.."
OUT="${1:-build/store-shots}"
APP=build/dd/Build/Products/Debug-iphonesimulator/MoonClub.app
[ -d "$APP" ] || { echo "no $APP: run make build first"; exit 1; }
RUNTIME="${STORE_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-27-0}"
id_of() { xcrun simctl list devices available | grep -F "    $1 (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'; }
sim() { ID=$(id_of "$1"); [ -n "$ID" ] || ID=$(xcrun simctl create "$1" "$2" "$RUNTIME"); echo "$ID"; }
# Some simulator runtimes hang on `simctl launch`; every call gets a timeout (as in shots.sh).
t() { "$@" & p=$!; ( sleep "${T:-60}"; kill $p 2>/dev/null ) 2>/dev/null & w=$!; wait $p 2>/dev/null || true; kill $w 2>/dev/null || true; }

# The order is the App Store order: the first three carry the listing.
SHOTS="world boss candles story shop luna piggy badges school"
args() {
  case $1 in
    world) echo "-tab school -world mid" ;;
    boss) echo "-tab school -world all -play coast-boss" ;;
    candles) echo "-tab school -world all -play canyon-build" ;;
    story) echo "-tab story" ;;
    shop) echo "-locker shop -points 640" ;;
    luna) echo "-tab luna" ;;
    piggy) echo "-tab piggy" ;;
    badges) echo "-tab story -locker badges -world mid" ;;
    school) echo "-tab school -world mid -library" ;;  # the living lesson cards (0.16.2)
  esac
}

installed() { xcrun simctl listapps "$1" 2>/dev/null | grep -q com.mutaafaziz.moonclub || { echo "✗ Moon Club didn't install on $1"; exit 1; }; }
# The app must be running (not the home screen) before a frame counts.
running() { for i in $(seq 1 40); do xcrun simctl spawn "$1" launchctl list 2>/dev/null | grep -q "UIKitApplication:com.mutaafaziz.moonclub" && return 0; sleep 3; done; echo "✗ Moon Club isn't running on $1"; exit 1; }
# Shut each simulator down when its set is done: other projects share this Mac's CoreSimulator.
done_with() { T=120 t xcrun simctl shutdown "$1"; }

shoot() { # name device-type dir width height
  ID=$(sim "$1" "$2"); D="$OUT/$3"; rm -rf "$D"; mkdir -p "$D"
  xcrun simctl boot "$ID" 2>/dev/null || true
  T=900 t xcrun simctl bootstatus "$ID" -b >/dev/null  # a busy Mac can take minutes
  T=20 t xcrun simctl ui "$ID" appearance light
  T=20 t xcrun simctl status_bar "$ID" override --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 2>/dev/null || true
  T=900 t xcrun simctl install "$ID" "$APP"  # a fresh simulator image's first install can take minutes
  installed "$ID"
  n=1
  for S in $SHOTS; do
    T=20 t xcrun simctl terminate "$ID" com.mutaafaziz.moonclub
    # shellcheck disable=SC2046
    T=180 t xcrun simctl launch "$ID" com.mutaafaziz.moonclub -demo $(args "$S") >/dev/null
    running "$ID"
    sleep "${WAIT:-6}"
    F="$D/$(printf %02d $n)-$S.png"
    xcrun simctl io "$ID" screenshot --type=png "$F" >/dev/null 2>&1
    # A blank or boot-logo frame compresses tiny: give the app longer and try again (first launches are slow).
    for retry in 1 2 3; do [ "$(wc -c < "$F")" -gt 250000 ] && break; sleep 15; xcrun simctl io "$ID" screenshot --type=png "$F" >/dev/null 2>&1; done
    [ "$(wc -c < "$F")" -gt 250000 ] || { echo "✗ $F looks blank (app not on screen)"; exit 1; }
    node scripts/brand/png.mjs "$F"
    w=$(sips -g pixelWidth "$F" | awk '/pixelWidth/ {print $2}'); h=$(sips -g pixelHeight "$F" | awk '/pixelHeight/ {print $2}')
    [ "$w" = "$4" ] && [ "$h" = "$5" ] || { echo "✗ $F is ${w}×${h}, App Store needs $4×$5"; exit 1; }
    n=$((n + 1))
  done
  echo "✓ $1: $(ls "$D" | wc -l | tr -d ' ') screenshots in $D ($4×$5)"
  done_with "$ID"
}

shoot_duo() {
  ID=$(xcrun simctl list devices available | grep -F "    Store Duo (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  [ -n "$ID" ] || ID=$(xcrun simctl create "Store Duo" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1)
  D="$OUT/iphone-duo"; rm -rf "$D"; mkdir -p "$D"
  xcrun simctl boot "$ID" 2>/dev/null || true
  T=900 t xcrun simctl bootstatus "$ID" -b >/dev/null  # a busy Mac can take minutes
  T=20 t xcrun simctl ui "$ID" appearance light
  T=20 t xcrun simctl status_bar "$ID" override --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 2>/dev/null || true
  T=900 t xcrun simctl install "$ID" "$APP"
  installed "$ID"
  n=1
  for S in world boss story piggy:book luna; do
    T=20 t xcrun simctl terminate "$ID" com.mutaafaziz.moonclub
    case $S in
      *:book) A="-tab ${S%:book} -pose book -hinge 95" ;;  # the hinge effects (piggy lid, Luna's moon), pinned
      *) A=$(args "$S") ;;
    esac
    # shellcheck disable=SC2086
    T=180 t xcrun simctl launch "$ID" com.mutaafaziz.moonclub -demo $A >/dev/null
    running "$ID"
    sleep "${WAIT:-6}"
    N=$(printf %02d $n)-$(echo "$S" | tr ':' '-')
    xcrun simctl io "$ID" screenshot --display=primary --type=png "$D/$N-outer.png" >/dev/null 2>&1
    T=20 t xcrun simctl io "$ID" screenshot --display=primary-1 --type=png "$D/$N-inner.png" >/dev/null 2>&1
    # keep the inner frame only if the device is open (a closed inner framebuffer is all black, so it compresses
    # tiny). Measure after dropping alpha: simctl's own RGBA encoding of a black frame is over 60 KB.
    [ -f "$D/$N-inner.png" ] && node scripts/brand/png.mjs "$D/$N-inner.png"
    [ -f "$D/$N-inner.png" ] && [ "$(wc -c < "$D/$N-inner.png")" -gt 60000 ] || rm -f "$D/$N-inner.png"
    for retry in 1 2 3; do [ "$(wc -c < "$D/$N-outer.png")" -gt 150000 ] && break; sleep 15; xcrun simctl io "$ID" screenshot --display=primary --type=png "$D/$N-outer.png" >/dev/null 2>&1; done
    node scripts/brand/png.mjs "$D"/$N-*.png
    n=$((n + 1))
  done
  echo "✓ Store Duo: $(ls "$D" | wc -l | tr -d ' ') screenshots in $D"
  done_with "$ID"
}

shoot "Store 69" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max iphone-69 1320 2868
shoot "Store iPad 13" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB ipad-13 2064 2752
[ "${DUO:-1}" = 0 ] || shoot_duo
