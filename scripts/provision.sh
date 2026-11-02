#!/bin/sh
# Let Xcode register Moon Club's App IDs, capabilities and the App Group on the developer portal, using the
# App Store Connect API key (the App Store Connect API itself has no App Groups endpoint).
# A Debug build for a generic device with -allowProvisioningUpdates is enough. Idempotent.
set -e
cd "$(dirname "$0")/.."
[ -f .env.testflight ] || { echo "Missing .env.testflight — see docs/TESTFLIGHT.md"; exit 1; }
. ./.env.testflight
xcodegen generate >/dev/null
xcodebuild -project MoonClub.xcodeproj -scheme MoonClub -configuration Debug -destination generic/platform=iOS \
  -derivedDataPath build/provision DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" -quiet build
echo "✓ App IDs, App Group and development profiles are registered"
