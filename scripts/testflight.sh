#!/bin/sh
# Archive Moon Club and upload it to TestFlight with an App Store Connect API key.
# Needs .env.testflight (gitignored) — see docs/TESTFLIGHT.md. Build numbers are UTC timestamps.
set -e
cd "$(dirname "$0")/.."
[ -f .env.testflight ] || { echo "Missing .env.testflight — see docs/TESTFLIGHT.md"; exit 1; }
. ./.env.testflight
: "${TEAM_ID:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_PATH:?}"
BUILD=$(date -u +%Y%m%d%H%M)
make test
xcodegen generate >/dev/null
rm -rf build/archive
xcodebuild -project MoonClub.xcodeproj -scheme MoonClub -configuration Release -destination "generic/platform=iOS" \
  -archivePath build/archive/MoonClub.xcarchive DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic CURRENT_PROJECT_VERSION="$BUILD" \
  -allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" archive
cat > build/archive/export.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>method</key><string>app-store-connect</string><key>teamID</key><string>$TEAM_ID</string>
<key>destination</key><string>upload</string><key>signingStyle</key><string>automatic</string></dict></plist>
PLIST
xcodebuild -exportArchive -archivePath build/archive/MoonClub.xcarchive -exportOptionsPlist build/archive/export.plist -exportPath build/archive/out \
  -allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
echo "✓ Build $BUILD uploaded. It appears in TestFlight after processing (about 5–15 minutes)."
