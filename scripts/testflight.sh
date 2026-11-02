#!/bin/sh
# Archive Moon Club and upload it to TestFlight with an App Store Connect API key.
# Then sets the TestFlight notes from release-notes/<version>.md, hands the build to testers and cuts a GitHub release.
# Needs .env.testflight (gitignored) — see docs/TESTFLIGHT.md. Build numbers are UTC timestamps.
set -e
cd "$(dirname "$0")/.."
[ -f .env.testflight ] || { echo "Missing .env.testflight — see docs/TESTFLIGHT.md"; exit 1; }
. ./.env.testflight
: "${TEAM_ID:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_PATH:?}"
BUILD=$(date -u +%Y%m%d%H%M)
VERSION=$(sed -nE 's/.*MARKETING_VERSION: *"([^"]+)".*/\1/p' project.yml | head -1)
node scripts/asc.mjs notes "$VERSION" >/dev/null   # no fun release notes, no ship
node scripts/asc.mjs bundle
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
echo "✓ Build $VERSION ($BUILD) uploaded."
node scripts/asc.mjs ship "$BUILD"
if command -v gh >/dev/null; then
  git tag -f "v$VERSION-$BUILD" && git push -f origin "v$VERSION-$BUILD" >/dev/null 2>&1 || true
  gh release create "v$VERSION-$BUILD" --prerelease --title "Moon Club $VERSION ($BUILD) on TestFlight" --notes-file "release-notes/$VERSION.md" >/dev/null && echo "✓ GitHub release v$VERSION-$BUILD"
fi
