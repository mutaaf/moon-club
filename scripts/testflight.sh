#!/bin/sh
# Archive Moon Club and upload it to TestFlight with an App Store Connect API key.
# Then sets the TestFlight notes from release-notes/<version>.md, hands the build to testers and cuts a GitHub release.
# Needs .env.testflight (gitignored) — see docs/TESTFLIGHT.md. Build numbers are UTC timestamps.
#   STORE=1     App Store build: compiled with STORE_BUILD (no grown-up own-key AI or voice; MoonClub/App/Distribution.swift)
#               and numbered <timestamp>.1, which is how `asc.mjs store-meta/store-check` recognise it. `make appstore-build`.
#   VALIDATE=1  archive + export an .ipa and run App Store validation (altool --validate-app), without uploading.
set -e
cd "$(dirname "$0")/.."
[ -f .env.testflight ] || { echo "Missing .env.testflight — see docs/TESTFLIGHT.md"; exit 1; }
. ./.env.testflight
: "${TEAM_ID:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_PATH:?}"
BUILD=$(date -u +%Y%m%d%H%M)
CONDITIONS=""
if [ "${STORE:-0}" = 1 ]; then BUILD="$BUILD.1"; CONDITIONS="STORE_BUILD"; echo "• App Store build $BUILD (STORE_BUILD: no own-key features)"; fi
VERSION=$(sed -nE 's/.*MARKETING_VERSION: *"([^"]+)".*/\1/p' project.yml | head -1)
node scripts/asc.mjs notes "$VERSION" >/dev/null   # no fun release notes, no ship
node scripts/asc.mjs bundle
node scripts/asc.mjs signing   # our own distribution cert + an App Store profile per bundle id (app, widgets): App Manager keys cannot use cloud signing
[ "${SKIP_TESTS:-0}" = 1 ] || make test
xcodegen generate >/dev/null
rm -rf build/archive
xcodebuild -project MoonClub.xcodeproj -scheme MoonClub -configuration Release -destination "generic/platform=iOS" \
  -archivePath build/archive/MoonClub.xcarchive DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic CURRENT_PROJECT_VERSION="$BUILD" \
  ${CONDITIONS:+SWIFT_ACTIVE_COMPILATION_CONDITIONS="$CONDITIONS"} \
  -allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" archive
cat > build/archive/export.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>method</key><string>app-store-connect</string><key>teamID</key><string>$TEAM_ID</string>
<key>destination</key><string>$( [ "${VALIDATE:-0}" = 1 ] && echo export || echo upload )</string><key>signingStyle</key><string>manual</string>
<key>signingCertificate</key><string>Apple Distribution</string>
<key>provisioningProfiles</key><dict><key>com.mutaafaziz.moonclub</key><string>Moon Club App Store</string>
<key>com.mutaafaziz.moonclub.widgets</key><string>Moon Club Widgets App Store</string></dict></dict></plist>
PLIST
xcodebuild -exportArchive -archivePath build/archive/MoonClub.xcarchive -exportOptionsPlist build/archive/export.plist -exportPath build/archive/out \
  -allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
if [ "${VALIDATE:-0}" = 1 ]; then
  # altool finds the key as AuthKey_<id>.p8 in ~/.appstoreconnect/private_keys (where docs/TESTFLIGHT.md puts it).
  xcrun altool --validate-app -f build/archive/out/MoonClub.ipa -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "✓ Build $VERSION ($BUILD) passed App Store validation (not uploaded)."
  exit 0
fi
echo "✓ Build $VERSION ($BUILD) uploaded."
node scripts/asc.mjs ship "$BUILD"
if command -v gh >/dev/null; then
  git tag -f "v$VERSION-$BUILD" && git push -f origin "v$VERSION-$BUILD" >/dev/null 2>&1 || true
  gh release create "v$VERSION-$BUILD" --prerelease --title "Moon Club $VERSION ($BUILD) on TestFlight" --notes-file "release-notes/$VERSION.md" >/dev/null && echo "✓ GitHub release v$VERSION-$BUILD"
fi
