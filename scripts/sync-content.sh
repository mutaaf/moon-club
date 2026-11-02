#!/bin/sh
# Pull the single source of truth for kid content from the metaphases repo into the app bundle
# (and the core test resources, where the vectors prove the Swift port matches the web).
# Usage: scripts/sync-content.sh [path to metaphases checkout]   (default ../metaphases)
set -e
cd "$(dirname "$0")/.."
MP="${1:-${METAPHASES:-../metaphases}}"
[ -f "$MP/scripts/export-kids-content.ts" ] || { echo "metaphases at $MP has no scripts/export-kids-content.ts (needs mutaaf/metaphases#32)"; exit 1; }
OUT="$PWD/MoonClub/Resources/kids-content.json"
( cd "$MP" && npx -y tsx scripts/export-kids-content.ts "$OUT" )
cp "$OUT" Packages/MoonClubCore/Tests/MoonClubCoreTests/Resources/kids-content.json
echo "synced → $OUT"
