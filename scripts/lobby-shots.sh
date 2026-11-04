#!/bin/zsh
# Store screenshots through Lobby: copy the fresh raw captures from `make store-shots` into
# store/lobby/raw, render the designed frames (store/lobby.json), upload those. Falls back to
# uploading the raw captures when Lobby isn't checked out next to this repo.
set -e
cd "$(dirname $0)/.."
LOBBY=${LOBBY:-../lobby/bin/lobby}
if [[ ! -x $LOBBY ]]; then
  node scripts/asc.mjs store-shots
  exit
fi
for pair in iphone-69:iphone ipad-13:ipad iphone-duo:duo; do
  from=build/store-shots/${pair%%:*} to=store/lobby/raw/${pair#*:}
  [[ -d $from ]] || continue
  mkdir -p $to
  # Raw captures are kept as quality-90 JPEGs: the PNG set was 55 MB and GitHub dropped the push.
  for f in $from/*.png; do sips -s format jpeg -s formatOptions 90 $f --out $to/${${f:t}%.png}.jpg >/dev/null; done
done
$LOBBY build .
node scripts/asc.mjs store-shots store/lobby/out/appstore
