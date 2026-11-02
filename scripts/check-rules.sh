#!/bin/sh
# Kids-safety rules that are easiest to enforce on the source (run by `make test` and CI):
#  1. No links out of the app, or openURL, anywhere except the Grown-up corner (behind the parental gate).
#  2. No third-party SDKs, analytics or ads: the only package dependency is our own MoonClubCore.
#  3. Luna's request builder never attaches a key (also unit-tested in MoonClubCore).
set -e
cd "$(dirname "$0")/.."
fail=0
hits=$(grep -rnE '\bLink\(|openURL|UIApplication\.shared\.open' MoonClub --include=*.swift | grep -v '^MoonClub/Features/GrownUps.swift' || true)
[ -z "$hits" ] || { echo "✗ links out of the app outside GrownUps.swift:"; echo "$hits"; fail=1; }
pk=$(grep -nE '^\s*[A-Za-z]+:\s*\{\s*(url|github|from):' project.yml || true)
[ -z "$pk" ] || { echo "✗ remote package dependencies are not allowed (Kids Category):"; echo "$pk"; fail=1; }
grep -rnE 'import (Firebase|Amplitude|Mixpanel|Segment|GoogleMobileAds|FacebookCore|AppsFlyer|Sentry)' MoonClub Packages && { echo "✗ third-party SDK import"; fail=1; } || true
awk '/static func luna\(/,/return r/' Packages/MoonClubCore/Sources/MoonClubCore/Services.swift | grep -q 'forHTTPHeaderField: "x-mp-key"' && { echo "✗ Luna request sets a key header"; fail=1; } || true
[ $fail -eq 0 ] && echo "✓ kids-safety rules hold"
exit $fail
