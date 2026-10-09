#!/bin/sh
# Build divo, run its tests, and check the sample site against the snapshot.
set -eu
cd "$(dirname "$0")/.."
OVID="${OVID:-../ovid/bin/ovid}"
"$OVID" test -C .
mkdir -p bin
"$OVID" build -C . -o bin/divo
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site"
# Copy the source site, not a previous public/ or the snapshot.
cp -a examples/notes/config.txt examples/notes/templates examples/notes/content examples/notes/static "$tmp/site/"
./bin/divo build "$tmp/site"
diff -ru examples/notes/expected "$tmp/site/public"
