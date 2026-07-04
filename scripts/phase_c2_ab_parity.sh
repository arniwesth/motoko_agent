#!/usr/bin/env bash
set -euo pipefail

off_dir="${1:-/tmp/c2_ab_off}"
on_dir="${2:-/tmp/c2_ab_on}"

rm -rf "$off_dir" "$on_dir" "${off_dir}.new" "${on_dir}.new"
./scripts/phase_a_event_parity.sh "$off_dir"
MOTOKO_PHASE_C2_DRIVER=1 ./scripts/phase_a_event_parity.sh "$on_dir"
diff -r "$off_dir" "$on_dir"
