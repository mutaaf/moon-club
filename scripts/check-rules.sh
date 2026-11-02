#!/bin/sh
# Kids-safety rules that are easiest to enforce on the source (run by `make test` and CI):
#  1. No links out of the app, or openURL, anywhere except the Grown-up corner (behind the parental gate).
#  2. No third-party SDKs, analytics or ads: the only package dependency is our own MoonClubCore.
#  3. Keys and Luna (also unit-tested in MoonClubCore/BrainTests):
#     a. the free brain's request (Requests.luna) never attaches any key;
#     b. a provider key header is set ONLY in Requests.byok (gated on consent for that provider), Requests.models
#        (the grown-up key check, no kid text) and Requests.speak (voice: app copy / Luna's answers only);
#     c. nobody hard-codes consent: every Requests.byok call passes the saved consent.
#  4. Every MARKETING_VERSION has fun, link-free release notes (release-notes/<version>.md, ≤ 4000 chars).
#  5. Widgets/Live Activities: only moonclub:// deep links, no web URLs, no push tokens.
set -e
cd "$(dirname "$0")/.."
fail=0
hits=$(grep -rnE '\bLink\(|openURL|UIApplication\.shared\.open' MoonClub MoonClubWidgets Shared --include=*.swift | grep -v '^MoonClub/Features/GrownUps.swift' \
  | grep -v 'Link(destination: MoonLink\.' || true)  # widgets deep-link INTO the app (moonclub://), never out
hits="$hits$(grep -rnE 'https?://' MoonClubWidgets Shared --include=*.swift || true)"  # widgets and their intents never reach the web
[ -z "$hits" ] || { echo "✗ links out of the app outside GrownUps.swift:"; echo "$hits"; fail=1; }
pk=$(grep -nE '^\s*[A-Za-z]+:\s*\{\s*(url|github|from):' project.yml || true)
[ -z "$pk" ] || { echo "✗ remote package dependencies are not allowed (Kids Category):"; echo "$pk"; fail=1; }
grep -rnE 'import (Firebase|Amplitude|Mixpanel|Segment|GoogleMobileAds|FacebookCore|AppsFlyer|Sentry)' MoonClub MoonClubWidgets Shared Packages && { echo "✗ third-party SDK import"; fail=1; } || true

CORE=Packages/MoonClubCore/Sources/MoonClubCore
KEYHDR='forHTTPHeaderField: "(x-mp-key|x-api-key|authorization)"'
# 3a
awk '/static func luna\(/,/return r/' $CORE/Services.swift | grep -qE "$KEYHDR" && { echo "✗ the free Luna request sets a key header"; fail=1; } || true
# 3b: every key header must sit inside an allowed builder (tracks the enclosing `static func`)
bad=$(find $CORE MoonClub -name '*.swift' -exec awk -v re="$KEYHDR" '
  /static func [A-Za-z]+\(/ { match($0, /static func [A-Za-z]+/); fn = substr($0, RSTART + 12, RLENGTH - 12) }
  $0 ~ re && fn != "byok" && fn != "models" && fn != "speak" { print FILENAME ":" FNR ": in " (fn == "" ? "?" : fn) }
' {} \;)
[ -z "$bad" ] || { echo "✗ key header outside Requests.byok/models/speak:"; echo "$bad"; fail=1; }
awk '/static func byok\(/,/^  }/' $CORE/Brain.swift | grep -q 'guard consent == p else { return nil }' || { echo "✗ Requests.byok must start with: guard consent == p else { return nil }"; fail=1; }
# 3c
hc=$(grep -rnE 'Requests\.byok\(.*consent: *\.(anthropic|openai|gemini|xai)' MoonClub $CORE || true)
[ -z "$hc" ] || { echo "✗ hard-coded BYOK consent:"; echo "$hc"; fail=1; }

v=$(sed -nE 's/.*MARKETING_VERSION: *"([^"]+)".*/\1/p' project.yml | head -1)
node scripts/asc.mjs notes "$v" >/dev/null || { echo "✗ release-notes/$v.md missing or invalid (see release-notes/README.md)"; fail=1; }
grep -rnE 'pushType: *\.token|pushTokenUpdates' MoonClub MoonClubWidgets Shared --include=*.swift && { echo "✗ Live Activities must stay local (no push tokens)"; fail=1; } || true
[ $fail -eq 0 ] && echo "✓ kids-safety rules hold"
exit $fail
