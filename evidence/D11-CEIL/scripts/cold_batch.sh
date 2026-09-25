#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
for i in $(seq 1 "$3"); do
  ./sample.sh cdf0f65f "$1" "$2-$i" >> results.txt 2>&1
done
echo "BATCH DONE $2" >> results.txt
