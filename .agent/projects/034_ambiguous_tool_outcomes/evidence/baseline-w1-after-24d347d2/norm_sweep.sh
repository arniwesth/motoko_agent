#!/usr/bin/env bash
# Normalise a `make dst` sweep log for a line diff: strip colour codes, mask
# glued durations (852s, 12.3ms), /tmp paths and ISO timestamps, then sort,
# because -j8 interleaves targets.
sed -E $'s/\x1b\\[[0-9;]*[A-Za-z]//g' "$1" \
  | sed -E 's/\b[0-9]+(\.[0-9]+)?(ms|s|µs)\b/<T>/g; s#/tmp/[A-Za-z0-9._/-]+#<TMP>#g; s/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z?/<TS>/g' \
  | LC_ALL=C sort
