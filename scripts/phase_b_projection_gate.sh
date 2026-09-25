#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$#" -gt 0 ]; then
  dirs=("$@")
elif [ -d /tmp/phase_b_blessed ]; then
  dirs=(/tmp/phase_b_blessed)
elif [ -d /tmp/phase_b_wi7_blessed ]; then
  dirs=(/tmp/phase_b_wi7_blessed)
else
  dirs=(/tmp/phase_a_parity_after)
fi

allowed_tmp="$(mktemp)"
seen_tmp="$(mktemp)"
trap 'rm -f "$allowed_tmp" "$seen_tmp"' EXIT

cat "$ROOT_DIR/scripts/phase_b_inventory_baseline.txt" > "$allowed_tmp"
printf '%s\n' provider_call_prepared ext_compaction_rejected >> "$allowed_tmp"
sort -u "$allowed_tmp" -o "$allowed_tmp"

for dir in "${dirs[@]}"; do
  if [ ! -d "$dir" ]; then
    echo "missing parity output dir: $dir" >&2
    exit 1
  fi
  scan_dirs=("$dir")
  if [ -d "${dir}.new" ]; then
    scan_dirs+=("${dir}.new")
  fi
  find "${scan_dirs[@]}" -type f -name '*.jsonl' \
    -exec grep -ho '"type":"[^"]*"' {} + \
    | sed -E 's/^"type":"([^"]*)"$/\1/' >> "$seen_tmp"
done

sort -u "$seen_tmp" -o "$seen_tmp"

unknown="$(comm -23 "$seen_tmp" "$allowed_tmp")"
if [ -n "$unknown" ]; then
  echo "phase_b_projection_gate: unknown emitted event type(s):" >&2
  echo "$unknown" >&2
  exit 1
fi

echo "phase_b_projection_gate: OK"
